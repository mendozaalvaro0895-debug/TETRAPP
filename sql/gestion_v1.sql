-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Módulo Gestión de Personal y Planta v1.0
-- Tablas nuevas:
--   · mejoras_planta    (seguimiento de mejoras de infraestructura)
--   · rrhh_permisos     (permisos / ausencias / tardanzas)
--   · rrhh_incidentes   (accidentes / amonestaciones / reconocimientos)
-- Columnas nuevas en tabla existente:
--   · personal: locker · talla_uniforme · epp_asignado · epp_fecha · notas_rrhh
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor.
-- Es idempotente: se puede correr varias veces sin romper nada.
-- Patrón RLS: es_master() escribe todo · rol_actual() IS NOT NULL lee
--   (rrhh_permisos y rrhh_incidentes son master-only incluso en lectura).
-- ════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────
-- 1. MEJORAS DE PLANTA (infraestructura)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.mejoras_planta (
  id             serial primary key,
  titulo         text not null,
  descripcion    text,
  area           text not null default 'General',
    -- Producción · Serigrafía · Tapas · Bodega · Oficina · General
  estado         text not null default 'pendiente'
                 check (estado in ('pendiente','en_proceso','completado','cancelado')),
  prioridad      text not null default 'media'
                 check (prioridad in ('alta','media','baja')),
  responsable    text,
  fecha_inicio   date,
  fecha_objetivo date,
  fecha_cierre   date,
  notas          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Índices de filtrado frecuente
create index if not exists idx_mejoras_estado    on public.mejoras_planta(estado);
create index if not exists idx_mejoras_area      on public.mejoras_planta(area);
create index if not exists idx_mejoras_prioridad on public.mejoras_planta(prioridad);

-- Trigger updated_at
create or replace function public.set_updated_at_mejoras()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_mejoras_planta_upd on public.mejoras_planta;
create trigger trg_mejoras_planta_upd
  before update on public.mejoras_planta
  for each row execute function public.set_updated_at_mejoras();


-- ─────────────────────────────────────────────────────────────
-- 2. COLUMNAS RRHH EN TABLA personal (idempotentes)
-- ─────────────────────────────────────────────────────────────
alter table public.personal add column if not exists locker          text;
alter table public.personal add column if not exists talla_uniforme  text;
  -- valores esperados: XS · S · M · L · XL · XXL
alter table public.personal add column if not exists epp_asignado    boolean not null default false;
alter table public.personal add column if not exists epp_fecha       date;
  -- fecha de entrega del EPP
alter table public.personal add column if not exists notas_rrhh      text;


-- ─────────────────────────────────────────────────────────────
-- 3. PERMISOS / AUSENCIAS
-- ─────────────────────────────────────────────────────────────
create table if not exists public.rrhh_permisos (
  id           serial primary key,
  personal_id  uuid references public.personal(id) on delete set null,
  tipo         text not null
               check (tipo in ('permiso','ausencia','tardanza','licencia','vacacion','otro')),
  fecha_inicio date not null,
  fecha_fin    date,
  estado       text not null default 'pendiente'
               check (estado in ('pendiente','aprobado','rechazado')),
  motivo       text,
  notas        text,
  created_at   timestamptz not null default now()
);

create index if not exists idx_permisos_personal on public.rrhh_permisos(personal_id);
create index if not exists idx_permisos_fecha    on public.rrhh_permisos(fecha_inicio desc);


-- ─────────────────────────────────────────────────────────────
-- 4. INCIDENTES / RECONOCIMIENTOS
-- ─────────────────────────────────────────────────────────────
create table if not exists public.rrhh_incidentes (
  id           serial primary key,
  personal_id  uuid references public.personal(id) on delete set null,
  tipo         text not null
               check (tipo in ('accidente','amonestacion','reconocimiento','capacitacion','otro')),
  fecha        date not null default current_date,
  descripcion  text,
  seguimiento  text,
  created_at   timestamptz not null default now()
);

create index if not exists idx_incidentes_personal on public.rrhh_incidentes(personal_id);
create index if not exists idx_incidentes_fecha    on public.rrhh_incidentes(fecha desc);


-- ─────────────────────────────────────────────────────────────
-- 5. RLS — mejoras_planta
--    Lectura: cualquier usuario autenticado con perfil
--    Escritura: solo master
-- ─────────────────────────────────────────────────────────────
alter table public.mejoras_planta enable row level security;

drop policy if exists "mejoras_lectura"        on public.mejoras_planta;
drop policy if exists "mejoras_insert_master"  on public.mejoras_planta;
drop policy if exists "mejoras_update_master"  on public.mejoras_planta;
drop policy if exists "mejoras_delete_master"  on public.mejoras_planta;

create policy "mejoras_lectura" on public.mejoras_planta
  for select to authenticated
  using (public.rol_actual() is not null);

create policy "mejoras_insert_master" on public.mejoras_planta
  for insert to authenticated
  with check (public.es_master());

create policy "mejoras_update_master" on public.mejoras_planta
  for update to authenticated
  using (public.es_master()) with check (public.es_master());

create policy "mejoras_delete_master" on public.mejoras_planta
  for delete to authenticated
  using (public.es_master());

revoke all on public.mejoras_planta from anon;
grant select, insert, update, delete on public.mejoras_planta to authenticated;
grant usage, select on sequence public.mejoras_planta_id_seq to authenticated;


-- ─────────────────────────────────────────────────────────────
-- 6. RLS — rrhh_permisos (master-only, datos sensibles de RRHH)
-- ─────────────────────────────────────────────────────────────
alter table public.rrhh_permisos enable row level security;

drop policy if exists "permisos_master_todo"  on public.rrhh_permisos;

create policy "permisos_master_todo" on public.rrhh_permisos
  for all to authenticated
  using (public.es_master())
  with check (public.es_master());

revoke all on public.rrhh_permisos from anon;
grant select, insert, update, delete on public.rrhh_permisos to authenticated;
grant usage, select on sequence public.rrhh_permisos_id_seq to authenticated;


-- ─────────────────────────────────────────────────────────────
-- 7. RLS — rrhh_incidentes (master-only, datos sensibles de RRHH)
-- ─────────────────────────────────────────────────────────────
alter table public.rrhh_incidentes enable row level security;

drop policy if exists "incidentes_master_todo" on public.rrhh_incidentes;

create policy "incidentes_master_todo" on public.rrhh_incidentes
  for all to authenticated
  using (public.es_master())
  with check (public.es_master());

revoke all on public.rrhh_incidentes from anon;
grant select, insert, update, delete on public.rrhh_incidentes to authenticated;
grant usage, select on sequence public.rrhh_incidentes_id_seq to authenticated;


-- ─────────────────────────────────────────────────────────────
-- 8. Refrescar caché PostgREST
-- ─────────────────────────────────────────────────────────────
notify pgrst, 'reload schema';


-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN — revisar la salida tras correr el script
-- ════════════════════════════════════════════════════════════════

-- a) Tres tablas nuevas con RLS activo
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('mejoras_planta','rrhh_permisos','rrhh_incidentes')
order by tablename;

-- b) Columnas nuevas en personal
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name   = 'personal'
  and column_name  in ('locker','talla_uniforme','epp_asignado','epp_fecha','notas_rrhh')
order by column_name;

-- c) Conteo inicial (deben ser 0)
select 'mejoras_planta'  as tabla, count(*) from public.mejoras_planta
union all
select 'rrhh_permisos',            count(*) from public.rrhh_permisos
union all
select 'rrhh_incidentes',          count(*) from public.rrhh_incidentes;
