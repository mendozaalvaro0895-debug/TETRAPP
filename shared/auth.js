// ═══════════════════════════════════════════════════════════════
// TETRAPP — shared/auth.js · Guardián de sesión y roles v1.0
// Se carga en TODOS los HTML (excepto login.html), justo después
// del CDN de supabase-js y ANTES del <script> propio de la página.
//
// Provee a cada página (reemplaza sus declaraciones locales):
//   SUPA_URL, SUPA_KEY, db (cliente único), HEADERS (con token vivo)
//   TETRA = { rol, nombre, email, esVisor }
//
// Reglas:
//   - Sin sesión → redirige a login.html
//   - Sesión sin perfil → cierra sesión y redirige (usuario no autorizado)
//   - Rol visor → banner "Modo Visual" + bloqueo de escrituras en cliente
//     (la protección REAL es el RLS en Supabase; esto es solo UX)
// ═══════════════════════════════════════════════════════════════

var SUPA_URL = 'https://rohdxjuuvpgrhevfsrye.supabase.co';
var SUPA_KEY = 'sb_publishable_PayfE36QRzwOnP6zA2TDSQ_oj4vnB5i';
var db = supabase.createClient(SUPA_URL, SUPA_KEY);
var HEADERS = { 'apikey': SUPA_KEY, 'Authorization': 'Bearer ' + SUPA_KEY, 'Content-Type': 'application/json' };
var TETRA = { rol: null, nombre: '', email: null, esVisor: false };

// ── Escape universal anti-XSS para texto dinámico en innerHTML ──
// (serigrafia.html tiene su propia copia equivalente; misma firma)
function escHtml(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// ── Ocultar la página hasta validar sesión (anti-flash) ─────────
(function () {
  var st = document.createElement('style');
  st.id = 'tetra-auth-veil';
  st.textContent = 'html{visibility:hidden}';
  document.head.appendChild(st);
  // Red de seguridad: si algo falla, revelar a los 5s (los datos
  // igual no cargan sin sesión — RLS los bloquea del lado servidor)
  setTimeout(tetraRevelar, 5000);
})();

function tetraRevelar() {
  var v = document.getElementById('tetra-auth-veil');
  if (v) v.remove();
}

// ── Bloqueo de escrituras en modo visor (capa UX) ────────────────
(function () {
  var fetchOriginal = window.fetch.bind(window);
  window.fetch = function (input, init) {
    var url = String(input && input.url ? input.url : input);
    var method = ((init && init.method) || (input && input.method) || 'GET').toUpperCase();
    var esEscritura = method !== 'GET' && method !== 'HEAD';
    var esSupa = url.indexOf(SUPA_URL) === 0;
    var esAuth = url.indexOf(SUPA_URL + '/auth/') === 0;
    if (TETRA.esVisor && esSupa && !esAuth && esEscritura) {
      tetraToastVisor();
      return Promise.resolve(new Response(
        JSON.stringify({ message: 'Modo Visual: sin permisos de edición', code: 'visor' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      ));
    }
    return fetchOriginal(input, init);
  };
})();

var tetraToastTimer = null;
function tetraToastVisor() {
  var t = document.getElementById('tetraToastVisor');
  if (!t) {
    t = document.createElement('div');
    t.id = 'tetraToastVisor';
    t.style.cssText = 'position:fixed;bottom:24px;left:50%;transform:translateX(-50%);background:#0C0C0B;color:#fff;padding:12px 22px;border-radius:12px;font:600 13px "DM Sans",sans-serif;z-index:99999;box-shadow:0 8px 28px rgba(0,0,0,.4);border:1px solid #B87200;display:none;align-items:center;gap:8px';
    t.innerHTML = '👁 Modo Visual — no tienes permisos de edición';
    document.body.appendChild(t);
  }
  t.style.display = 'flex';
  clearTimeout(tetraToastTimer);
  tetraToastTimer = setTimeout(function () { t.style.display = 'none'; }, 2600);
}

function tetraBannerVisor() {
  document.body.classList.add('rol-visor');
  var b = document.createElement('div');
  b.id = 'tetraBannerVisor';
  b.style.cssText = 'background:#FEF3C7;border-bottom:1.5px solid #FDE68A;color:#92400E;font:600 12px "DM Sans",sans-serif;text-align:center;padding:7px 16px;letter-spacing:.3px';
  b.innerHTML = '👁 MODO VISUAL — acceso de solo lectura, sin permisos de edición';
  var topbar = document.querySelector('.topbar');
  if (topbar && topbar.parentNode) topbar.parentNode.insertBefore(b, topbar.nextSibling);
  else document.body.insertBefore(b, document.body.firstChild);
}

// ── Pill de usuario + cerrar sesión ──────────────────────────────
function tetraPintarUsuario() {
  var pill = document.querySelector('.user-pill');
  if (!pill) return;
  var nombre = TETRA.nombre || TETRA.email || 'Usuario';
  var iniciales = nombre.trim().split(/\s+/).map(function (p) { return p[0]; }).slice(0, 2).join('').toUpperCase();
  var avCls = pill.querySelector('.uavatar') ? 'uavatar' : 'user-av';
  pill.innerHTML = '<div class="' + avCls + '" style="color:#fff">' + iniciales + '</div>' +
    '<span style="color:#fff;font-size:12px;font-weight:600">' + nombre.replace(/[<>&"]/g, '') + '</span>' +
    '<span style="color:rgba(255,255,255,.65);font-size:11px;margin-left:6px;cursor:pointer;white-space:nowrap" title="Cerrar sesión">⏻ Salir</span>';
  pill.style.cursor = 'pointer';
  pill.title = 'Cerrar sesión (' + (TETRA.email || '') + ')';
  pill.onclick = function () {
    if (confirm('¿Cerrar sesión?')) {
      db.auth.signOut().then(function () { location.replace('login.html'); });
    }
  };
}

// ── Validación de sesión y carga de rol ──────────────────────────
(async function tetraGuard() {
  try {
    var s = await db.auth.getSession();
    var session = s && s.data ? s.data.session : null;
    if (!session) { location.replace('login.html'); return; }

    HEADERS['Authorization'] = 'Bearer ' + session.access_token;
    TETRA.email = session.user.email;

    var r = await db.from('perfiles').select('rol,nombre').eq('user_id', session.user.id).single();
    if (r.error || !r.data) {
      // Usuario autenticado pero SIN perfil autorizado → fuera
      await db.auth.signOut();
      location.replace('login.html?e=noperfil');
      return;
    }

    TETRA.rol = r.data.rol;
    TETRA.nombre = r.data.nombre || session.user.email;
    TETRA.esVisor = r.data.rol !== 'master';

    var pintar = function () {
      if (TETRA.esVisor) tetraBannerVisor();
      tetraPintarUsuario();
      tetraRevelar();
    };
    if (document.body) pintar();
    else document.addEventListener('DOMContentLoaded', pintar);
  } catch (e) {
    console.error('TETRA auth:', e);
    location.replace('login.html');
  }
})();

// ── Mantener HEADERS con el token renovado ───────────────────────
db.auth.onAuthStateChange(function (evento, session) {
  if (session && session.access_token) {
    HEADERS['Authorization'] = 'Bearer ' + session.access_token;
  }
  if (evento === 'SIGNED_OUT') location.replace('login.html');
});
