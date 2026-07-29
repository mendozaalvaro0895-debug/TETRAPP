-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Cierre mensual de fichas "Sin asignar" (Serigrafía) v1.0
--
-- Permite congelar el % de avance de un período (ej. JULIO) al cierre
-- del mes, y trasladar los pedidos aún pendientes al período siguiente
-- (AGOSTO) SIN duplicar la fila del pedido — solo se reasigna su
-- período efectivo. El pedido original nunca se copia ni se borra.
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Es idempotente:
-- se puede correr varias veces sin romper nada.
-- ════════════════════════════════════════════════════════════════

-- ── 1. Override manual de período en solicitudes ──────────────────
-- NULL (default) = el período se sigue calculando de created_at, como
-- siempre. Solo se llena cuando un pedido pendiente se traslada al
-- cerrar el mes anterior.
alter table public.solicitudes
  add column if not exists periodo_efectivo text;

-- ── 2. Registro histórico permanente del cierre de cada período ───
-- Una fila por cliente + período cerrado. Los números quedan fijos
-- para siempre — no se recalculan aunque los pedidos sigan avanzando
-- después del traslado.
create table if not exists public.periodo_cierres (
  id             uuid primary key default gen_random_uuid(),
  cliente        text not null,
  periodo_key    text not null,   -- ej. '2026-07'
  periodo_label  text not null,   -- ej. 'JULIO 2026'
  pct_entregado  integer not null default 0,
  n_total        integer not null default 0,  -- líneas totales del período (mismo criterio que la ficha en vivo)
  n_listos       integer not null default 0,
  n_parciales    integer not null default 0,
  n_pendientes   integer not null default 0,
  und_total      integer not null default 0,
  und_verde      integer not null default 0,
  und_ambar      integer not null default 0,
  und_rojo       integer not null default 0,
  area           text not null default 'serig',
  fecha_cierre   timestamptz not null default now(),
  unique (cliente, periodo_key, area)
);

-- ── 3. RLS + políticas (mismo patrón que registro_flameado_serig) ──
alter table public.periodo_cierres enable row level security;

drop policy if exists lectura_con_perfil on public.periodo_cierres;
create policy lectura_con_perfil on public.periodo_cierres
  for select to authenticated using (public.rol_actual() is not null);

drop policy if exists insert_master on public.periodo_cierres;
create policy insert_master on public.periodo_cierres
  for insert to authenticated with check (public.es_master());

drop policy if exists update_master on public.periodo_cierres;
create policy update_master on public.periodo_cierres
  for update to authenticated using (public.es_master()) with check (public.es_master());

drop policy if exists delete_master on public.periodo_cierres;
create policy delete_master on public.periodo_cierres
  for delete to authenticated using (public.es_master());

revoke all on public.periodo_cierres from anon;
grant select, insert, update, delete on public.periodo_cierres to authenticated;

-- ── 4. Refrescar el caché de esquema de PostgREST ─────────────────
notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ════════════════════════════════════════════════════════════════
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'solicitudes' and column_name = 'periodo_efectivo';

select tablename, rowsecurity from pg_tables
where schemaname = 'public' and tablename = 'periodo_cierres';

select tablename, policyname, cmd, roles from pg_policies
where schemaname = 'public' and tablename = 'periodo_cierres'
order by cmd, policyname;
