-- ════════════════════════════════════════════════════════════
-- Fix Serigrafía v2 (consolidado) — repara TODO lo que bloquea
-- que los registros de registro-serigrafia.html lleguen a la
-- tabla y se vean en serigrafia.html → pestaña Productividad.
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor.
-- Es idempotente: se puede correr varias veces sin romper nada.
--
-- Causas que repara:
--   1. Política insert_operativo_serig borrada por seguridad_v1.sql
--      (su sección C elimina TODAS las políticas y recrea solo
--      insert_master → serigrafia@tetrapp.app no podía insertar)
--   2. Columna hora inexistente si no se corrió
--      registro_tiros_serig_hora.sql (todo INSERT fallaría)
--   3. CHECK de momento sin 'velada' (el formulario ya tiene el
--      botón 🌙 Velada; la tabla lo rechazaba)
--   4. Registros viejos guardados con fecha UTC (un día adelante
--      por el bug de toISOString, ya corregido en el código)
-- ════════════════════════════════════════════════════════════

-- ── 0. Crear la tabla si no existe (con esquema completo) ─────
create table if not exists public.registro_tiros_serig (
  id              uuid primary key default gen_random_uuid(),
  fecha           date not null default current_date,
  linea_id        integer not null,
  sku             text,
  diseno          text,
  operador_codigo text not null,
  operador_nombre text,
  momento         text not null,
  hora            time,
  contador        integer not null,
  area            text not null default 'serig',
  created_at      timestamptz not null default now()
);

-- ── 1. Columna hora (por si la tabla ya existía sin ella) ─────
alter table public.registro_tiros_serig
  add column if not exists hora time;

-- ── 2. CHECK de momento: aceptar también 'velada' ─────────────
alter table public.registro_tiros_serig
  drop constraint if exists registro_tiros_serig_momento_check;
alter table public.registro_tiros_serig
  add constraint registro_tiros_serig_momento_check
  check (momento in ('inicio','mediodia','fin','velada'));

-- ── 3. CHECK de perfiles: aceptar rol operativo_serig ─────────
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles
  add constraint perfiles_rol_check
  check (rol in ('master','visor','operativo','operativo_serig'));

-- ── 4. Asegurar el perfil de serigrafia@tetrapp.app ───────────
insert into public.perfiles (user_id, rol, nombre)
select id, 'operativo_serig', 'Operativos Serigrafía'
from auth.users where email = 'serigrafia@tetrapp.app'
on conflict (user_id) do update
  set rol = 'operativo_serig', nombre = 'Operativos Serigrafía';

-- ── 5. RLS + políticas completas de la tabla ──────────────────
alter table public.registro_tiros_serig enable row level security;

drop policy if exists lectura_con_perfil on public.registro_tiros_serig;
create policy lectura_con_perfil on public.registro_tiros_serig
  for select to authenticated using (public.rol_actual() is not null);

drop policy if exists insert_operativo_serig on public.registro_tiros_serig;
create policy insert_operativo_serig on public.registro_tiros_serig
  for insert to authenticated
  with check (public.rol_actual() = 'operativo_serig');

drop policy if exists insert_master on public.registro_tiros_serig;
create policy insert_master on public.registro_tiros_serig
  for insert to authenticated with check (public.es_master());

drop policy if exists update_master on public.registro_tiros_serig;
create policy update_master on public.registro_tiros_serig
  for update to authenticated using (public.es_master()) with check (public.es_master());

drop policy if exists delete_master on public.registro_tiros_serig;
create policy delete_master on public.registro_tiros_serig
  for delete to authenticated using (public.es_master());

-- ── 6. GRANT base (sin esto RLS ni siquiera se evalúa) ────────
revoke all on public.registro_tiros_serig from anon;
grant select, insert, update, delete on public.registro_tiros_serig to authenticated;

-- ── 7. Reparar registros guardados con fecha UTC adelantada ───
-- Si el registro se creó ANTES de las 06:00 UTC (medianoche GT) y
-- su fecha quedó un día ADELANTE de la fecha local del created_at,
-- fue víctima del bug de toISOString → retroceder un día.
update public.registro_tiros_serig
set fecha = fecha - 1
where fecha = ((created_at at time zone 'America/Guatemala')::date + 1);

-- ════════════════════════════════════════════════════════════
-- DIAGNÓSTICO — revisar la salida de estas consultas:
-- ════════════════════════════════════════════════════════════

-- a) ¿El perfil quedó bien? (debe salir operativo_serig)
select u.email, p.rol, p.nombre
from auth.users u left join public.perfiles p on p.user_id = u.id
where u.email = 'serigrafia@tetrapp.app';

-- b) ¿Qué hay guardado en la tabla? (si sale vacío, los ingresos
--    del formulario NUNCA llegaron — eran rechazados por RLS/hora)
select fecha, linea_id, operador_nombre, momento, hora, contador, area, created_at
from public.registro_tiros_serig
order by created_at desc
limit 25;

-- c) Políticas vigentes (deben ser 5: lectura, 2 insert, update, delete)
select policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename = 'registro_tiros_serig'
order by cmd, policyname;

-- d) Columnas de la tabla (debe incluir hora · time)
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'registro_tiros_serig'
order by ordinal_position;
