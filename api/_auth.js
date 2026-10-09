// Helper compartido de los endpoints api/* (Vercel no expone archivos con prefijo "_").
// El chequeo corre COMO el usuario que llama (su JWT), no con la service key: `perfiles`
// no tiene grants para service_role, solo se lee vía RLS con el token del propio usuario.

const { createClient } = require('@supabase/supabase-js');

const SUPA_URL = process.env.SUPA_URL || 'https://rohdxjuuvpgrhevfsrye.supabase.co';
const SUPA_KEY = process.env.SUPA_KEY || 'sb_publishable_PayfE36QRzwOnP6zA2TDSQ_oj4vnB5i';

// Devuelve { rol, error }: rol del dueño del Bearer token, o rol=null + motivo legible.
async function rolDeSesion(req) {
  const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '').trim();
  if (!token) return { rol: null, error: 'Falta sesión' };
  try {
    const db = createClient(SUPA_URL, SUPA_KEY, {
      global: { headers: { Authorization: 'Bearer ' + token } }
    });
    const { data: userData, error: userErr } = await db.auth.getUser(token);
    if (userErr || !userData || !userData.user) return { rol: null, error: 'Sesión inválida' };
    const { data: perfil, error: perfilErr } = await db
      .from('perfiles').select('rol').eq('user_id', userData.user.id).single();
    if (perfilErr || !perfil) return { rol: null, error: 'No se encontró perfil para este usuario' };
    return { rol: perfil.rol, error: null };
  } catch (e) {
    return { rol: null, error: 'No se pudo validar la sesión' };
  }
}

const MIME_IMAGEN = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];
function mimeImagen(m) { return MIME_IMAGEN.indexOf(m) !== -1 ? m : 'image/png'; }

module.exports = { rolDeSesion, mimeImagen };
