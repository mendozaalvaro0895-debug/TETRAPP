// ════════════════════════════════════════════════════════════════
// TETRAPP — Bot WhatsApp de Serigrafía y Tapas
// Endpoint: POST /api/whatsapp
//
// VARIABLES DE ENTORNO requeridas en Vercel → Settings → Environment:
//   ANTHROPIC_API_KEY   — clave Claude API (platform.anthropic.com)
//   SUPA_URL            — https://rohdxjuuvpgrhevfsrye.supabase.co
//   SUPA_SERVICE_KEY    — service_role key de Supabase (Supabase → Project Settings → API)
//   TWILIO_AUTH_TOKEN   — OBLIGATORIO. Auth token de Twilio (Console → Account Info).
//                         Valida la firma X-Twilio-Signature; sin él se rechaza TODO
//                         POST (fail-closed) para que nadie más pueda escribir en la
//                         base ni gastar tokens de Claude llamando al endpoint.
//                         (acepta el nombre viejo TWILIO_SANDBOX_AUTH como respaldo)
//   TWILIO_WEBHOOK_URL  — opcional. URL exacta configurada en Twilio (ej.
//                         https://tetrapp.vercel.app/api/whatsapp). Úsalo si la firma
//                         falla por reconstrucción de URL detrás del proxy de Vercel.
//   TETRA_WA_ALLOW      — opcional. Números autorizados separados por coma (defensa
//                         extra; la firma ya garantiza que el POST viene de Twilio).
//
// FLUJO:
//   Álvaro reenvía mensaje del grupo de Serigrafía o de Tapas al número sandbox
//   de Twilio → Twilio hace POST aquí → Claude interpreta → INSERT en Supabase
//   → respuesta TwiML
// ════════════════════════════════════════════════════════════════

const crypto = require('crypto');
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

