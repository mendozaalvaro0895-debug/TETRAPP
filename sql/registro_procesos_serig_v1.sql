-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Registro de procesos Serigrafía v1.0
-- Tablas para los flujos nuevos de registro-serigrafia.html:
--   · registro_flameado_serig  (una fila por bolsa flameada)
--   · registro_empaque_serig   (una fila por registro de empaque)
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor.
-- Es idempotente: se puede correr varias veces sin romper nada.
-- Mismo patrón RLS que registro_tiros_serig:
--   anon = nada · lectura con perfil · INSERT operativo_serig y
--   master · UPDATE/DELETE solo master.
-- ════════════════════════════════════════════════════════════════

-- ── 1. FLAMEADO — espejo de la hoja física ────────────────────────
-- (Hora, Flameador, Envase, Cantidad, Para línea 1-4)
create table if not exists public.registro_flameado_serig (
  id                uuid primary key default gen_random_uuid(),
  fecha             date not null default current_date,
  hora              time,
  flameador_codigo  text not null,
  flameador_nombre  text,
  sku               text,
  descripcion       text,
  cantidad          integer not null check (cantidad > 0),
  para_linea        integer not null check (para_linea between 1 and 4),
  area              text not null default 'serig',
  created_at        timestamptz not null default now()
);

-- ── 2. EMPAQUE — operador propio o apoyo de otra área ─────────────
-- operador_codigo es NULL cuando es apoyo externo (no vive en la
-- tabla personal); area_origen justifica el déficit en su área
-- cuando se conecten las áreas.
create table if not exists public.registro_empaque_serig (
  id               uuid primary key default gen_random_uuid(),
  fecha            date not null default current_date,
  hora             time,
  operador_codigo  text,
  operador_nombre  text not null,
  area_origen      text not null default 'serig',
  sku              text,
  descripcion      text,
  cantidad         integer not null check (cantidad > 0),
  area             text not null default 'serig',
  created_at       timestamptz not null default now()
);

-- ── 3. RLS + políticas + grants (mismo patrón, ambas tablas) ──────
do $$
declare t text;
begin
  foreach t in array array['registro_flameado_serig','registro_empaque_serig']
  loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists lectura_con_perfil on public.%I', t);
    execute format(
      'create policy lectura_con_perfil on public.%I
       for select to authenticated using (public.rol_actual() is not null)', t);

    execute format('drop policy if exists insert_operativo_serig on public.%I', t);
    execute format(
      'create policy insert_operativo_serig on public.%I
       for insert to authenticated
       with check (public.rol_actual() = ''operativo_serig'')', t);

    execute format('drop policy if exists insert_master on public.%I', t);
    execute format(
      'create policy insert_master on public.%I
       for insert to authenticated with check (public.es_master())', t);

    execute format('drop policy if exists update_master on public.%I', t);
    execute format(
      'create policy update_master on public.%I
       for update to authenticated using (public.es_master()) with check (public.es_master())', t);

    execute format('drop policy if exists delete_master on public.%I', t);
    execute format(
      'create policy delete_master on public.%I
       for delete to authenticated using (public.es_master())', t);

    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

-- ── 4. Refrescar el caché de esquema de PostgREST ─────────────────
-- (evita el error PGRST205 "table not found in schema cache" justo
-- después de crear las tablas)
notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN — revisar la salida:
-- ════════════════════════════════════════════════════════════════

-- a) Ambas tablas deben aparecer con rowsecurity = true
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('registro_flameado_serig','registro_empaque_serig');

-- b) 5 políticas por tabla (10 filas en total)
select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in ('registro_flameado_serig','registro_empaque_serig')
order by tablename, cmd, policyname;
