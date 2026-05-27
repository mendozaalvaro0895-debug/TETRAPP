// ════════════════════════════════════════════════════════
// TETRAPLASTIC - FUNCIONES COMPARTIDAS
// ════════════════════════════════════════════════════════

// Funciones de UI
function ePill(estado) {
  const clases = {
    'nueva': 'pill-pendiente',
    'programada': 'pill-programada',
    'proceso': 'pill-proceso',
    'lista': 'pill-lista',
    'entregada': 'pill-entregada'
  };
  const textos = {
    'nueva': '🟡 Nueva',
    'programada': '📅 Programada',
    'proceso': '🟢 En proceso',
    'lista': '✅ Lista',
    'entregada': '📦 Entregada'
  };
  return `<span class="pill ${clases[estado] || 'pill-pendiente'}">${textos[estado] || estado}</span>`;
}

function pPill(prioridad) {
  const clases = {
    'normal': 'pill-normal',
    'urgente': 'pill-urgente',
    'programada': 'pill-programada',
    'vela': 'pill-vela'
  };
  const textos = {
    'normal': '🟢 Normal',
    'urgente': '🔴 Urgente',
    'programada': '📅 Programada',
    'vela': '🌙 Vela'
  };
  return `<span class="pill ${clases[prioridad] || 'pill-normal'}">${textos[prioridad] || prioridad}</span>`;
}

function calcHoras(cantidad, opsCount = 1) {
  const velocidadBase = 1200; // und/hora por operador
  return cantidad / (velocidadBase * opsCount);
}

function fechaEst(turnos) {
  const fecha = new Date();
  fecha.setDate(fecha.getDate() + turnos);
  return fecha.toLocaleDateString('es-GT');
}

async function generarCodigo(area) {
  const prefix = area === 'tapas' ? 'T' : 'S';
  try {
    const { data, error } = await db
      .from('solicitudes')
      .select('codigo')
      .eq('area', area)
      .order('created_at', { ascending: false })
      .limit(1);
    
    if (error) throw error;
    
    let lastNum = 0;
    if (data && data.length > 0 && data[0].codigo) {
      const match = data[0].codigo.match(/\d+$/);
      if (match) lastNum = parseInt(match[0]);
    }
    const newNum = lastNum + 1;
    return `${prefix}-${String(newNum).padStart(3, '0')}`;
  } catch (e) {
    console.error('Error generando código:', e);
    return `${prefix}-001`;
  }
}

async function actualizarEnSupabase(id, datos) {
  const { error } = await db.from('solicitudes').update(datos).eq('id', id);
  if (error) throw error;
  return true;
}

async function cargarInventarioDB() {
  try {
    const { data, error } = await db
      .from('inventario')
      .select('sku, descripcion, existencia')
      .eq('activo', true)
      .limit(500);
    
    if (error) throw error;
    return data || [];
  } catch (e) {
    console.error('Error cargando inventario:', e);
    return [];
  }
}

// Trazabilidad de fugas
async function registrarPerdida(solicitudId, sku, cantidad, motivo, usuario, obs) {
  try {
    const { error } = await db.from('movimientos_materiales').insert({
      solicitud_id: solicitudId,
      sku: sku,
      cantidad: cantidad,
      tipo: 'perdida',
      usuario: usuario,
      observaciones: `${motivo} - ${obs}`
    });
    return { ok: !error, error: error?.message };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

async function registrarEntradaPT(solicitudId, sku, cantidad, usuario, obs) {
  try {
    const { error } = await db.from('movimientos_materiales').insert({
      solicitud_id: solicitudId,
      sku: sku,
      cantidad: cantidad,
      tipo: 'entrada_pt',
      usuario: usuario,
      observaciones: obs
    });
    return { ok: !error, error: error?.message };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

async function registrarSalidaBodega(solicitudId, sku, cantidad, usuario, obs) {
  try {
    const { error } = await db.from('movimientos_materiales').insert({
      solicitud_id: solicitudId,
      sku: sku,
      cantidad: cantidad,
      tipo: 'salida_bodega',
      usuario: usuario,
      observaciones: obs
    });
    return { ok: !error, error: error?.message };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

async function registrarParoMaquina(maquinaId, motivo, duracion, usuario, obs) {
  try {
    const { error } = await db.from('paros_maquina').insert({
      maquina_id: maquinaId,
      motivo: motivo,
      duracion_minutos: duracion,
      usuario: usuario,
      observaciones: obs
    });
    return { ok: !error, error: error?.message };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

// Asegurar que db esté disponible
if (typeof db === 'undefined') {
  console.warn('⚠️ db no está definido. Asegúrate de que supabase.js se cargue antes.');
}
