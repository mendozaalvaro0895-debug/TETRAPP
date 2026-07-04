-- ═══════════════════════════════════════════════════════════════
-- TETRAPP — Blindaje de seguridad v1.0
-- Correr COMPLETO en Supabase Dashboard → SQL Editor
--
-- ORDEN DE DESPLIEGUE (importante):
--   1. Crear los 2 usuarios en Dashboard → Authentication → Users:
--        master@tetrapp.app  (Auto Confirm ✓)
--        visor@tetrapp.app   (Auto Confirm ✓)
--   2. Correr este script completo.
--   3. Push del código a main (Vercel despliega el login).
--   4. Dashboard → Authentication → Sign In / Up →
--      DESACTIVAR "Allow new users to sign up".
--
-- Qué hace:
--   A. Tabla perfiles (rol master/visor por usuario)
--   B. Helpers rol_actual() / es_master()
--   C. Elimina TODAS las políticas abiertas (tetra_anon_all etc.)
--   D. Nuevas políticas: anónimo=NADA · visor=solo lectura · master=todo
--   E. Revoca todo privilegio del rol anon (tablas, vistas, funciones)
--   F. Asegura las RPCs de inventario (security invoker + sin anon)
--   G. Asigna perfiles a los 2 usuarios creados
-- ═══════════════════════════════════════════════════════════════

-- ── A. Tabla de perfiles ─────────────────────────────────────────
create table if not exists public.perfiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  rol        text not null check (rol in ('master','visor')),
  nombre     text not null default '',
  created_at timestamptz not null default now()
);

alter table public.perfiles enable row level security;

-- ── B. Helpers de rol (security definer: leen perfiles sin RLS) ──
create or replace function public.rol_actual()
returns text
language sql stable security definer
set search_path = public
as $$
  select rol from public.perfiles where user_id = auth.uid()
$$;

create or replace function public.es_master()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce((select rol from public.perfiles where user_id = auth.uid()) = 'master', false)
$$;

revoke execute on function public.rol_actual() from public, anon;
revoke execute on function public.es_master()  from public, anon;
grant  execute on function public.rol_actual() to authenticated;
grant  execute on function public.es_master()  to authenticated;

-- ── C. Eliminar TODAS las políticas actuales del schema public ──
-- (hoy solo existen las abiertas tipo tetra_anon_all; se recrean abajo)
do $$
declare pol record;
begin
  for pol in
    select policyname, tablename from pg_policies where schemaname = 'public'
  loop
    execute format('drop policy %I on public.%I', pol.policyname, pol.tablename);
  end loop;
end $$;

-- ── D. Nuevas políticas para TODAS las tablas de public ─────────
-- Lectura: cualquier usuario autenticado CON perfil.
-- Escritura (insert/update/delete): solo master.
do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('alter table public.%I enable row level security', t.tablename);

    if t.tablename = 'perfiles' then
      -- cada quien lee solo su propio perfil; nadie escribe vía API
      execute 'create policy perfil_propio on public.perfiles
               for select to authenticated using (auth.uid() = user_id)';
    else
      execute format(
        'create policy lectura_con_perfil on public.%I
         for select to authenticated using (public.rol_actual() is not null)',
        t.tablename);
      execute format(
        'create policy insert_master on public.%I
         for insert to authenticated with check (public.es_master())',
        t.tablename);
      execute format(
        'create policy update_master on public.%I
         for update to authenticated using (public.es_master()) with check (public.es_master())',
        t.tablename);
      execute format(
        'create policy delete_master on public.%I
         for delete to authenticated using (public.es_master())',
        t.tablename);
    end if;
  end loop;
end $$;

-- ── E. Cortar TODO acceso del rol anónimo ────────────────────────
revoke all on all tables    in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;
alter default privileges in schema public revoke all on tables    from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on functions from anon;

-- ── F. Asegurar RPCs de inventario ───────────────────────────────
-- security invoker → la RPC respeta el RLS del usuario que la llama
-- (un visor NO puede ajustar existencias ni por consola del navegador)
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('descontar_inventario','aumentar_inventario')
  loop
    execute format('alter function %s security invoker', f.sig);
    execute format('revoke execute on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;

-- ── G. Asignar perfiles a los 2 usuarios ─────────────────────────
-- (requiere haberlos creado antes en Authentication → Users)
insert into public.perfiles (user_id, rol, nombre)
select id, 'master', 'Álvaro Mendoza'
from auth.users where email = 'master@tetrapp.app'
on conflict (user_id) do update set rol = 'master', nombre = 'Álvaro Mendoza';

insert into public.perfiles (user_id, rol, nombre)
select id, 'visor', 'Usuario Visor'
from auth.users where email = 'visor@tetrapp.app'
on conflict (user_id) do update set rol = 'visor', nombre = 'Usuario Visor';

-- ── Verificación final ───────────────────────────────────────────
select u.email, p.rol, p.nombre
from public.perfiles p join auth.users u on u.id = p.user_id;

-- Debe mostrar SOLO políticas para {authenticated} — ninguna para anon:
select tablename, policyname, roles, cmd
from pg_policies where schemaname = 'public'
order by tablename, policyname;
