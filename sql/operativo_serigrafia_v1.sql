-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Perfil OPERATIVO Serigrafía v1.0
-- Correr COMPLETO en Supabase Dashboard → SQL Editor
--
-- ORDEN DE DESPLIEGUE (importante):
--   1. Crear el usuario en Dashboard → Authentication → Users:
--        serigrafia@tetrapp.app   (Auto Confirm ✓)
--   2. Correr este script completo.
--   3. Push del código a main (Vercel despliega registro-serigrafia.html).
--
-- Qué hace:
--   A. Crea la tabla registro_tiros_serig (lecturas de contador por
--      línea/diseño/momento de turno)
--   B. Amplía los roles de perfiles con 'operativo_serig'
--   C. Asigna ese perfil a serigrafia@tetrapp.app
--   D. Políticas RLS: mismo patrón que el resto de tablas del
--      blindaje v1.0 (lectura con perfil, escritura solo master),
--      más un INSERT-only para operativo_serig
-- ════════════════════════════════════════════════════════════════

-- ── A. Tabla de lecturas ──────────────────────────────────────────
create table if not exists public.registro_tiros_serig (
  id              uuid primary key default gen_random_uuid(),
  fecha           date not null default current_date,
  linea_id        integer not null,
  sku             text,
  diseno          text,
  operador_codigo text not null,
  operador_nombre text,
  momento         text not null check (momento in ('inicio','mediodia','fin')),
  contador        integer not null,
  area            text not null default 'serig',
  created_at      timestamptz not null default now()
);

alter table public.registro_tiros_serig enable row level security;

-- ── B. Ampliar roles permitidos ───────────────────────────────────
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles
  add constraint perfiles_rol_check check (rol in ('master','visor','operativo','operativo_serig'));

-- ── C. Perfil del usuario compartido de planta ────────────────────
-- (requiere haber creado serigrafia@tetrapp.app en Authentication → Users)
insert into public.perfiles (user_id, rol, nombre)
select id, 'operativo_serig', 'Operativos Serigrafía'
from auth.users where email = 'serigrafia@tetrapp.app'
on conflict (user_id) do update set rol = 'operativo_serig', nombre = 'Operativos Serigrafía';

-- ── D. Políticas ───────────────────────────────────────────────────
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

revoke all on public.registro_tiros_serig from anon;

-- ── Verificación final ────────────────────────────────────────────
select u.email, p.rol, p.nombre
from public.perfiles p join auth.users u on u.id = p.user_id
order by p.rol;

select tablename, policyname, roles, cmd
from pg_policies where schemaname = 'public' and tablename = 'registro_tiros_serig';
