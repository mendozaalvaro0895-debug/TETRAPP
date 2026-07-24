// ════════════════════════════════════════════════════════════════
// TETRAPP — Lector de documentos por imagen (Claude Vision)
// Endpoint: POST /api/parse-doc
// Body JSON: { image_base64: "...", mime_type: "image/jpeg", tipo: "salida"|"ingreso" }
// Devuelve: { requi, fecha, descripcion, productos: [{sku, desc, cant}], warnings }
// ════════════════════════════════════════════════════════════════

const Anthropic = require('@anthropic-ai/sdk');

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST')    { res.status(405).end('Method Not Allowed'); return; }

  const { image_base64, mime_type, tipo } = req.body || {};
  if (!image_base64) {
    res.status(400).json({ error: 'Falta image_base64' });
    return;
  }

  const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

  const prompt = `Analizá este documento de TETRAPLAST, S.A. (Guatemala) y extraé los datos estructurados.

Es un documento de "${tipo === 'ingreso' ? 'Requi / Entrega PT' : 'Salida de Bodega / Ingresos de materiales'}".

Extraé EXACTAMENTE estos campos:
• requi: Número de documento principal (campo "Documento" — ej: "PRI2 476", "R-001")
• fecha: Fecha en formato YYYY-MM-DD (campo "Fecha" — convertí DD/MM/YY → YYYY-MM-DD; año de 2 dígitos: 26 → 2026)
• descripcion: Turno o descripción si aparece (campo "Descripción" — ej: "lunes 1 noche")
• productos: Array con TODOS los renglones de la tabla. Cada uno:
    – sku: Código numérico (columna "Código")
    – desc: Descripción del producto (columna "Producto" o "Descripción")
    – cant: Cantidad como entero (columna "Cantidad" — 2850.0000 → 2850; ignorar filas de Total)

Respondé SOLO con JSON válido, sin markdown, sin texto adicional:
{
  "requi": "PRI2 476",
  "fecha": "2026-06-02",
  "descripcion": "lunes 1 noche",
  "productos": [
    { "sku": "10008", "desc": "ENVASE TARRO 1.3 40 ONZ NATURAL PVC", "cant": 2850 }
  ],
  "warnings": []
}

Reglas: cantidad siempre entero · omitir filas de subtotal/total · si un campo no es claro ponelo en warnings.`;

  try {
    const aiResp = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 2048,
      messages: [{
        role: 'user',
        content: [
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: mime_type || 'image/jpeg',
              data: image_base64
            }
          },
          { type: 'text', text: prompt }
        ]
      }]
    });

    const raw = aiResp.content[0].text.trim()
      .replace(/^```[a-z]*\n?/, '').replace(/\n?```$/, '').trim();
    const parsed = JSON.parse(raw);
    res.json(parsed);
  } catch(e) {
    console.error('[parse-doc]', e.message);
    res.status(500).json({ error: e.message });
  }
};
