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
