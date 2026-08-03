-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Módulo Producción (Sopladoras) v1.0
-- Correr en Supabase Dashboard → SQL Editor
--
-- Crea:
--   · produccion_diaria  — una fila por (fecha, turno, máquina, sku)
--   · inventario.meta_12hrs             — capacidad de producción en 12 hrs
--   · inventario.maquina_default        — máquina habitual del SKU (pre-llenado)
--   · inventario.precio_ponderado_manual— respaldo cuando el SKU no tiene ventas
--
-- El precio ponderado se calcula automáticamente desde la tabla `ventas`
-- (últimos 3 meses, ponderado por unidades). La columna manual es solo
-- el fallback para SKUs que se producen pero no se facturan.
-- ════════════════════════════════════════════════════════════════


-- ── PASO 1: tabla de producción diaria ───────────────────────────
create table if not exists public.produccion_diaria (
  id          bigint generated always as identity primary key,
  fecha       date        not null,
  turno       text        not null,
  maquina     smallint    not null default 0,   -- 0 = sin asignar
  sku         text        not null,
  descripcion text,
  cantidad    numeric     not null default 0,
  origen      text,                              -- 'pdf' | 'manual'
  created_at  timestamptz not null default now()
);

-- turno solo acepta dia/noche
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'produccion_diaria_turno_check'
  ) then
    alter table public.produccion_diaria
      add constraint produccion_diaria_turno_check
      check (turno in ('dia','noche'));
  end if;
end $$;

-- una sola fila por combinación → permite recargar un turno corregido
create unique index if not exists ux_prod_fecha_turno_maq_sku
  on public.produccion_diaria (fecha, turno, maquina, sku);

create index if not exists idx_prod_fecha   on public.produccion_diaria (fecha);
create index if not exists idx_prod_sku     on public.produccion_diaria (sku);
create index if not exists idx_prod_maquina on public.produccion_diaria (maquina);


-- ── PASO 2: columnas de producción en inventario ─────────────────
alter table public.inventario add column if not exists meta_12hrs              numeric;
alter table public.inventario add column if not exists maquina_default         smallint;
alter table public.inventario add column if not exists precio_ponderado_manual numeric;

comment on column public.inventario.meta_12hrs is
  'Capacidad de producción en un turno de 12 horas. Base del cálculo de eficiencia.';
comment on column public.inventario.maquina_default is
  'Máquina habitual del SKU. Pre-llena la asignación al importar producción.';
comment on column public.inventario.precio_ponderado_manual is
  'Precio de respaldo. Solo se usa si el SKU no tiene ventas facturadas en el periodo.';


-- ── PASO 3: RLS ──────────────────────────────────────────────────
alter table public.produccion_diaria enable row level security;

drop policy if exists lectura_con_perfil on public.produccion_diaria;
drop policy if exists insert_master      on public.produccion_diaria;
drop policy if exists update_master      on public.produccion_diaria;
drop policy if exists delete_master      on public.produccion_diaria;

create policy lectura_con_perfil on public.produccion_diaria
  for select to authenticated
  using (rol_actual() is not null);

create policy insert_master on public.produccion_diaria
  for insert to authenticated
  with check (es_master());

create policy update_master on public.produccion_diaria
  for update to authenticated
  using (es_master()) with check (es_master());

create policy delete_master on public.produccion_diaria
  for delete to authenticated
  using (es_master());

revoke all on public.produccion_diaria from anon;
grant select, insert, update, delete on public.produccion_diaria to authenticated;


-- ── PASO 4: refrescar el cache del API ───────────────────────────
notify pgrst, 'reload schema';


-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN — correr después y revisar los resultados
-- ════════════════════════════════════════════════════════════════

-- 1) La tabla existe y tiene RLS activa
select tablename, rowsecurity
from pg_tables
where schemaname = 'public' and tablename = 'produccion_diaria';

-- 2) Las 4 políticas quedaron creadas
select policyname, cmd
from pg_policies
where schemaname = 'public' and tablename = 'produccion_diaria'
order by policyname;

-- 3) Las columnas nuevas en inventario
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'inventario'
  and column_name in ('meta_12hrs','maquina_default','precio_ponderado_manual')
order by column_name;

-- 4) Conteo inicial (debe ser 0 en instalación limpia)
select count(*) as filas_produccion from public.produccion_diaria;
