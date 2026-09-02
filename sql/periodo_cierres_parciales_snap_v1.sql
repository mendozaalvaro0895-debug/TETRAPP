-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Snapshot de parciales en cierres de período
-- Agrega dos columnas a periodo_cierres:
--   und_ambar_ent  → und REALMENTE entregadas de fichas parciales
--                    (el und_ambar existente guarda las solicitadas)
--   parciales_snap → JSON [{codigo,cliente,cant,ent}] por ficha parcial
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

-- ── 1. Nuevas columnas ───────────────────────────────────────────
alter table public.periodo_cierres
  add column if not exists und_ambar_ent  integer not null default 0,
  add column if not exists parciales_snap jsonb   not null default '[]'::jsonb;

-- ── 2. Refrescar caché PostgREST ─────────────────────────────────
notify pgrst, 'reload schema';

-- ── 3. Reparar cierres de agosto (und_ambar_ent) ─────────────────
-- Calcula las und entregadas reales de fichas aún activas (no lista)
-- para cada cliente con cierre de agosto, desde entregas_serig.
-- Los completados (lista) ya están en und_verde; este query solo toca partials.
update public.periodo_cierres pc
set und_ambar_ent = coalesce((
  select sum(e.cant)
  from entregas_serig e
  join solicitudes   s on s.id::text = e.sol_id
  where s.cliente_nombre = pc.cliente
    and s.area            = 'serig'
    and s.deleted_at      is null
    and s.estado          not in ('lista')
), 0)
where pc.area = 'serig'
  and pc.periodo_key = '2026-08';

-- ── 4. Verificación ──────────────────────────────────────────────
select cliente, periodo_key, und_ambar, und_ambar_ent,
       jsonb_array_length(parciales_snap) as snap_items
from periodo_cierres
where area = 'serig'
order by periodo_key, cliente;
