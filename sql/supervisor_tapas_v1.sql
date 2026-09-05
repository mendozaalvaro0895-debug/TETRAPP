-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Perfil SUPERVISOR Tapas v1.1
-- Correr COMPLETO en Supabase Dashboard → SQL Editor
--
-- Contexto: NO se crea una cuenta nueva. Se REPROPÓSITA la cuenta que
-- ya existe (tapas@tetrapp.app, hoy rol 'operativo', usada por los
-- operarios en el dispositivo compartido de planta). A partir de este
-- script esa misma cuenta pasa a ser de la SUPERVISORA (Yenifer) —
-- los operarios dejan de tener acceso a ese perfil (rol cambia de
-- 'operativo' a 'supervisor_tapas'). Cuando más adelante se restaure
-- la participación de los operarios, se creará OTRO perfil aparte
-- (nueva cuenta, no esta).
--
-- Sin cambios en registro-tapas.html: la pantalla ya permite elegir
-- cualquier tarjeta de operario y registrar su tarea, que es
-- exactamente lo que necesita la supervisora para cargar la
-- producción del día por su equipo.
--
-- ORDEN DE DESPLIEGUE (importante):
--   1. Dashboard → Authentication → Users → tapas@tetrapp.app →
--      restablecer la contraseña y dársela SOLO a Yenifer (los
--      operarios ya no deben conocerla).
--   2. Correr este script completo (re-ejecutar la parte B es seguro
--      aunque ya hayas corrido la v1.0 antes — el UPSERT solo cambia
--      el rol/nombre del mismo user_id).
--   3. Yenifer entra en login.html con tapas@tetrapp.app y la
--      contraseña nueva → aterriza directo en registro-tapas.html.
-- ════════════════════════════════════════════════════════════════

-- ── A. Ampliar roles permitidos ──────────────────────────────────
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles
  add constraint perfiles_rol_check
  check (rol in ('master','visor','operativo','operativo_serig','operativo_prod','supervisor_tapas'));

-- ── B. Repropósito del perfil: tapas@tetrapp.app pasa de 'operativo'
--      a 'supervisor_tapas' (mismo user_id, ya existe desde
--      operativo_tapas_v1.sql — no hace falta crear cuenta nueva) ──
insert into public.perfiles (user_id, rol, nombre)
select id, 'supervisor_tapas', 'Yenifer'
from auth.users where email = 'tapas@tetrapp.app'
on conflict (user_id) do update set rol = 'supervisor_tapas', nombre = 'Yenifer';

-- ── C. Políticas de escritura para supervisor_tapas ──────────────
-- Mismo alcance que operativo por ahora (solo insertar, sin update ni
-- delete) — si luego Yenifer necesita corregir registros, se agrega
-- update/delete en un script aparte.
drop policy if exists insert_supervisor_tapas on public.comandas;
create policy insert_supervisor_tapas on public.comandas
  for insert to authenticated
  with check (public.rol_actual() = 'supervisor_tapas');

drop policy if exists insert_supervisor_tapas on public.comanda_tareas;
create policy insert_supervisor_tapas on public.comanda_tareas
  for insert to authenticated
  with check (public.rol_actual() = 'supervisor_tapas');

-- ── Verificación final ───────────────────────────────────────────
-- 1) Debe aparecer tapas@tetrapp.app con rol supervisor_tapas (ya NO 'operativo'):
select u.email, p.rol, p.nombre
from public.perfiles p join auth.users u on u.id = p.user_id
order by p.rol;

-- 2) comandas y comanda_tareas deben mostrar insert_supervisor_tapas junto a las demás:
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public' and tablename in ('comandas','comanda_tareas')
order by tablename, policyname;
