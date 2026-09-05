-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Perfil SUPERVISOR Tapas v1.0
-- Correr COMPLETO en Supabase Dashboard → SQL Editor
--
-- Contexto: hoy quien registra producción en Tapas es la cuenta
-- compartida de planta (tapas@tetrapp.app, rol 'operativo', usada por
-- los operarios en registro-tapas.html). Este script agrega un rol
-- NUEVO para que la SUPERVISORA (Yenifer) entre con su propio correo
-- a esa misma app — sin tocar registro-tapas.html: la pantalla ya
-- permite elegir cualquier tarjeta de operario y registrar su tarea,
-- que es exactamente lo que necesita una supervisora que carga la
-- producción del día por su equipo.
--
-- ORDEN DE DESPLIEGUE (importante):
--   1. Crear el usuario en Dashboard → Authentication → Users:
--        supervisor.tapas@tetrapp.app   (Auto Confirm ✓)
--      ⚠️ Si Álvaro prefiere el correo real de Yenifer, cambia el
--      correo aquí y en el INSERT de abajo antes de correr el script.
--   2. Correr este script completo.
--   3. Yenifer entra en login.html con ese correo → aterriza directo
--      en registro-tapas.html (jaula igual que operativo).
-- ════════════════════════════════════════════════════════════════

-- ── A. Ampliar roles permitidos ──────────────────────────────────
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles
  add constraint perfiles_rol_check
  check (rol in ('master','visor','operativo','operativo_serig','operativo_prod','supervisor_tapas'));

-- ── B. Perfil de la supervisora ───────────────────────────────────
-- (requiere haber creado supervisor.tapas@tetrapp.app en Authentication → Users)
insert into public.perfiles (user_id, rol, nombre)
select id, 'supervisor_tapas', 'Yenifer'
from auth.users where email = 'supervisor.tapas@tetrapp.app'
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
-- 1) Debe aparecer supervisor.tapas@tetrapp.app con rol supervisor_tapas:
select u.email, p.rol, p.nombre
from public.perfiles p join auth.users u on u.id = p.user_id
order by p.rol;

-- 2) comandas y comanda_tareas deben mostrar insert_supervisor_tapas junto a las demás:
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public' and tablename in ('comandas','comanda_tareas')
order by tablename, policyname;