// Valida la firma X-Twilio-Signature. Twilio firma con HMAC-SHA1 la URL
// del webhook concatenada con sus parámetros POST ordenados por clave.
// https://www.twilio.com/docs/usage/security#validating-requests
function firmaTwilioValida(req, url, params, authToken) {
  const firma = req.headers['x-twilio-signature'];
  if (!firma) return false;
  let data = url;
  Object.keys(params).sort().forEach(function (k) { data += k + params[k]; });
  const esperado = crypto.createHmac('sha1', authToken)
    .update(Buffer.from(data, 'utf-8')).digest('base64');
  const a = Buffer.from(firma);
  const b = Buffer.from(esperado);
  return a.length === b.length && crypto.timingSafeEqual(a, b); // tiempo constante
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

// ── Insertar registro en Supabase vía RPC (SECURITY DEFINER) ─────────
// Las funciones bot_insertar_* corren con privilegios del dueño
// y saltan RLS — sin necesitar service_role key.

async function insertar(db, tipo, datos, fecha, hora) {
  if (tipo === 'tiros') {
    const r = await db.rpc('bot_insertar_tiro', {
      p_fecha:    fecha,
      p_area:     'serig',
      p_hora:     hora,
      p_linea_id: Number(datos.linea_id),
      p_momento:  datos.momento,
      p_contador: Number(datos.contador),
      p_diseno:   datos.descripcion || datos.diseno || '',
      p_sku:      datos.sku || '',
    });
    if (r.error) throw new Error('tiros: ' + r.error.message);
    return true;
  }

  if (tipo === 'flameado') {
    const r = await db.rpc('bot_insertar_flameado', {
      p_fecha:       fecha,
      p_hora:        hora,
      p_flameador:   datos.flameador  || 'Sin especificar',
      p_descripcion: datos.descripcion,
      p_sku:         datos.sku        || null,
      p_cantidad:    Number(datos.cantidad),
      p_para_linea:  datos.para_linea ? Number(datos.para_linea) : null,
    });
    if (r.error) throw new Error('flameado: ' + r.error.message);
    return true;
  }

  if (tipo === 'empaque') {
    const r = await db.rpc('bot_insertar_empaque', {
      p_fecha:           fecha,
      p_hora:            hora,
      p_descripcion:     datos.descripcion,
      p_sku:             datos.sku || null,
      p_cantidad:        Number(datos.cantidad),
      p_operador_codigo: datos.operador_codigo || null,
      p_area_origen:     datos.operador_codigo ? null : 'serig',
    });
    if (r.error) throw new Error('empaque: ' + r.error.message);
    return true;
  }

  if (tipo === 'tapas') {
    const r = await db.rpc('bot_insertar_comanda_tapas', {
      p_fecha:            fecha,
      p_operario_codigo:  datos.operario_codigo || '',
      p_operario_nombre:  datos.operario_nombre || datos.operario || '',
      p_proceso:          datos.proceso,
      p_cantidad:         Number(datos.cantidad),
      p_tapa_desc:        datos.descripcion || '',
      p_tapa_sku:         datos.sku || '',
      p_metodo:           datos.metodo || 'manual',
      p_hora:             hora,
    });
    if (r.error) throw new Error('tapas: ' + r.error.message);
    datos.correlativo = r.data || null; // se muestra en la confirmación
    return true;
  }

  return false; // tipo desconocido
}

// ── Resolver operario de Tapas desde el nombre (trazabilidad) ────
// Mismo criterio que resolverSku: si hay un candidato claro, muta
// datos con operario_codigo/nombre oficiales. Si no, deja el texto
// libre tal cual (igual tolerancia que ya tiene el campo flameador
// de Serigrafía) y solo agrega una nota de aviso.
async function resolverOperario(db, datos) {
  var texto = (datos.operario_nombre || datos.operario || '').trim();
  if (!texto || datos.operario_codigo) return { nota: '' };

  var r;
  try { r = await db.rpc('bot_buscar_operario', { p_texto: texto, p_area: 'tapas' }); }
  catch(_) { return { nota: '' }; }
  if (r.error || !r.data) return { nota: '' };

  var conHits = r.data.filter(function(x){ return x.hits > 0; });
  if (!conHits.length) return { nota: ' · ⚠️ operario no verificado' };

  var toks = texto.toLowerCase().split(/\s+/).filter(function(t){ return t.length >= 2; });
  var top = conHits[0];
  var unico = conHits.length === 1 || conHits[1].hits < top.hits;

  if (top.hits >= toks.length && unico) {
    datos.operario_codigo = top.codigo;
    datos.operario_nombre = top.nombre;
    return { nota: '' };
  }

  return { nota: ' · ⚠️ operario no verificado' };
}

// ── Resolver SKU desde la descripción (trazabilidad) ──────────────
// Devuelve { nota, opciones? }
//   · 1 coincidencia clara → muta datos con sku/descripcion oficial, nota con SKU
//   · varias opciones      → nota vacía + opciones[] para que el operador elija
//   · ninguna              → nota de aviso
async function resolverSku(db, datos) {
  var texto = (datos.descripcion || datos.diseno || '').trim();
  if (!texto || datos.sku) return { nota: '' };

  var r;
  try { r = await db.rpc('bot_buscar_sku', { p_texto: texto }); }
  catch(_) { return { nota: '' }; }
  if (r.error || !r.data) return { nota: '' };

  var conHits = r.data.filter(function(x){ return x.hits > 0; });
  if (!conHits.length) return { nota: ' · ⚠️ sin SKU en inventario' };

  var toks = texto.toLowerCase().split(/\s+/).filter(function(t){ return t.length >= 2; });
  var top = conHits[0];
  var unico = conHits.length === 1 || conHits[1].hits < top.hits;

  // Coincidencia confiable: top cubre TODAS las palabras y no hay empate
  if (top.hits >= toks.length && unico) {
    datos.sku = String(top.sku);
    datos.descripcion = top.descripcion;
    return { nota: ' · 🔗 SKU ' + top.sku };
  }

  // Varias opciones → devolver lista para que el operador elija
  return { opciones: conHits.slice(0, 5), nota: '' };
}

// ── Prompt del sistema ────────────────────────────────────────────

const SYSTEM_PROMPT = `Eres el asistente interno de TETRAPP para las plantas de Serigrafía y Tapas de Tetraplastic Guatemala.
Recibes mensajes de WhatsApp reenviados por Álvaro (supervisor/administrador) desde los grupos de planta.
Tu trabajo: interpretar el mensaje y extraer datos de producción estructurados.

━━ TIPOS DE REGISTRO ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

① TIROS (Serigrafía) — lectura del contador de impresión de una línea.
   Campos: linea_id (1-4), momento, contador (número entero de tiros), descripcion (producto)
   momento válidos: "inicio" · "mediodia" · "fin" · "velada"
   Alias: inicio/arranque=inicio · medio/mediodía=mediodia · cierre/terminar/salida=fin · noche/madrugada=velada

② FLAMEADO (Serigrafía) — bolsas flameadas para una línea.
   Campos: flameador (nombre o código, ej. "S3" o "Marcos"), descripcion (producto), cantidad (entero), para_linea (1-4)
   Señales: "flameó", "bolsas", "flameadas", "contenido + parte de enfrente", menciona línea destino (L1-L4)

③ EMPAQUE (Serigrafía) — producto empacado.
   Campos: descripcion (producto), cantidad (entero), operador_codigo (ej. "S5", si se menciona)

④ TAPAS — producción de un operario de la planta de Tapas (una tarea por mensaje).
   Campos: operario (nombre o código), proceso, descripcion (tapa/producto trabajado), cantidad (entero), metodo
   proceso válidos: "Armado" · "Banda" · "Liner" · "Encajado" · "Revisado" · "Limpiar pestaña" ·
     "Apoyo Serigrafía" · "Apoyo Producción" · "Otra tarea: <detalle>"
   Alias: armó/arme/armado=Armado · banda=Banda · liner=Liner · encajó/encajó cajas/encajado=Encajado ·
     revisó/revisión=Revisado · pestaña=Limpiar pestaña
   metodo válidos: "manual" (default) · "maquina_liner" (solo si proceso=Liner Y menciona máquina/Press Top) ·
     "maquina_armado" (solo si proceso=Armado Y menciona máquina/Press Top)
   Señales: "armó", "encajó N cajas", "hizo banda de", cualquier producción de Tapas sin vocabulario de ②
     (bolsas/contenido/línea destino) ni de ① (contador/tiros de línea)

━━ REGLAS DE INTERPRETACIÓN ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Números: coma y punto son separadores de miles (12,000 = 12000; 1.500 = 1500)
• Si hay "total X" o "= X", ese X es el número definitivo
• "contenido" = unidades dentro de la bolsa (tipo flameado)
• "parte de enfrente / detrás / lado B" = otra zona del mismo proceso (sumar al total)
• L1/L2/L3/L4 = Línea 1/2/3/4 (solo tipos ① y ②, Serigrafía)
• Operadores Serigrafía: S0=Luis Córdova (supervisor), S1-S7=operadores
• Si el mensaje solo menciona un número y un producto sin contexto claro → pide aclaración
• "tiros" puede referirse al conteo de impresiones de ese turno (flameado NO usa "tiros")
• "Flameado"/"Impresión" de Tapas (tipo④) vs Serigrafía (tipos ①②): si el mensaje trae bolsas/
  contenido/línea destino → es Serigrafía; si solo dice "Fulano flameó/imprimió N tapas X" sin esas
  señales y menciona un operario de Tapas → es tipo④
• Mensajes de cortesía, OK, gracias, saludos, confirmaciones → ignorar:true

━━ DATOS CRÍTICOS QUE DEBES TENER ━━━━━━━━━━━━━━━━━━━━━━━━

- TIROS: línea + momento + contador son OBLIGATORIOS
- FLAMEADO: descripcion + cantidad son OBLIGATORIOS (para_linea recomendado)
- EMPAQUE: descripcion + cantidad son OBLIGATORIOS
- TAPAS: operario + proceso + cantidad son OBLIGATORIOS (descripcion/tapa recomendada, no bloquea)

Si falta un dato crítico, haz UNA sola pregunta concisa.
Si tienes todo, inserta sin preguntar.

━━ FORMATO DE RESPUESTA ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Responde ÚNICAMENTE con JSON válido, sin markdown, sin texto extra:

{
  "tipo": "tiros" | "flameado" | "empaque" | "tapas" | "desconocido",
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

    // ── Seguridad: validar que el POST viene realmente de Twilio ──────
    // Fail-closed: sin auth token o con firma inválida se rechaza (403),
    // ANTES de llamar a Claude o escribir en Supabase (service_role salta RLS).
    const authToken = process.env.TWILIO_AUTH_TOKEN || process.env.TWILIO_SANDBOX_AUTH;
    if (!authToken) {
      console.error('[TETRAPP-BOT] TWILIO_AUTH_TOKEN no configurado — rechazando (fail-closed)');
      res.status(403).end('Forbidden');
      return;
    }
    const proto = req.headers['x-forwarded-proto'] || 'https';
    const host  = req.headers['x-forwarded-host'] || req.headers.host;
    const url   = process.env.TWILIO_WEBHOOK_URL || (proto + '://' + host + req.url);
    if (!firmaTwilioValida(req, url, body, authToken)) {
      console.warn('[TETRAPP-BOT] firma Twilio inválida — rechazado. from:', from);
      res.status(403).end('Forbidden');
      return;
    }

    // Allowlist opcional de números (defensa extra sobre la firma)
    const allow = (process.env.TETRA_WA_ALLOW || '').split(',').map(function (s) { return s.trim(); }).filter(Boolean);
    if (allow.length && !allow.some(function (n) { return from.indexOf(n) !== -1; })) {
      console.warn('[TETRAPP-BOT] número no autorizado:', from);
      res.setHeader('Content-Type', 'text/xml');
      res.end(twiml('⛔ Número no autorizado para registrar producción.'));
      return;
    }

    console.log('[TETRAPP-BOT] from:', from, '| msg:', msgText.slice(0, 80));

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

    // ── ¿El operador está eligiendo un SKU de la lista? ──────────
    if (estadoPrevio && estadoPrevio.pendiente_sku) {
      const ops   = estadoPrevio.pendiente_sku.opciones || [];
      const datos = estadoPrevio.pendiente_sku.datos    || {};
      const tipo  = estadoPrevio.pendiente_sku.tipo;
      const sel   = parseInt(msgText.trim());
      const limpiar = msgText.toLowerCase();

      // 0 o "ninguno" → guardar sin SKU
      if (sel === 0 || limpiar.includes('ninguno') || limpiar.includes('sin sku')) {
        try {
          await insertar(db, tipo, datos, fecha, hora);
          await clearEstado(db, from).catch(() => {});
          res.setHeader('Content-Type', 'text/xml');
          res.end(twiml('✅ Registrado sin SKU · ' + fecha + (datos.correlativo ? ' · ' + datos.correlativo : '')));
        } catch(e) {
          res.setHeader('Content-Type', 'text/xml');
          res.end(twiml('❌ Error BD: ' + e.message));
        }
        return;
      }

      // Número válido → vincular SKU seleccionado
      if (sel >= 1 && sel <= ops.length) {
        datos.sku         = String(ops[sel - 1].sku);
        datos.descripcion = ops[sel - 1].descripcion;
        try {
          await insertar(db, tipo, datos, fecha, hora);
          await clearEstado(db, from).catch(() => {});
          res.setHeader('Content-Type', 'text/xml');
          res.end(twiml(
            '✅ Registrado · 🔗 ' + datos.sku + ' · ' + datos.descripcion.slice(0, 45)
              + (datos.correlativo ? ' · ' + datos.correlativo : '')
          ));
        } catch(e) {
          res.setHeader('Content-Type', 'text/xml');
          res.end(twiml('❌ Error BD: ' + e.message));
        }
        return;
      }

      // Entrada inválida → repetir lista
      const lista = ops.map(function(o, i){
        return (i + 1) + ') ' + o.sku + ' · ' + o.descripcion.slice(0, 40);
      }).join('\n');
      res.setHeader('Content-Type', 'text/xml');
      res.end(twiml('⚠️ Elegí un número:\n' + lista + '\n0) Sin SKU'));
      return;
    }

    // Construir el mensaje para Claude (flujo normal)
    let userContent = msgText;
    if (estadoPrevio && !estadoPrevio.pendiente_sku) {
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

    // ── Datos completos: resolver operario/SKU e insertar ─────────
    try {
      const datos = parsed.datos || {};

      // Tapas: resolver el operario contra `personal` antes del SKU
      // (no bloquea si no hay match claro — mismo criterio tolerante
      // que ya tiene el campo flameador de Serigrafía)
      let operarioNota = '';
      if (parsed.tipo === 'tapas') {
        const opRes = await resolverOperario(db, datos);
        operarioNota = opRes.nota || '';
      }

      const skuRes = await resolverSku(db, datos);

      // Varias opciones → preguntar al operador sin insertar todavía
      if (skuRes.opciones && skuRes.opciones.length) {
        const lista = skuRes.opciones.map(function(o, i){
          return (i + 1) + ') ' + o.sku + ' · ' + o.descripcion.slice(0, 40);
        }).join('\n');
        try {
          await setEstado(db, from, {
            pendiente_sku: { tipo: parsed.tipo, datos, opciones: skuRes.opciones }
          });
        } catch(_) {}
        res.setHeader('Content-Type', 'text/xml');
        res.end(twiml('❓ ¿Cuál producto?\n' + lista + '\n0) Sin SKU'));
        return;
      }

      // SKU resuelto (único) o sin coincidencia → insertar directamente
      const ok = await insertar(db, parsed.tipo, datos, fecha, hora);
      await clearEstado(db, from).catch(() => {});

      const resp = ok
        ? '✅ ' + (parsed.mensaje_confirmacion || 'Registro guardado · ' + fecha) + skuRes.nota + operarioNota
            + (datos.correlativo ? ' · ' + datos.correlativo : '')
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
