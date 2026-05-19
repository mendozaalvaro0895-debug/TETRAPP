// ════════════════════════════════════════════════════════
// HELPERS COMPARTIDOS · TETRAPLASTIC
// VERSIÓN 2.1 · LIMPIO (sin duplicar datos de data.js)
// ════════════════════════════════════════════════════════
// IMPORTANTE: este archivo depende de que data.js se cargue antes
// porque usa CFG, ESTADOS y personal definidos allí.

// ── Cálculo de horas y turnos ──────────────────────────────
function calcHoras(cant, nOps) {
  if (!cant || !nOps) return 0;
  return cant / (CFG.cap_und_h * nOps);
}

function calcTurnos(h) {
  return Math.ceil(h / CFG.turno_h);
}

function fechaEst(turnos) {
  const d = new Date();
  d.setDate(d.getDate() + turnos);
  return d.toLocaleDateString('es-GT', { day: '2-digit', month: 'short' });
}

// ── Operadores ocupados (los que están en órdenes activas) ─
function getOperadoresOcupados(solicitudesGlobal) {
  const ocupados = new Set();
  (solicitudesGlobal || []).filter(s => s.estado === 'proceso').forEach(s => {
    (s.lineas || []).forEach(l => {
      (l.operadores || []).forEach(opId => ocupados.add(opId));
    });
  });
  return ocupados;
}

// ── Horas restantes de un operador en sus órdenes ──────────
function getHorasRestantes(opId, solicitudesGlobal) {
  let totalH = 0;
  (solicitudesGlobal || []).filter(s => s.estado === 'proceso').forEach(s => {
    const asignado = (s.lineas || []).some(l => (l.operadores || []).includes(opId));
    if (asignado) {
      const h = calcHoras(s.cant, Math.max(s.ops.length, 1));
      totalH += h * (1 - (s.prog || 0) / 100);
    }
  });
  return Math.round(totalH * 10) / 10;
}

// ── Obtener operador por ID (busca en ambas áreas) ─────────
function opObj(id) {
  const all = [...(personal?.tapas || []), ...(personal?.serig || [])];
  return all.find(p => p.id === id);
}

function opName(id) {
  const p = opObj(id);
  return p ? (p.nombre?.split(' ')[0] || p.nombre) : id;
}

// ── Pills de estado y prioridad ────────────────────────────
function ePill(estado) {
  const e = ESTADOS[estado] || { css: 'p-nueva', lbl: estado };
  return `<span class="pill ${e.css}">${e.lbl}</span>`;
}

function pPill(prio) {
  const map = {
    urgente: { lbl: '🔴 Urgente', css: 'p-urg' },
    normal: { lbl: '🟢 Normal', css: 'p-norm' },
    programada: { lbl: '🟡 Programada', css: 'p-prog' },
    vela: { lbl: '🌙 Vela', css: 'p-vela' }
  };
  const p = map[prio] || map.normal;
  return `<span class="pill ${p.css}">${p.lbl}</span>`;
}

// ── Toast de notificación ──────────────────────────────────
function showToast(msg, color = 'var(--teal)') {
  const existing = document.querySelector('.toast-message');
  if (existing) existing.remove();

  const t = document.createElement('div');
  t.textContent = msg;
  t.className = 'toast-message';
  t.style.cssText = `position:fixed;bottom:28px;left:50%;transform:translateX(-50%);background:${color};color:white;padding:12px 24px;border-radius:10px;font-size:13px;font-weight:700;z-index:9999;white-space:nowrap;box-shadow:0 4px 20px rgba(0,0,0,.2)`;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 4000);
}

// ── Buscar inventario por SKU ──────────────────────────────
// Primero intenta el cache de Supabase, si no, usa el archivo local
function buscarSKU(sku) {
  if (!sku) return null;
  const inv = (typeof getInventario === 'function' && getInventario()) || (typeof INVENTARIO !== 'undefined' ? INVENTARIO : []);
  return inv.find(item => item.sku === sku);
}

function buscarPorDescripcion(query) {
  if (!query || query.length < 2) return [];
  const q = query.toLowerCase();
  const inv = (typeof getInventario === 'function' && getInventario()) || (typeof INVENTARIO !== 'undefined' ? INVENTARIO : []);
  return inv
    .filter(item =>
      (item.sku && item.sku.toLowerCase().includes(q)) ||
      ((item.descripcion || item.desc) && (item.descripcion || item.desc).toLowerCase().includes(q))
    )
    .slice(0, 8);
}
