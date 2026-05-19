// ════════════════════════════════════════════════════════
// SUPABASE · CONEXIÓN Y FUNCIONES COMPARTIDAS
// VERSIÓN 2.0 · CON TRAZABILIDAD DE FUGAS
// ════════════════════════════════════════════════════════

const SUPA_URL = 'https://rohdxjuuvpgrhevfsrye.supabase.co';
const SUPA_KEY = 'sb_publishable_PayfE36QRzwOnP6zA2TDSQ_oj4vnB5i';
const db = supabase.createClient(SUPA_URL, SUPA_KEY);

// ════════════════════════════════════════════════════════
// 1. SOLICITUDES (CRUD)
// ════════════════════════════════════════════════════════

// ── Generar código único de solicitud ──────────────────────
async function generarCodigo(area) {
  const prefix = area === 'tapas' ? 'T' : 'S';
  const { count } = await db
    .from('solicitudes')
    .select('id', { count: 'exact', head: true })
    .eq('area', area);
  return prefix + '-' + String((count || 0) + 1).padStart(4, '0');
}

// ── Actualizar campo en Supabase ───────────────────────────
async function actualizarEnSupabase(dbId, fields) {
  const { error } = await db.from('solicitudes').update(fields).eq('id', dbId);
  if (error) console.error('Update error:', error);
  return !error;
}

// ── Buscar solicitudes por área (filtra el listado) ────────
async function cargarSolicitudesPorArea(area) {
  const { data, error } = await db
    .from('solicitudes')
    .select(`
      *,
      solicitud_lineas (
        id, orden, sku, descripcion, cantidad, existencia_snap, procesos, operadores_ids
      )
    `)
    .eq('area', area)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error al cargar solicitudes:', error);
    return [];
  }
  return data || [];
}

// ── Cargar TODAS las solicitudes (para dashboard) ──────────
async function cargarTodasSolicitudes() {
  const { data: lineas, error: err1 } = await db
    .from('solicitud_lineas')
    .select('solicitud_id, sku, descripcion, cantidad, existencia_snap, procesos, operadores_ids, orden');

  if (err1) {
    console.error('Error cargando líneas:', err1);
    return [];
  }

  const lineasPorSol = {};
  (lineas || []).forEach(l => {
    if (!lineasPorSol[l.solicitud_id]) lineasPorSol[l.solicitud_id] = [];
    lineasPorSol[l.solicitud_id].push(l);
  });

  const { data: ops } = await db.from('solicitud_operadores').select('solicitud_id, personal(codigo)');
  const opsPorSol = {};
  (ops || []).forEach(o => {
    if (!opsPorSol[o.solicitud_id]) opsPorSol[o.solicitud_id] = [];
    if (o.personal) opsPorSol[o.solicitud_id].push(o.personal.codigo);
  });

  const { data: sols, error: err2 } = await db
    .from('solicitudes')
    .select('*')
    .order('created_at', { ascending: false });

  if (err2) {
    console.error('Error cargando solicitudes:', err2);
    return [];
  }

  return (sols || []).map(s => ({
    id: s.id,
    dbId: s.id,
    id_display: s.codigo,
    area: s.area,
    cliente: s.cliente_nombre,
    area_sol: s.area_solicitante,
    sku: (lineasPorSol[s.id]?.[0]?.sku) || '—',
    desc: lineasPorSol[s.id]?.length === 1
      ? (lineasPorSol[s.id][0].descripcion || '—')
      : (lineasPorSol[s.id]?.[0]?.descripcion || '—') +
        (lineasPorSol[s.id]?.length > 1 ? ` (+${lineasPorSol[s.id].length - 1} más)` : ''),
    lineas: (lineasPorSol[s.id] || []).map(l => ({
      sku: l.sku,
      desc: l.descripcion,
      cant: l.cantidad,
      existencia: l.existencia_snap,
      procs: l.procesos || [],
      operadores: l.operadores_ids || []
    })),
    tipo: ((lineasPorSol[s.id] || []).flatMap(l => l.procesos || [])).join('+') || 'armado',
    cant: (lineasPorSol[s.id] || []).reduce((sum, l) => sum + (l.cantidad || 0), 0),
    fecha_lim: s.fecha_limite || '',
    prio: s.prioridad,
    estado: s.estado,
    prog: s.progreso_pct || 0,
    ops: opsPorSol[s.id] || [],
    notas: s.notas || '',
    created: new Date(s.created_at).toLocaleDateString('es-GT', { day: '2-digit', month: '2-digit' }) +
      ' ' + new Date(s.created_at).toLocaleTimeString('es-GT', { hour: '2-digit', minute: '2-digit' })
  }));
}

