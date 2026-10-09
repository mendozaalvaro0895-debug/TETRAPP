// ════════════════════════════════════════════════════════════════
// TETRAPP — Lector de documentos por imagen (Claude Vision)
// Endpoint: POST /api/parse-doc
// Header:   Authorization: Bearer <access_token de sesión — rol master u operativo_prod>
// Body JSON: { image_base64: "...", mime_type: "image/jpeg", tipo: "salida"|"ingreso" }
// Devuelve: { requi, fecha, descripcion, productos: [{sku, desc, cant}], warnings }
// Lo usan produccion.html (master + operativo_prod) y serigrafia.html (master).
// ════════════════════════════════════════════════════════════════

const Anthropic = require('@anthropic-ai/sdk');
const { rolDeSesion, mimeImagen } = require('./_auth');

const ROLES_PERMITIDOS = ['master', 'operativo_prod'];

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST')    { res.status(405).end('Method Not Allowed'); return; }

  const sesion = await rolDeSesion(req);
  if (!sesion.rol) { res.status(401).json({ error: sesion.error || 'No autorizado' }); return; }
  if (ROLES_PERMITIDOS.indexOf(sesion.rol) === -1) {
    res.status(403).json({ error: 'Sin permiso para leer documentos con IA' });
    return;
  }

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
• fecha: Fecha en formato YYYY-MM-DD (campo "Fecha"). Año de 2 dígitos: 26 → 2026.
    ⚠️ EL DOCUMENTO USA DÍA/MES/AÑO (formato de Guatemala). El PRIMER número es el DÍA,
    el SEGUNDO es el MES. NUNCA lo leas como mes/día, aunque ambos sean ≤ 12 y las dos
    lecturas parezcan válidas — ahí es donde se cometen los errores.
       01/09/26 → 2026-09-01  (1 de septiembre — NO el 9 de enero)
       08/01/26 → 2026-01-08  (8 de enero — NO el 1 de agosto)
       09/05/26 → 2026-05-09  (9 de mayo — NO el 5 de septiembre)
    Si el primer número es mayor a 12, confirma que es día/mes: 25/07/26 → 2026-07-25.
    Si la fecha está borrosa o el orden no se puede determinar, ponela en warnings.
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
  "fecha": "2026-06-25",
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
              media_type: mimeImagen(mime_type),
              data: image_base64
            }
          },
          { type: 'text', text: prompt }
        ]
      }]
    });

    // Buscar el bloque de texto (Sonnet puede devolver otros tipos de bloque primero)
    const textBlock = (aiResp.content || []).find(function(b) { return b.type === 'text' && b.text; });
    if (!textBlock) throw new Error('La IA no devolvió texto legible');
    const raw = textBlock.text.trim()
      .replace(/^```[a-z]*\n?/, '').replace(/\n?```$/, '').trim();
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch(pe) {
      console.error('[parse-doc] JSON inválido:', raw.slice(0, 300));
      throw new Error('Respuesta no es JSON válido');
    }
    res.json(parsed);
  } catch(e) {
    console.error('[parse-doc]', e.message);
    res.status(500).json({ error: e.message });
  }
};
