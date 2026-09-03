-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Capacitaciones / Habilidades del personal
--
-- Registro de habilidades por persona, con posibilidad de certificar
-- en un área DISTINTA a la propia (ej. un operador de Tapas
-- capacitado para cubrir una máquina de Producción en almuerzo).
-- Valida un supervisor con comentario de acompañamiento y, opcional,
-- foto de respaldo (reusa el bucket Storage `justificaciones`, ya
-- creado para las faltas — sin necesidad de crear un bucket nuevo).
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.rrhh_capacitaciones (
  id           serial primary key,
  personal_id  uuid references public.personal(id) on delete set null,
  area         text not null check (area in ('tapas','serig','produccion','molino','bodega','moldes')),
  habilidad    text not null,
  estado       text not null default 'en_proceso' check (estado in ('en_proceso','certificado')),
  fecha        date not null default current_date,
  supervisor   text,
  comentario   text,
  foto_url     text,
  created_at   timestamptz not null default now()
);

create index if not exists idx_capacitaciones_personal on public.rrhh_capacitaciones(personal_id);
create index if not exists idx_capacitaciones_area      on public.rrhh_capacitaciones(area);
create index if not exists idx_capacitaciones_fecha     on public.rrhh_capacitaciones(fecha desc);

-- RLS — master-only (mismo patrón que rrhh_permisos/rrhh_incidentes/rrhh_faltas)
alter table public.rrhh_capacitaciones enable row level security;

drop policy if exists "capacitaciones_master_todo" on public.rrhh_capacitaciones;
create policy "capacitaciones_master_todo" on public.rrhh_capacitaciones
  for all to authenticated
  using (public.es_master())
  with check (public.es_master());

revoke all on public.rrhh_capacitaciones from anon;
grant select, insert, update, delete on public.rrhh_capacitaciones to authenticated;
grant usage, select on sequence public.rrhh_capacitaciones_id_seq to authenticated;

notify pgrst, 'reload schema';

-- Verificación
select tablename, rowsecurity from pg_tables
where schemaname = 'public' and tablename = 'rrhh_capacitaciones';

select count(*) as filas_iniciales from public.rrhh_capacitaciones;