// ════════════════════════════════════════════════════════
// 2. INVENTARIO
// ════════════════════════════════════════════════════════

let INVENTARIO_CACHE = null;
let INV_FECHA = null;

async function cargarInventarioDB() {
  const { data, error } = await db
    .from('inventario')
    .select('sku, descripcion, existencia')
    .eq('facturable', true)
    .eq('activo', true)
    .order('descripcion');

  if (!error && data && data.length > 0) {
    INVENTARIO_CACHE = data.map(i => ({
      sku: i.sku,
      descripcion: i.descripcion,
      existencia: i.existencia || 0,
      facturable: true
    }));
    INV_FECHA = new Date().toLocaleDateString('es-GT');
    console.log('📦 Inventario cargado:', INVENTARIO_CACHE.length, 'SKUs');
    return INVENTARIO_CACHE;
  }
  console.warn('⚠️ Error cargando inventario desde Supabase, usando datos locales');
  return null;
}

function getInventario() {
  return INVENTARIO_CACHE;
}

// ════════════════════════════════════════════════════════
// 3. TRAZABILIDAD DE FUGAS (NUEVO)
// ════════════════════════════════════════════════════════

// ── Registrar salida de bodega (materia prima) ────────────
async function registrarSalidaBodega(solicitudId, sku, cantidad, operadorId, observaciones = '') {
  const { data, error } = await db
    .from('movimientos_materiales')
    .insert({
      solicitud_id: solicitudId,
      tipo: 'salida_bodega',
      sku_original: sku,
      cantidad: cantidad,
      operador_id: operadorId,
      observaciones: observaciones
    })
    .select();

  if (error) {
    console.error('Error registrando salida:', error);
    return { ok: false, error: error.message };
  }

  // También descontar del inventario (si existe la tabla inventario_actual)
  await db.rpc('descontar_inventario', { p_sku: sku, p_cantidad: cantidad });

  return { ok: true, data: data?.[0] };
}

// ── Registrar entrada de producto terminado ────────────────
async function registrarEntradaPT(solicitudId, skuPT, cantidad, operadorId, observaciones = '') {
  const { data, error } = await db
    .from('movimientos_materiales')
    .insert({
      solicitud_id: solicitudId,
      tipo: 'entrada_pt',
      sku_original: skuPT,
      cantidad: cantidad,
      operador_id: operadorId,
      observaciones: observaciones
    })
    .select();

  if (error) {
    console.error('Error registrando entrada PT:', error);
    return { ok: false, error: error.message };
  }

  // Sumar al inventario
  await db.rpc('aumentar_inventario', { p_sku: skuPT, p_cantidad: cantidad });

  return { ok: true, data: data?.[0] };
}

// ── Registrar pérdida en proceso ──────────────────────────
async function registrarPerdida(solicitudId, sku, cantidad, motivo, operadorId, observaciones = '') {
  const motivosValidos = [
    'cavidad_defectuosa',
    'rechazo_calidad',
    'merma_operacion',
    'muestra_lab',
    'robo',
    'otro'
  ];

  if (!motivosValidos.includes(motivo)) {
    return { ok: false, error: `Motivo no válido: ${motivo}` };
  }

  const { data, error } = await db
    .from('movimientos_materiales')
    .insert({
      solicitud_id: solicitudId,
      tipo: 'perdida',
      sku_original: sku,
      cantidad: cantidad,
      motivo_perdida: motivo,
      operador_id: operadorId,
      observaciones: observaciones
    })
    .select();

  if (error) {
    console.error('Error registrando pérdida:', error);
    return { ok: false, error: error.message };
  }

  return { ok: true, data: data?.[0] };
}

