-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Perfil OPERATIVO Producción (Sopladoras) v1.0
-- Correr COMPLETO en Supabase Dashboard → SQL Editor.
-- Idempotente: se puede correr varias veces sin romper nada.
--
-- ORDEN DE DESPLIEGUE (importante):
--   1. PRIMERO correr sql/produccion_v1.sql (crea la tabla produccion_diaria
--      y sus columnas en inventario). Este script asume que ya existe.
--   2. Crear el usuario en Dashboard → Authentication → Users:
--        produccion@tetrapp.app   (Auto Confirm ✓)   ← contraseña la pones tú
--   3. Correr este script completo.
--   4. Push del código a main (ya despliega auth.js con la jaula del rol).
--
-- Qué hace:
--   A. Amplía los roles de perfiles con 'operativo_prod'
--   B. Asigna ese perfil a produccion@tetrapp.app
--   C. Políticas RLS en produccion_diaria: lectura con perfil, escritura
--      (insert/update/delete) para operativo_prod y para master
--
-- Alcance del rol (enjaulado en produccion.html por auth.js):
--   PUEDE  → registrar/editar/borrar turnos de producción (produccion_diaria)
--            y ver los reportes semanal/mensual (lectura con perfil)
--   NO PUEDE → editar recetas ni fichas técnicas de SKU (siguen solo-master,
--            gateadas en la UI y por RLS), ni entrar a otros módulos.
--   Nota: el "recordar máquina" (inventario.maquina_default) que produccion.html
--   intenta al guardar es opcional y está en try/catch — para operativo_prod
--   simplemente no persiste (no bloquea el registro). Si más adelante se quiere
--   habilitar, se hace con una RPC security-definer, no abriendo inventario.
-- ════════════════════════════════════════════════════════════════

-- ── A. Ampliar roles permitidos ───────────────────────────────────
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles
  add constraint perfiles_rol_check
  check (rol in ('master','visor','operativo','operativo_serig','operativo_prod'));

-- ── B. Perfil del usuario de planta de Producción ─────────────────
-- (requiere haber creado produccion@tetrapp.app en Authentication → Users)
insert into public.perfiles (user_id, rol, nombre)
select id, 'operativo_prod', 'Operativos Producción'
from auth.users where email = 'produccion@tetrapp.app'
on conflict (user_id) do update
  set rol = 'operativo_prod', nombre = 'Operativos Producción';

-- ── C. Políticas RLS en produccion_diaria ─────────────────────────
-- Guarda: solo si la tabla existe (debe haberla creado produccion_v1.sql).
do $$
begin
  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'produccion_diaria'
  ) then
    raise exception 'La tabla produccion_diaria no existe. Corre PRIMERO sql/produccion_v1.sql.';
  end if;

  execute 'alter table public.produccion_diaria enable row level security';

  -- Lectura: cualquier autenticado con perfil (para ver reportes)
  execute 'drop policy if exists lectura_con_perfil on public.produccion_diaria';
  execute 'create policy lectura_con_perfil on public.produccion_diaria
           for select to authenticated using (public.rol_actual() is not null)';

  -- Escritura del operativo de producción
  execute 'drop policy if exists insert_operativo_prod on public.produccion_diaria';
  execute 'create policy insert_operativo_prod on public.produccion_diaria
           for insert to authenticated with check (public.rol_actual() = ''operativo_prod'')';

  execute 'drop policy if exists update_operativo_prod on public.produccion_diaria';
  execute 'create policy update_operativo_prod on public.produccion_diaria
           for update to authenticated using (public.rol_actual() = ''operativo_prod'')
           with check (public.rol_actual() = ''operativo_prod'')';

  execute 'drop policy if exists delete_operativo_prod on public.produccion_diaria';
  execute 'create policy delete_operativo_prod on public.produccion_diaria
           for delete to authenticated using (public.rol_actual() = ''operativo_prod'')';

  -- Escritura del master (se re-crean por si seguridad_v1 las barrió)
  execute 'drop policy if exists insert_master on public.produccion_diaria';
  execute 'create policy insert_master on public.produccion_diaria
           for insert to authenticated with check (public.es_master())';

  execute 'drop policy if exists update_master on public.produccion_diaria';
  execute 'create policy update_master on public.produccion_diaria
           for update to authenticated using (public.es_master()) with check (public.es_master())';

  execute 'drop policy if exists delete_master on public.produccion_diaria';
  execute 'create policy delete_master on public.produccion_diaria
           for delete to authenticated using (public.es_master())';

  execute 'revoke all on public.produccion_diaria from anon';
  execute 'grant select, insert, update, delete on public.produccion_diaria to authenticated';
end $$;

-- Refrescar el caché de esquema de PostgREST
notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN — revisar la salida:
-- ════════════════════════════════════════════════════════════════

-- a) El usuario debe salir con rol = operativo_prod
select u.email, p.rol, p.nombre
from auth.users u left join public.perfiles p on p.user_id = u.id
where u.email = 'produccion@tetrapp.app';

-- b) Políticas en produccion_diaria (deben incluir las 3 de operativo_prod)
select policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename = 'produccion_diaria'
order by cmd, policyname;
