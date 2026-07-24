// ════════════════════════════════════════════════════════════════
// TETRAPP — Bot WhatsApp de Serigrafía
// Endpoint: POST /api/whatsapp
//
// VARIABLES DE ENTORNO requeridas en Vercel → Settings → Environment:
//   ANTHROPIC_API_KEY   — clave Claude API (platform.anthropic.com)
//   SUPA_URL            — https://rohdxjuuvpgrhevfsrye.supabase.co
//   SUPA_SERVICE_KEY    — service_role key de Supabase (Supabase → Project Settings → API)
//   TWILIO_SANDBOX_AUTH — token del sandbox Twilio (opcional; activa validación de firma)
//
// FLUJO:
//   Álvaro reenvía mensaje del grupo serigrafía al número sandbox de Twilio
//   → Twilio hace POST aquí → Claude interpreta → INSERT en Supabase → respuesta TwiML
// ════════════════════════════════════════════════════════════════

const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');

// Desactivar el body parser de Vercel — Twilio envía form-encoded
module.exports.config = { api: { bodyParser: false } };

// ── Helpers ──────────────────────────────────────────────────────

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    let buf = '';
    req.on('data', chunk => { buf += chunk.toString(); });
    req.on('end', () => resolve(buf));
    req.on('error', reject);
  });
}

function parseFormBody(raw) {
  const p = new URLSearchParams(raw);
  const out = {};
  for (const [k, v] of p) out[k] = v;
  return out;
}

// Fecha/hora en Guatemala (UTC-6) — nunca toISOString directo en prod
function fechaGT() {
  const gt = new Date(Date.now() - 6 * 60 * 60 * 1000);
  const iso = gt.toISOString();
  return { fecha: iso.slice(0, 10), hora: iso.slice(11, 16) };
}

function twiml(msg) {
  const esc = msg.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  return `<?xml version="1.0" encoding="UTF-8"?><Response><Message>${esc}</Message></Response>`;
}

// ── Estado conversación (1 fila por número Twilio) ───────────────

async function getEstado(db, from) {
  const r = await db.from('bot_estado').select('estado').eq('whatsapp_from', from).maybeSingle();
  return (r.data && r.data.estado) || null;
}

async function setEstado(db, from, estado) {
  await db.from('bot_estado').upsert(
    { whatsapp_from: from, estado, updated_at: new Date().toISOString() },
    { onConflict: 'whatsapp_from' }
  );
}

async function clearEstado(db, from) {
  await db.from('bot_estado').delete().eq('whatsapp_from', from);
}

// ── Insertar registro en Supabase ─────────────────────────────────

async function insertar(db, tipo, datos, fecha, hora) {
  if (tipo === 'tiros') {
    const r = await db.from('registro_tiros_serig').insert({
      fecha, area: 'serig', hora,
      linea_id: Number(datos.linea_id),
      momento:  datos.momento,
      contador: Number(datos.contador),
    });
    if (r.error) throw new Error('tiros: ' + r.error.message);
    return true;
  }

  if (tipo === 'flameado') {
    const r = await db.from('registro_flameado_serig').insert({
      fecha, hora,
      flameador:   datos.flameador  || 'Sin especificar',
      descripcion: datos.descripcion,
      sku:         datos.sku        || null,
      cantidad:    Number(datos.cantidad),
      para_linea:  datos.para_linea ? Number(datos.para_linea) : null,
    });
    if (r.error) throw new Error('flameado: ' + r.error.message);
    return true;
  }

  if (tipo === 'empaque') {
    const r = await db.from('registro_empaque_serig').insert({
      fecha, hora,
      descripcion:     datos.descripcion,
      sku:             datos.sku || null,
      cantidad:        Number(datos.cantidad),
      operador_codigo: datos.operador_codigo || null,
      area_origen:     datos.operador_codigo ? null : 'serig',
    });
    if (r.error) throw new Error('empaque: ' + r.error.message);
    return true;
  }

  return false; // tipo desconocido
}

// ── Prompt del sistema ────────────────────────────────────────────

const SYSTEM_PROMPT = `Eres el asistente interno de TETRAPP para la planta de Serigrafía de Tetraplastic Guatemala.
Recibes mensajes de WhatsApp reenviados por Álvaro (supervisor/administrador) desde el grupo de serigrafía.
Tu trabajo: interpretar el mensaje y extraer datos de producción estructurados.

━━ TIPOS DE REGISTRO ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

① TIROS — lectura del contador de impresión de una línea.
   Campos: linea_id (1-4), momento, contador (número entero de tiros), descripcion (producto)
   momento válidos: "inicio" · "mediodia" · "fin" · "velada"
   Alias: inicio/arranque=inicio · medio/mediodía=mediodia · cierre/terminar/salida=fin · noche/madrugada=velada

② FLAMEADO — bolsas flameadas para una línea.
   Campos: flameador (nombre o código, ej. "S3" o "Marcos"), descripcion (producto), cantidad (entero), para_linea (1-4)
   Señales: "flameó", "bolsas", "flameadas", "contenido + parte de enfrente"

③ EMPAQUE — producto empacado.
   Campos: descripcion (producto), cantidad (entero), operador_codigo (ej. "S5", si se menciona)

━━ REGLAS DE INTERPRETACIÓN ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Números: coma y punto son separadores de miles (12,000 = 12000; 1.500 = 1500)
• Si hay "total X" o "= X", ese X es el número definitivo
• "contenido" = unidades dentro de la bolsa (tipo flameado)
• "parte de enfrente / detrás / lado B" = otra zona del mismo proceso (sumar al total)
• L1/L2/L3/L4 = Línea 1/2/3/4
• Operadores: S0=Luis Córdova (supervisor), S1-S7=operadores
• Si el mensaje solo menciona un número y un producto sin contexto claro → pide aclaración
• "tiros" puede referirse al conteo de impresiones de ese turno (flameado NO usa "tiros")
• Mensajes de cortesía, OK, gracias, saludos, confirmaciones → ignorar:true

━━ DATOS CRÍTICOS QUE DEBES TENER ━━━━━━━━━━━━━━━━━━━━━━━━

- TIROS: línea + momento + contador son OBLIGATORIOS
- FLAMEADO: descripcion + cantidad son OBLIGATORIOS (para_linea recomendado)
- EMPAQUE: descripcion + cantidad son OBLIGATORIOS

Si falta un dato crítico, haz UNA sola pregunta concisa.
Si tienes todo, inserta sin preguntar.

━━ FORMATO DE RESPUESTA ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Responde ÚNICAMENTE con JSON válido, sin markdown, sin texto extra:

{
  "tipo": "tiros" | "flameado" | "empaque" | "desconocido",
  "datos": {
    /* campos según el tipo */
  },
  "confianza": "alta" | "media" | "baja",
  "mensaje_confirmacion": "Texto breve confirmando qué se registró (máx 80 caracteres)",
  "pregunta_pendiente": null | "Pregunta corta si FALTA dato crítico",
  "ignorar": false
}

Si el mensaje debe ignorarse:
{ "ignorar": true }`;

