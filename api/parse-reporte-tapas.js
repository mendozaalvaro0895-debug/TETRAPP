// ════════════════════════════════════════════════════════════════
// TETRAPP — Parser de reportes diarios de Tapas (texto de WhatsApp → estructurado)
// Endpoint: POST /api/parse-reporte-tapas
// Body JSON: { texto: "...", fecha_referencia: "YYYY-MM-DD" }
// Devuelve: { filas: [{ operario_texto, fecha, dia_texto, cantidad, proceso,
//             descripcion, metodo, proceso_dudoso }], warnings: [] }
//
// A diferencia de api/parse-doc.js (CORS abierto, sin auth — pendiente de
// gatear, ver CLAUDE.md), este endpoint exige el access_token de la sesión
// de Supabase del que llama y verifica rol='master' en `perfiles` ANTES de
// llamar a Claude, para que nadie pueda gastar tokens golpeando el endpoint
// sin estar logueado como master en TETRAPP.
//
// Uso: comandas.html → botón "Importar reporte WhatsApp" → pega el texto
// crudo del reporte, el navegador llama aquí con su propio token de sesión.
// ════════════════════════════════════════════════════════════════

const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');

function buildPrompt(texto, fechaRef) {
  return `Eres el asistente de TETRAPP que interpreta reportes diarios de producción de la planta de Tapas (Tetraplastic, Guatemala), reenviados desde WhatsApp.

FECHA DE REFERENCIA (día en que se envió/recibió el reporte): ${fechaRef}

FORMATO TÍPICO del reporte:
- El nombre de un operario en su propia línea inicia un bloque con SU producción.
- Dentro del bloque de un operario puede haber sub-encabezados de día ("Martes", "Miércoles", etc.) que agrupan varias líneas de producción de ESE día. Si un bloque de operario NO tiene sub-encabezado de día, toda su producción es de la FECHA DE REFERENCIA.
- Cada línea de producción es: <cantidad> <texto libre con proceso + producto>. Coma y punto son separadores de miles (1,300 = 1300).
- Puede haber texto decorativo al inicio ("Reporte del día...", nombre de grupo, saludos, etc.) — ignóralo, no es una línea de producción.

RESOLUCIÓN DE DÍAS: si aparece un nombre de día de la semana (lunes…domingo) sin fecha explícita, calculá la fecha real como la ocurrencia de ese día de la semana MÁS CERCANA Y ANTERIOR O IGUAL a ${fechaRef} (nunca futura).

PROCESOS VÁLIDOS y palabras que los identifican (normalizá SIEMPRE a estos nombres EXACTOS):
- "Armado": armó, arme, armado, armada, "primer proceso" (de un producto que se arma primero, ej. push pull)
- "Liner": liner
- "Banda": banda
- "Encajado": encajó, encajo, encajado, encajar
- "Impresión": imprimió, impreso, impresas, impresión
- "Flameado": flameó, flameo, flameado
- Si NINGUNA palabra de la lista aparece en la línea, o el texto es ambiguo entre dos procesos, dejá "proceso":"" y "proceso_dudoso":true — NO ADIVINES el proceso en ese caso.

MÉTODO: "metodo":"maquina_liner" SOLO si proceso=Liner Y el texto menciona máquina/press/PP33; "maquina_armado" SOLO si proceso=Armado Y menciona máquina/press/PP28; en cualquier otro caso "manual".

DESCRIPCIÓN: el resto del texto de la línea que no es la palabra de proceso ni la cantidad (ej. "28 negra", "elíptica dorada", "tapa 90 azul pastel", "incogua", "push pull negra", "addiction", "amour intense"). Conservalo tal cual lo escribió el operario, sin inventar ni corregir.

Devolvé ÚNICAMENTE JSON válido, sin markdown, sin texto extra:
{
  "filas": [
    {
      "operario_texto": "Johana",
      "fecha": "YYYY-MM-DD",
      "dia_texto": "Martes",
      "cantidad": 1300,
      "proceso": "Liner",
      "descripcion": "28 negra",
      "metodo": "manual",
      "proceso_dudoso": false
    }
  ],
  "warnings": []
}

Si el texto no tiene ninguna línea de producción reconocible, devolvé {"filas":[],"warnings":["..."]}.

TEXTO DEL REPORTE:
"""
${texto}
"""`;
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST')    { res.status(405).end('Method Not Allowed'); return; }

  try {
    const authHeader = req.headers['authorization'] || '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) {
      res.status(401).json({ error: 'Falta sesión' });
      return;
    }

    // Chequeo de rol: corre COMO el usuario que llama (igual que shared/auth.js en el
    // navegador), no con la service key — `perfiles` nunca le dio grants directos a
    // service_role (es tabla sensible de auth, el resto de páginas solo la leen vía RLS
    // con el token del propio usuario). Así este chequeo no depende de permisos nuevos.
    const db = createClient(
      process.env.SUPA_URL,
      process.env.SUPA_KEY || 'sb_publishable_PayfE36QRzwOnP6zA2TDSQ_oj4vnB5i',
      { global: { headers: { Authorization: 'Bearer ' + token } } }
    );

    const { data: userData, error: userErr } = await db.auth.getUser(token);
    if (userErr || !userData || !userData.user) {
      console.error('[parse-reporte-tapas] getUser falló:', userErr && userErr.message);
      res.status(401).json({ error: 'Sesión inválida', detalle: userErr ? userErr.message : null });
      return;
    }

    const { data: perfil, error: perfilErr } = await db.from('perfiles').select('rol').eq('user_id', userData.user.id).single();
    if (perfilErr || !perfil || perfil.rol !== 'master') {
      console.error('[parse-reporte-tapas] chequeo de rol falló. user_id:', userData.user.id,
        '| error:', perfilErr && perfilErr.message, '| perfil:', perfil);
      res.status(403).json({
        error: 'Sin permiso — se requiere rol master',
        detalle: perfilErr ? perfilErr.message : (perfil ? ('rol actual: ' + perfil.rol) : 'no se encontró perfil para este usuario'),
      });
      return;
    }

    const { texto, fecha_referencia } = req.body || {};
    if (!texto || !fecha_referencia) {
      res.status(400).json({ error: 'Falta texto o fecha_referencia' });
      return;
    }

    const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
    const aiResp = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 2048,
      messages: [{ role: 'user', content: buildPrompt(texto, fecha_referencia) }]
    });

    const textBlock = (aiResp.content || []).find(function(b) { return b.type === 'text' && b.text; });
    if (!textBlock) throw new Error('La IA no devolvió texto legible');
    const raw = textBlock.text.trim()
      .replace(/^```[a-z]*\n?/, '').replace(/\n?```$/, '').trim();

    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch(pe) {
      console.error('[parse-reporte-tapas] JSON inválido:', raw.slice(0, 300));
      throw new Error('Respuesta no es JSON válido');
    }

    res.json(parsed);
  } catch(e) {
    console.error('[parse-reporte-tapas]', e.message);
    res.status(500).json({ error: e.message });
  }
};
