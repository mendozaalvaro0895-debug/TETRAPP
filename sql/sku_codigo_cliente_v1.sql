-- ════════════════════════════════════════════════════════════════
-- Código del cliente ↔ nuestro SKU (oct/2026)
-- Cada cliente identifica sus productos con SU PROPIO código en sus OC. Al escribirlo en la
-- solicitud de Tapas se busca aquí y se elige solo nuestro SKU; si es nuevo, queda vinculado
-- al guardar. Además la línea de la ficha guarda el código para verlo en Fichas de Trabajo.
-- Correr en Supabase Dashboard → SQL Editor (no borra ni cambia nada existente).
-- ════════════════════════════════════════════════════════════════

create table if not exists public.sku_codigo_cliente (
  id              bigserial primary key,
  cliente         text not null,                 -- igual que solicitudes.cliente_nombre
  codigo_cliente  text not null,                 -- como lo escribió el usuario
  codigo_norm     text not null,                 -- MAYÚSCULAS sin espacios ni guiones: así "ab-12" = "AB 12"
  sku             text not null,                 -- nuestro SKU
  descripcion     text,
  area            text not null default 'tapas' check (area in ('tapas','serigrafia','produccion')),
  actualizado_por text,
  actualizado_en  timestamptz default now(),
  unique (cliente, codigo_norm, area)
);

create index if not exists idx_sku_codigo_cliente_sku on public.sku_codigo_cliente(sku);

drop trigger if exists trg_sku_codigo_cliente_actualizado_en on public.sku_codigo_cliente;
create trigger trg_sku_codigo_cliente_actualizado_en
before insert or update on public.sku_codigo_cliente
for each row execute function public.set_actualizado_en();   -- función creada en sku_especificaciones_v1.sql

alter table public.sku_codigo_cliente enable row level security;

drop policy if exists lectura_con_perfil     on public.sku_codigo_cliente;
drop policy if exists insert_master_o_prod   on public.sku_codigo_cliente;
drop policy if exists update_master_o_prod   on public.sku_codigo_cliente;
drop policy if exists delete_master_o_prod   on public.sku_codigo_cliente;

create policy lectura_con_perfil on public.sku_codigo_cliente
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_master_o_prod on public.sku_codigo_cliente
  for insert to authenticated with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy update_master_o_prod on public.sku_codigo_cliente
  for update to authenticated using (public.es_master() or public.rol_actual() = 'operativo_prod')
  with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy delete_master_o_prod on public.sku_codigo_cliente
  for delete to authenticated using (public.es_master() or public.rol_actual() = 'operativo_prod');

revoke all on public.sku_codigo_cliente from anon;
grant select, insert, update, delete on public.sku_codigo_cliente to authenticated;
grant usage, select on sequence public.sku_codigo_cliente_id_seq to authenticated;

-- El código también se guarda en la línea de cada ficha (para verlo en Fichas de Trabajo)
alter table public.solicitud_lineas add column if not exists codigo_cliente text;

-- Verificar
select count(*) as vinculos from public.sku_codigo_cliente;
