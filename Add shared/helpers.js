// ════════════════════════════════════════════════════════
// HELPERS COMPARTIDOS · TETRAPLASTIC
// Funciones de cálculo, formato y utilidades comunes
// ════════════════════════════════════════════════════════

// ── Cálculo de horas y turnos ──────────────────────────────
function calcHoras(cant, nOps) {
  if (!cant || !nOps) return 0;
  return cant / (CFG.cap_und_h * nOps);
}

function calcTurnos(h) {
  return Math.ceil(h / CFG.turno_h);
}

// ── Operadores ocupados (los que están en órdenes activas) ─
function getOperadoresOcupados() {
  const ocupados = new Set();
  solicitudes.filter(s => s.estado === 'proceso').forEach(s => {
    (s.lineas || []).forEach(l => {
      (l.operadores || []).forEach(opId => ocupados.add(opId));
    });
  });
  return ocupados;
}

// ── Horas restantes de un operador en sus órdenes ──────────
function getHorasRestantes(opId) {
  let totalH = 0;
  solicitudes.filter(s => s.estado === 'proceso').forEach(s => {
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
  return personal.tapas.concat(personal.serig).find(p => p.id === id);
}

function opName(id) {
  const p = opObj(id);
  return p ? p.nombre : id;
}

// ── Pills de estado y prioridad ────────────────────────────
function ePill(estado) {
  const e = ESTADOS[estado] || { css: 'p-nueva', lbl: estado };
  return `<span class="pill ${e.css}">${e.lbl}</span>`;
}

function pPill(prio) {
  const map = {
    urgente:    { lbl:'🔴 Urgente',    css:'p-urg'  },
    normal:     { lbl:'🟢 Normal',     css:'p-norm' },
    programada: { lbl:'🟡 Programada', css:'p-prog' },
    vela:       { lbl:'🌙 Vela',       css:'p-vela' }
  };
  const p = map[prio] || map.normal;
  return `<span class="pill ${p.css}">${p.lbl}</span>`;
}

// ── Toast de notificación ──────────────────────────────────
function showToast(msg, color = 'var(--teal)') {
  const t = document.createElement('div');
  t.textContent = msg;
  t.style.cssText = `position:fixed;bottom:28px;left:50%;transform:translateX(-50%);background:${color};color:white;padding:12px 24px;border-radius:10px;font-size:13px;font-weight:700;z-index:9999;white-space:nowrap;box-shadow:0 4px 20px rgba(0,0,0,.2)`;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 4000);
}

// ── Buscar inventario por SKU ──────────────────────────────
function buscarSKU(sku) {
  if (!sku) return null;
  return INVENTARIO.find(item => item.sku === sku);
}

function buscarPorDescripcion(query) {
  if (!query || query.length < 2) return [];
  const q = query.toLowerCase();
  return INVENTARIO
    .filter(item =>
      (item.sku && item.sku.toLowerCase().includes(q)) ||
      (item.desc && item.desc.toLowerCase().includes(q))
    )
    .slice(0, 8);
}
