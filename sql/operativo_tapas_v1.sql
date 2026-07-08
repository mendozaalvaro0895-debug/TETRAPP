-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Perfil OPERATIVO Tapas v1.0
-- Correr COMPLETO en Supabase Dashboard → SQL Editor
--
-- ORDEN DE DESPLIEGUE (importante):
--   1. Crear el usuario en Dashboard → Authentication → Users:
--        tapas@tetrapp.app   (Auto Confirm ✓)
--   2. Correr este script completo.
--   3. Push del código a main (Vercel despliega registro-tapas.html).
--
-- Qué hace:
--   A. Amplía los roles de perfiles: master / visor / operativo
--   B. Asigna perfil 'operativo' a tapas@tetrapp.app
--   C. Políticas RLS: operativo puede INSERTAR comandas y
--      comanda_tareas (solo insertar — sin update ni delete;
--      la lectura ya la cubre lectura_con_perfil)
--   D. Correlativo automático CMD-### vía secuencia + trigger
--      (se asigna en la BD cuando el insert llega sin correlativo,
--       elimina colisiones entre operarios simultáneos)
-- ════════════════════════════════════════════════════════════════

-- ── A. Ampliar roles permitidos ──────────────────────────────────
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles
  add constraint perfiles_rol_check check (rol in ('master','visor','operativo'));

-- ── B. Perfil del usuario compartido de planta ───────────────────
-- (requiere haber creado tapas@tetrapp.app en Authentication → Users)
insert into public.perfiles (user_id, rol, nombre)
select id, 'operativo', 'Operativos Tapas'
from auth.users where email = 'tapas@tetrapp.app'
on conflict (user_id) do update set rol = 'operativo', nombre = 'Operativos Tapas';

-- ── C. Políticas de escritura para operativo ─────────────────────
-- Las políticas de un mismo comando se combinan con OR, así que
-- insert_master sigue funcionando igual para el rol master.
drop policy if exists insert_operativo on public.comandas;
create policy insert_operativo on public.comandas
  for insert to authenticated
  with check (public.rol_actual() = 'operativo');

drop policy if exists insert_operativo on public.comanda_tareas;
create policy insert_operativo on public.comanda_tareas
  for insert to authenticated
  with check (public.rol_actual() = 'operativo');

-- ── D. Correlativo automático CMD-### ────────────────────────────
create sequence if not exists public.comandas_correlativo_seq;

-- Sincronizar la secuencia con el correlativo más alto ya existente
select setval(
  'public.comandas_correlativo_seq',
  coalesce(
    (select max((regexp_match(correlativo, '(\d+)$'))[1]::int)
     from public.comandas
     where correlativo ~ '\d+$'),
    0
  ) + 1,
  false
);

-- Trigger: asigna correlativo solo si el insert llega sin él
-- (security definer para que operativo pueda usar la secuencia)
create or replace function public.asignar_correlativo_comanda()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if new.correlativo is null or btrim(new.correlativo) = '' then
    new.correlativo := 'CMD-' || lpad(nextval('public.comandas_correlativo_seq')::text, 3, '0');
  end if;
  return new;
end $$;

revoke execute on function public.asignar_correlativo_comanda() from public, anon;

drop trigger if exists trg_correlativo_comanda on public.comandas;
create trigger trg_correlativo_comanda
  before insert on public.comandas
  for each row execute function public.asignar_correlativo_comanda();

-- ── Verificación final ───────────────────────────────────────────
-- 1) Debe aparecer tapas@tetrapp.app con rol operativo:
select u.email, p.rol, p.nombre
from public.perfiles p join auth.users u on u.id = p.user_id
order by p.rol;

-- 2) comandas y comanda_tareas deben mostrar insert_master + insert_operativo:
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public' and tablename in ('comandas','comanda_tareas')
order by tablename, policyname;
