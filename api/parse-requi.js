// ════════════════════════════════════════════════════════════════
// TETRAPP — Central de Ingreso: lector de requis SICAF (Claude Vision)
// Endpoint: POST /api/parse-requi
// Header:   Authorization: Bearer <supabase access_token de un usuario master>
// Body JSON: { image_base64: "...", mime_type: "image/png" }
// Devuelve:  { documentos: [{ bodega, documento, prefijo, numero, fecha,
//              descripcion, referencia, lineas:[{codigo,producto,cantidad,
//              costo_unitario,valor_total}] }], warnings }
//
// A diferencia de api/parse-doc.js (CORS abierto sin auth — pendiente en
// CLAUDE.md), este endpoint SÍ valida que quien llama sea un usuario
// autenticado con rol master antes de gastar tokens de Claude.
// ════════════════════════════════════════════════════════════════

const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');

const SUPA_URL = 'https://rohdxjuuvpgrhevfsrye.supabase.co';
const SUPA_KEY = 'sb_publishable_PayfE36QRzwOnP6zA2TDSQ_oj4vnB5i';

async function esMaster(token) {
  if (!token) return false;
  try {
    // Con Authorization en los headers globales, las consultas .from(...) viajan
    // con el JWT del usuario (no el anon) — sin esto, el RLS de `perfiles` las
    // bloquea silenciosamente y esto siempre da "no autorizado".
    const db = createClient(SUPA_URL, SUPA_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } }
    });
    const { data: userData, error: userErr } = await db.auth.getUser(token);
    if (userErr || !userData || !userData.user) return false;
    const { data: perfil, error: perfilErr } = await db
      .from('perfiles').select('rol').eq('user_id', userData.user.id).single();
    if (perfilErr || !perfil) return false;
    return perfil.rol === 'master';
  } catch (e) {
    return false;
  }
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST')    { res.status(405).end('Method Not Allowed'); return; }

  const authHeader = req.headers.authorization || '';
  const token = authHeader.replace(/^Bearer\s+/i, '');
  if (!(await esMaster(token))) {
    res.status(401).json({ error: 'No autorizado' });
    return;
  }

  const { image_base64, mime_type } = req.body || {};
  if (!image_base64) {
    res.status(400).json({ error: 'Falta image_base64' });
    return;
  }

  const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

  const prompt = `Analizá esta captura o página de un reporte de SICAF (ERP de TETRAPLAST, S.A.,
Guatemala) — "Salidas de Bodega" o "Ingresos a Bodega". Extraé TODOS los documentos que aparezcan
en la imagen (puede haber más de uno en la misma página, cada uno con su propia tabla de productos
y su "Total Documento:").

Para cada documento extraé:
• bodega: el número que aparece junto a "Bodega:" en el encabezado (ej. "02", "07"). Si no aparece
  visible en esta captura, poné null — NO inventes un valor.
• documento: el texto completo del campo "Documento" tal cual aparece (ej. "PRI2 498", "TMP 3087").
• prefijo: SOLO las letras iniciales de "documento", en mayúsculas (ej. "PRI", "TMP", "PTI").
• numero: SOLO los dígitos de "documento" (ej. "498", "3087").
• fecha: la fecha de ESE renglón de documento (columna "Fecha" junto al número de documento — es la
  fecha real de la transacción, NO la fecha de generación del reporte que aparece arriba a la
  derecha del todo). Formato YYYY-MM-DD (año de 2 dígitos: 26 → 2026).
• descripcion: el texto de la columna "Descripción" tal cual (es libre, sin estándar — cópialo literal).
• referencia: el texto de la columna "Referencia" tal cual, o null si esa columna viene vacía.
• lineas: array con TODOS los renglones de productos de ESE documento (no mezclar con los de otro
  documento de la misma imagen). Cada línea:
    – codigo: código numérico (columna "Código")
    – producto: descripción del producto (columna "Producto", puede ocupar 2 líneas — es una sola fila)
    – cantidad: cantidad como número (columna "Cantidad" — quitar el ".0000" final)
    – costo_unitario: columna "Prec.Uni. C/I" o "Costo U." (número, puede ser 0)
    – valor_total: columna "Valor Total" (número, puede ser 0)

⚠️ MÁXIMA PRECISIÓN EN LOS DÍGITOS — un dígito mal invalida el registro:
• Leé cada código y cada cantidad DÍGITO POR DÍGITO, sin adivinar.
• Distinguí con cuidado los pares que se confunden: 0/8, 3/8, 6/8, 2/3, 5/6, 1/7, 9/0, 4/9.
• Nunca mezcles filas de "Total Documento:" o "Total General:" como si fueran un producto.
• Contá los renglones de cada tabla: la cantidad de líneas debe coincidir con las filas visibles.
• Si un dato no es claramente legible, dejalo en null y anotalo en "warnings" en vez de inventarlo.

Respondé SOLO con JSON válido, sin markdown, sin texto adicional:
{
  "documentos": [
    {
      "bodega": "02",
      "documento": "PRI2 498",
      "prefijo": "PRI",
      "numero": "498",
      "fecha": "2026-06-08",
      "descripcion": "sabado 6 dia",
      "referencia": null,
      "lineas": [
        { "codigo": "10023", "producto": "ENVA.OVAL C/ROSCA 240 ML SIN IMP. LIN BEBE COD.201668", "cantidad": 3140, "costo_unitario": 0.49, "valor_total": 1538.60 }
      ]
    }
  ],
  "warnings": []
}`;

  try {
    const aiResp = await anthropic.messages.create({
      model: 'claude-sonnet-5',
      max_tokens: 8192,
      messages: [{
        role: 'user',
        content: [
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: mime_type || 'image/png',
              data: image_base64
            }
          },
          { type: 'text', text: prompt }
        ]
      }]
    });

    const textBlock = (aiResp.content || []).find(function(b) { return b.type === 'text' && b.text; });
    if (!textBlock) throw new Error('La IA no devolvió texto legible');
    const raw = textBlock.text.trim()
      .replace(/^```[a-z]*\n?/, '').replace(/\n?```$/, '').trim();
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (pe) {
      console.error('[parse-requi] JSON inválido:', raw.slice(0, 300));
      throw new Error('Respuesta no es JSON válido');
    }
    res.json(parsed);
  } catch (e) {
    console.error('[parse-requi]', e.message);
    res.status(500).json({ error: e.message });
  }
};
