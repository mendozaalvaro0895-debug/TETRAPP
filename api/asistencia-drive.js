// ════════════════════════════════════════════════════════════════
// TETRAPP — Lee la hoja "ASISTENCIA DE PLANTA" (Google Sheets) y la devuelve normalizada
// Endpoint: GET /api/asistencia-drive?mes=YYYY-MM   (default: mes actual en Guatemala)
// Devuelve: { mes, hoja, personas: [{ nombre, area, turno_prod, ingreso, rol, estados:{fecha:estado},
//             baja_desde }], estados_desconocidos: [] }
//
// Estados normalizados: presente | ausente | velada | tarde | permiso | baja
//
// Solo rol master (api/_auth.js). La hoja debe estar compartida "cualquiera con el enlace puede VER".
// Env: ASISTENCIA_SHEET_ID (id de la hoja — NO se guarda en el repo, el enlace da acceso a la hoja).
// Cada pestaña se llama como el mes (ENE…DIC). Secciones por área en la columna A (SERIGRAFIA, TAPAS, …).
// ════════════════════════════════════════════════════════════════

const { rolDeSesion } = require('./_auth');

const MESES = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
const ABR_MES = { ene: 1, feb: 2, mar: 3, abr: 4, may: 5, jun: 6, jul: 7, ago: 8, sep: 9, oct: 10, nov: 11, dic: 12 };

// Encabezado de sección (col A) → área de TETRAPP (personal.area)
const SECCIONES = {
  'GRUPO GABINO': { area: 'produccion', turno: 'gabino' },
  'GRUPO ALEX': { area: 'produccion', turno: 'alex' },
  'SERIGRAFIA': { area: 'serig', turno: null },
  'TAPAS': { area: 'tapas', turno: null },
  'BODEGA': { area: 'bodega', turno: null },
  'MANTENIMIENTO': { area: 'mantenimiento', turno: null },
  'TORNO': { area: 'torno', turno: null },
  'MOLDES': { area: 'moldes', turno: null },
  'MOLINO': { area: 'molino', turno: null },
  'OFICINA': { area: 'oficina', turno: null }
};

function normalizar(s) {
  return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().replace(/\s+/g, ' ').trim();
}

// CSV con comillas, comillas dobladas y saltos de línea dentro de una celda ("4-oct\nDOM")
function parseCsv(texto) {
  const filas = [];
  let fila = [], celda = '', comillas = false;
  for (let i = 0; i < texto.length; i++) {
    const c = texto[i];
    if (comillas) {
      if (c === '"') {
        if (texto[i + 1] === '"') { celda += '"'; i++; } else { comillas = false; }
      } else { celda += c; }
    } else if (c === '"') { comillas = true; }
    else if (c === ',') { fila.push(celda); celda = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && texto[i + 1] === '\n') i++;
      fila.push(celda); filas.push(fila); fila = []; celda = '';
    } else { celda += c; }
  }
  if (celda !== '' || fila.length) { fila.push(celda); filas.push(fila); }
  return filas;
}

function normEstado(raw) {
  const t = normalizar(raw);
  if (t === 'PRESENTE') return 'presente';
  if (t === 'NO PRESENTE') return 'ausente';
  if (t === 'VELADA') return 'velada';
  if (t === 'TARDE') return 'tarde';
  if (t === 'PERMISO') return 'permiso';
  if (t.indexOf('BAJA') !== -1 || t.indexOf('RENUNCIA') !== -1) return 'baja';
  if (t.indexOf('VIAJE') !== -1) return 'permiso';   // "Viaje laboral": trabaja fuera de planta, cuenta como presente
  return null;
}

function parseIngreso(s) {
  const m = String(s || '').trim().match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (!m) return null;
  return m[3] + '-' + m[2].padStart(2, '0') + '-' + m[1].padStart(2, '0');
}

function pad(n) { return String(n).padStart(2, '0'); }

function parsearHoja(csv, anio, mes) {
  const filas = parseCsv(csv);
  if (!filas.length || normalizar(filas[0][0]) !== 'NOMBRE Y APELLIDO') {
    return { error: 'La pestaña no tiene el formato esperado (¿existe la pestaña del mes?)' };
  }
  const cols = [];
  filas[0].forEach(function (h, c) {
    if (c < 3) return;
    const m = String(h || '').match(/^\s*(\d{1,2})\s*-\s*([A-Za-z]{3})/);
    if (!m) return;
    const mm = ABR_MES[m[2].toLowerCase()] || mes;
    cols.push({ c: c, fecha: anio + '-' + pad(mm) + '-' + pad(parseInt(m[1], 10)) });
  });

  const personas = [], desconocidos = {};
  let sec = null;
  for (let i = 1; i < filas.length; i++) {
    const f = filas[i];
    const nombre = String(f[0] || '').trim();
    if (!nombre) continue;
    const esSeccion = SECCIONES[normalizar(nombre)];
    if (esSeccion && !String(f[1] || '').trim() && !String(f[2] || '').trim()) { sec = esSeccion; continue; }
    if (!sec) continue;
    const estados = {};
    let bajaDesde = null;
    cols.forEach(function (col) {
      const raw = String(f[col.c] || '').trim();
      if (!raw) return;
      const est = normEstado(raw);
      if (!est) { desconocidos[raw] = true; return; }
      estados[col.fecha] = est;
      if (est === 'baja' && (!bajaDesde || col.fecha < bajaDesde)) bajaDesde = col.fecha;
    });
    personas.push({
      nombre: nombre, area: sec.area, turno_prod: sec.turno,
      ingreso: parseIngreso(f[1]), rol: String(f[2] || '').trim(),
      estados: estados, baja_desde: bajaDesde
    });
  }
  return { personas: personas, estados_desconocidos: Object.keys(desconocidos) };
}

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'GET') return res.status(405).json({ error: 'Método no permitido' });

  const { rol, error } = await rolDeSesion(req);
  if (!rol) return res.status(401).json({ error: error || 'Sin sesión' });
  if (rol !== 'master') return res.status(403).json({ error: 'Solo master' });

  const sheetId = process.env.ASISTENCIA_SHEET_ID;
  if (!sheetId) return res.status(500).json({ error: 'Falta la variable de entorno ASISTENCIA_SHEET_ID en Vercel' });

  const hoyGT = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString().slice(0, 7);
  const mesParam = String((req.query && req.query.mes) || hoyGT);
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(mesParam)) return res.status(400).json({ error: 'mes inválido (YYYY-MM)' });
  const anio = parseInt(mesParam.slice(0, 4), 10), mes = parseInt(mesParam.slice(5, 7), 10);
  const hoja = MESES[mes - 1];

  try {
    const url = 'https://docs.google.com/spreadsheets/d/' + encodeURIComponent(sheetId) +
      '/gviz/tq?tqx=out:csv&sheet=' + encodeURIComponent(hoja);
    const r = await fetch(url, { signal: AbortSignal.timeout(20000) });
    if (!r.ok) return res.status(502).json({ error: 'Google respondió ' + r.status + ' — ¿la hoja está compartida con el enlace?' });
    const csv = await r.text();
    const out = parsearHoja(csv, anio, mes);
    if (out.error) return res.status(404).json({ error: out.error + ' [' + hoja + ']' });
    return res.status(200).json({ mes: mesParam, hoja: hoja, personas: out.personas, estados_desconocidos: out.estados_desconocidos });
  } catch (e) {
    return res.status(502).json({ error: 'No se pudo leer la hoja: ' + (e && e.message ? e.message : e) });
  }
};

module.exports.parsearHoja = parsearHoja;
