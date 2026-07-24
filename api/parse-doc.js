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

⚠️ MÁXIMA PRECISIÓN EN LOS DÍGITOS — es un inventario, un dígito mal invalida el registro:
• Leé cada código y cada cantidad DÍGITO POR DÍGITO, sin adivinar.
• Distinguí con cuidado los pares que se confunden: 0/8, 3/8, 6/8, 2/3, 5/6, 1/7, 9/0, 4/9.
• Los códigos son enteros de 5 o 6 dígitos. Las cantidades son el entero ANTES del ".0000".
• Si un dígito NO es claramente legible, poné el código/cantidad en warnings en vez de inventar uno.
• Un producto que ocupa 2 renglones (descripción larga) es UNA sola fila; no lo dupliques.
• Contá los renglones: la cantidad de productos debe coincidir con las filas visibles de la tabla.

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
      model: 'claude-sonnet-5',
      max_tokens: 4096,
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

    const raw = aiResp.content[0].text.trim()
      .replace(/^```[a-z]*\n?/, '').replace(/\n?```$/, '').trim();
    const parsed = JSON.parse(raw);
    res.json(parsed);
  } catch(e) {
    console.error('[parse-doc]', e.message);
    res.status(500).json({ error: e.message });
  }
};