// ── Obtener resumen de fugas por solicitud ────────────────
async function getFugasPorSolicitud(solicitudId) {
  const { data, error } = await db
    .from('movimientos_materiales')
    .select('*')
    .eq('solicitud_id', solicitudId);

  if (error) {
    console.error('Error obteniendo fugas:', error);
    return null;
  }

  const salidas = (data || []).filter(m => m.tipo === 'salida_bodega').reduce((s, m) => s + (m.cantidad || 0), 0);
  const entradas = (data || []).filter(m => m.tipo === 'entrada_pt').reduce((s, m) => s + (m.cantidad || 0), 0);
  const perdidas = (data || []).filter(m => m.tipo === 'perdida').reduce((s, m) => s + (m.cantidad || 0), 0);

  const fugaTotal = salidas - entradas - perdidas;
  const porcentajeFuga = salidas > 0 ? (fugaTotal / salidas) * 100 : 0;

  return {
    salidas,
    entradas,
    perdidas,
    fugaTotal,
    porcentajeFuga,
    detalle: data || []
  };
}

// ════════════════════════════════════════════════════════
// 4. PAROS DE MÁQUINA (OEE)
// ════════════════════════════════════════════════════════

async function registrarParoMaquina(maquinaId, motivo, duracionMinutos, operadorId, observaciones = '') {
  const motivosValidos = [
    'mantenimiento',
    'falta_material',
    'cambio_molde',
    'operador_ausente',
    'energia',
    'calidad',
    'otro'
  ];

  if (!motivosValidos.includes(motivo)) {
    return { ok: false, error: `Motivo no válido: ${motivo}` };
  }

  const fechaInicio = new Date();
  const fechaFin = new Date(fechaInicio.getTime() + duracionMinutos * 60000);

  const { data, error } = await db
    .from('paros_maquina')
    .insert({
      maquina_id: maquinaId,
      motivo: motivo,
      duracion_minutos: duracionMinutos,
      fecha_inicio: fechaInicio.toISOString(),
      fecha_fin: fechaFin.toISOString(),
      operador_id: operadorId,
      observaciones: observaciones
    })
    .select();

  if (error) {
    console.error('Error registrando paro:', error);
    return { ok: false, error: error.message };
  }

  return { ok: true, data: data?.[0] };
}

async function getParosHoy() {
  const hoy = new Date().toISOString().split('T')[0];
  const { data, error } = await db
    .from('paros_maquina')
    .select('*')
    .gte('fecha_inicio', hoy);

  if (error) {
    console.error('Error obteniendo paros:', error);
    return [];
  }
  return data || [];
}

// ════════════════════════════════════════════════════════
// 5. HELPERS DE FECHA
// ════════════════════════════════════════════════════════

function fmtFecha(date) {
  const d = new Date(date);
  return d.toLocaleDateString('es-GT', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

function fmtHora(date) {
  const d = new Date(date);
  return d.toLocaleTimeString('es-GT', { hour: '2-digit', minute: '2-digit' });
}

// ════════════════════════════════════════════════════════
// 6. INICIALIZACIÓN
// ════════════════════════════════════════════════════════

(async function initSupabase() {
  await cargarInventarioDB();
  console.log('✅ Supabase conectado · Inventario listo');
})();

// Exportar para uso en otros archivos (en vanilla JS, las funciones son globales)
window.db = db;
window.cargarInventarioDB = cargarInventarioDB;
window.getInventario = getInventario;
window.registrarSalidaBodega = registrarSalidaBodega;
window.registrarEntradaPT = registrarEntradaPT;
window.registrarPerdida = registrarPerdida;
window.getFugasPorSolicitud = getFugasPorSolicitud;
window.registrarParoMaquina = registrarParoMaquina;
window.getParosHoy = getParosHoy;
window.cargarTodasSolicitudes = cargarTodasSolicitudes;
window.generarCodigo = generarCodigo;
window.actualizarEnSupabase = actualizarEnSupabase;