// ── Handler principal ─────────────────────────────────────────────

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).end('Method Not Allowed');
    return;
  }

  try {
    // Parsear body form-encoded de Twilio
    const raw  = await readRawBody(req);
    const body = parseFormBody(raw);
    const from    = body.From  || '';
    const msgText = (body.Body  || '').trim();

    console.log('[TETRAPP-BOT] from:', from, '| msg:', msgText.slice(0, 80));
    console.log('[TETRAPP-BOT] env check — SUPA_URL:', !!process.env.SUPA_URL,
      '| SUPA_SERVICE_KEY:', !!process.env.SUPA_SERVICE_KEY,
      '| ANTHROPIC_API_KEY:', !!process.env.ANTHROPIC_API_KEY);

    if (!msgText) {
      res.setHeader('Content-Type', 'text/xml');
      res.end(twiml('👋 Bot TETRAPP activo'));
      return;
    }

    // Clientes
    const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
    const db = createClient(
      process.env.SUPA_URL,
      process.env.SUPA_SERVICE_KEY || process.env.SUPA_KEY
    );

    const { fecha, hora } = fechaGT();

    // ¿Hay estado pendiente de un mensaje anterior?
    let estadoPrevio = null;
    try { estadoPrevio = await getEstado(db, from); } catch(_) {}

    // Construir el mensaje para Claude
    let userContent = msgText;
    if (estadoPrevio) {
      userContent =
        `DATOS INCOMPLETOS DEL MENSAJE ANTERIOR:\n${JSON.stringify(estadoPrevio, null, 2)}\n\n` +
        `RESPUESTA DE ÁLVARO: "${msgText}"\n\n` +
        `Completa los datos faltantes y retorna el registro completo.`;
    }

    // ── Llamada a Claude ──────────────────────────────────────────
    let parsed;
    let rawText = '';
    try {
      const aiResp = await anthropic.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 512,
        system: SYSTEM_PROMPT,
        messages: [{ role: 'user', content: userContent }]
      });
      rawText = aiResp.content[0].text.trim()
        .replace(/^```[a-z]*\n?/, '').replace(/\n?```$/, '').trim();
    } catch(e) {
      console.error('[TETRAPP-BOT] Error llamada Anthropic:', e.message);
      res.setHeader('Content-Type', 'text/xml');
      res.end(twiml('❌ Error API: ' + e.message.slice(0, 100)));
      return;
    }
    try {
      parsed = JSON.parse(rawText);
    } catch(e) {
      console.error('[TETRAPP-BOT] JSON inválido de Claude:', rawText.slice(0, 200));
      res.setHeader('Content-Type', 'text/xml');
      res.end(twiml('❌ Respuesta inesperada de Claude. Intenta de nuevo.'));
      return;
    }

    // ── Mensaje que se debe ignorar ───────────────────────────────
    if (parsed.ignorar) {
      res.setHeader('Content-Type', 'text/xml');
      res.end(twiml('👍'));
      return;
    }

    // ── Falta un dato crítico: guardar estado y preguntar ─────────
    if (parsed.pregunta_pendiente) {
      try {
        await setEstado(db, from, { tipo: parsed.tipo, datos: parsed.datos || {} });
      } catch(_) {}
      res.setHeader('Content-Type', 'text/xml');
      res.end(twiml('❓ ' + parsed.pregunta_pendiente));
      return;
    }

    // ── Datos completos: insertar en Supabase ─────────────────────
    try {
      const ok = await insertar(db, parsed.tipo, parsed.datos || {}, fecha, hora);
      await clearEstado(db, from).catch(() => {});

      const resp = ok
        ? '✅ ' + (parsed.mensaje_confirmacion || 'Registro guardado · ' + fecha)
        : '⚠️ Tipo no reconocido: ' + parsed.tipo + '. Escribe "ayuda" para ver los formatos.';

      res.setHeader('Content-Type', 'text/xml');
      res.end(twiml(resp));
    } catch(e) {
      console.error('[TETRAPP-BOT] Error BD:', e.message);
      res.setHeader('Content-Type', 'text/xml');
      res.end(twiml('❌ Error BD: ' + e.message));
    }
  } catch(e) {
    console.error('[TETRAPP-BOT] Error global no manejado:', e.message, e.stack);
    try {
      res.setHeader('Content-Type', 'text/xml');
      res.end(twiml('❌ Error interno: ' + e.message.slice(0, 100)));
    } catch(_) {}
  }
};
