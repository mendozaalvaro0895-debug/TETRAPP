// ════════════════════════════════════════════════════════
// SUPABASE · CONEXIÓN Y FUNCIONES COMPARTIDAS
// ════════════════════════════════════════════════════════

const SUPA_URL = 'https://rohdxjuuvpgrhevfsrye.supabase.co';
const SUPA_KEY = 'sb_publishable_PayfE36QRzwOnP6zA2TDSQ_oj4vnB5i';
const db = supabase.createClient(SUPA_URL, SUPA_KEY);

// ── Generar código único de solicitud ──────────────────────
async function generarCodigo(area) {
  const prefix = area === 'tapas' ? 'T' : 'S';
  const { count } = await db
    .from('solicitudes')
    .select('id', { count: 'exact', head: true })
    .eq('area', area);
  return prefix + String((count || 0) + 1).padStart(4, '0');
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

// ── Helpers de fecha ───────────────────────────────────────
function fmtFecha(date) {
  const d = new Date(date);
  return d.toLocaleDateString('es-GT', { day:'2-digit', month:'2-digit', year:'numeric' });
}

function fmtHora(date) {
  const d = new Date(date);
  return d.toLocaleTimeString('es-GT', { hour:'2-digit', minute:'2-digit' });
}

// ── Cargar inventario desde Supabase (COMPARTIDA · Regla #3) ─
// Intenta leer la tabla `inventario`; si falla o está vacía,
// devuelve el inventario estático de shared/inventario.js (global INVENTARIO).
// SIEMPRE retorna un array, para que los módulos puedan hacer
//   const inv = await cargarInventarioDB(); if (inv) ...
async function cargarInventarioDB() {
  try {
    const { data, error } = await db
      .from('inventario')
      .select('sku, descripcion, existencia')
      .eq('facturable', true)
      .eq('activo', true)
      .order('descripcion');
    if (!error && data && data.length > 0) {
      const inv = data.map(i => ({
        sku: i.sku,
        descripcion: i.descripcion,
        existencia: i.existencia || 0,
        facturable: true
      }));
      // Sincroniza la global INVENTARIO (declarada como const en inventario.js)
      // mutando el array en lugar de reasignarlo.
      if (typeof INVENTARIO !== 'undefined' && Array.isArray(INVENTARIO)) {
        INVENTARIO.length = 0;
        INVENTARIO.push(...inv);
      }
      console.log('Inventario cargado desde Supabase:', inv.length, 'SKUs');
      return inv;
    }
  } catch (e) {
    console.warn('cargarInventarioDB: usando inventario local. Detalle:', e);
  }
  // Respaldo: inventario estático de shared/inventario.js
  return (typeof INVENTARIO !== 'undefined' && Array.isArray(INVENTARIO)) ? INVENTARIO : [];
}
// ════════════════════════════════════════════════════════
// MÓDULO DE TRAZABILIDAD Y BODEGA (FASE 1 - Lotes)
// ════════════════════════════════════════════════════════

/**
 * Registra un movimiento de inventario asociado a una solicitud
 * @param {string} solicitudId - ID de la solicitud (ej. 'T0001')
 * @param {string} sku - Código del material
 * @param {number} cantidad - Cantidad movida
 * @param {string} tipo - 'salida_bodega', 'entrada_pt', 'perdida', 'devolucion'
 * @param {string} observaciones - Notas opcionales
 */
async function registrarMovimientoMaterial(solicitudId, sku, cantidad, tipo, observaciones = '') {
  try {
    const { error } = await db.from('movimientos_materiales').insert([{
      solicitud_id: solicitudId,
      sku: sku,
      cantidad: Number(cantidad),
      tipo: tipo,
      observaciones: observaciones,
      usuario: 'Admin' 
    }]);

    if (error) throw error;
    console.log(`✅ Movimiento registrado: ${tipo} de ${cantidad} unds (SKU: ${sku})`);
    return true;
  } catch (err) {
    console.error('❌ Error al registrar movimiento:', err);
    return false;
  }
}

/**
 * Obtiene todos los movimientos de una solicitud y calcula el balance (Fugas)
 * @param {string} solicitudId - ID de la solicitud a consultar
 */
async function obtenerBalanceLote(solicitudId) {
  try {
    const { data, error } = await db
      .from('movimientos_materiales')
      .select('*')
      .eq('solicitud_id', solicitudId);

    if (error) throw error;

    let totalSalidas = 0;
    let totalDevoluciones = 0;
    let totalProductoTerminado = 0;

    data.forEach(mov => {
      if (mov.tipo === 'salida_bodega') totalSalidas += Number(mov.cantidad);
      if (mov.tipo === 'devolucion') totalDevoluciones += Number(mov.cantidad);
      if (mov.tipo === 'entrada_pt') totalProductoTerminado += Number(mov.cantidad);
    });

    const fugasCalculadas = totalSalidas - (totalDevoluciones + totalProductoTerminado);

    return {
      movimientos: data,
      resumen: {
        salidas: totalSalidas,
        devoluciones: totalDevoluciones,
        productoTerminado: totalProductoTerminado,
        fugas: fugasCalculadas
      }
    };
  } catch (err) {
    console.error('❌ Error al obtener balance del lote:', err);
    return null;
  }
}
