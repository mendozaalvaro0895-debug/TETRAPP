-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Módulo Ventas y Financiero v1.0
-- Prepara la tabla public.ventas para ventas.html:
--   · La crea si no existe (una fila = una línea de factura)
--   · Si ya existe (la usaba el importador diario de inventario.html),
--     agrega las columnas nuevas y normaliza fecha a tipo DATE
--   · RLS patrón estándar: anon = nada · lectura con perfil ·
--     INSERT/UPDATE/DELETE solo master
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor.
-- Es idempotente: se puede correr varias veces sin romper nada.
-- ════════════════════════════════════════════════════════════════

-- ── 1. Crear tabla si no existe ───────────────────────────────────
create table if not exists public.ventas (
  id                  bigint generated always as identity primary key,
  serie               text not null,
  docu                bigint,
  fecha               date not null,
  codigo_cliente      text,
  nit                 text,
  cliente             text,
  familia             text,
  descripcion_familia text,
  sku                 text not null,
  descripcion         text,
  precio_unidad       numeric(12,4) default 0,
  total_quetzales     numeric(14,2) default 0,
  total_unidades      numeric(14,2) default 0,
  costo               numeric(14,2) default 0,
  utilidad            numeric(14,2) default 0,
  created_at          timestamptz not null default now()
);

-- ── 2. Si la tabla ya existía: columnas que el importador viejo
--       de inventario.html no manejaba ───────────────────────────
alter table public.ventas add column if not exists codigo_cliente      text;
alter table public.ventas add column if not exists familia             text;
alter table public.ventas add column if not exists descripcion_familia text;
alter table public.ventas add column if not exists created_at          timestamptz default now();

-- ── 3. Normalizar fecha a DATE si quedó como texto ────────────────
-- (el importador viejo guardaba el string tal cual venía del Excel,
--  formato DD/MM/YYYY; las fechas ISO YYYY-MM-DD también se aceptan)
do $$
declare tipo text;
begin
  select data_type into tipo
  from information_schema.columns
  where table_schema = 'public' and table_name = 'ventas' and column_name = 'fecha';

  if tipo in ('text', 'character varying') then
    execute $sql$
      alter table public.ventas
      alter column fecha type date using (
        case
          when fecha ~ '^\d{4}-\d{2}-\d{2}' then fecha::date
          when fecha ~ '^\d{1,2}/\d{1,2}/\d{4}' then to_date(fecha, 'DD/MM/YYYY')
          else null
        end
      )
    $sql$;
    raise notice 'Columna fecha convertida de % a date', tipo;
  end if;
end $$;

-- ── 4. Índices para las consultas del módulo ──────────────────────
create index if not exists idx_ventas_fecha   on public.ventas (fecha);
create index if not exists idx_ventas_sku     on public.ventas (sku);
create index if not exists idx_ventas_cliente on public.ventas (cliente);

-- ── 5. RLS + políticas + grants ───────────────────────────────────
alter table public.ventas enable row level security;

drop policy if exists lectura_con_perfil on public.ventas;
create policy lectura_con_perfil on public.ventas
  for select to authenticated using (public.rol_actual() is not null);

drop policy if exists insert_master on public.ventas;
create policy insert_master on public.ventas
  for insert to authenticated with check (public.es_master());

drop policy if exists update_master on public.ventas;
create policy update_master on public.ventas
  for update to authenticated using (public.es_master()) with check (public.es_master());

drop policy if exists delete_master on public.ventas;
create policy delete_master on public.ventas
  for delete to authenticated using (public.es_master());

revoke all on public.ventas from anon;
grant select, insert, update, delete on public.ventas to authenticated;

-- ── 6. Refrescar el caché de esquema de PostgREST ─────────────────
notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN — revisar la salida:
-- ════════════════════════════════════════════════════════════════

-- a) La tabla debe aparecer con rowsecurity = true
select tablename, rowsecurity
from pg_tables
where schemaname = 'public' and tablename = 'ventas';

-- b) 4 políticas
select policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename = 'ventas'
order by cmd, policyname;

-- c) fecha debe ser tipo date y las columnas nuevas deben existir
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'ventas'
order by ordinal_position;

-- d) cuántas filas tiene hoy (0 si nunca se ha importado)
select count(*) as filas, min(fecha) as desde, max(fecha) as hasta
from public.ventas;
