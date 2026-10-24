-- ════════════════════════════════════════════════════════════════
-- sku_recetas_cliente — VARIANTE de la receta de un SKU según el CLIENTE (oct/2026)
-- Caso real: el SKU 13002 lo piden SINERGIA e INCOGUA y solo cambia el LINER.
-- `sku_recetas` tiene UNIQUE(sku_fact) (una receta general por SKU); cada cliente
-- cuya versión difiere guarda la suya aquí. El formulario de Tapas autorrellena con:
-- ficha anterior del cliente > variante del cliente > receta general.
-- Correr en Supabase Dashboard → SQL Editor (no borra ni cambia nada existente).
-- ════════════════════════════════════════════════════════════════

create table if not exists public.sku_recetas_cliente (
  id              bigserial primary key,
  sku             text not null,
  cliente         text not null,
  area            text not null default 'tapas' check (area in ('tapas','serigrafia','produccion')),
  partes          jsonb not null default '[]'::jsonb,   -- [{tipo:'base'|'accesorio'|'proceso', codigo, nota}] igual que sku_receta_partes
  actualizado_por text,
  actualizado_en  timestamptz default now(),
  unique (sku, cliente, area)
);

create index if not exists idx_sku_recetas_cliente_sku on public.sku_recetas_cliente(sku);

drop trigger if exists trg_sku_recetas_cliente_actualizado_en on public.sku_recetas_cliente;
create trigger trg_sku_recetas_cliente_actualizado_en
before insert or update on public.sku_recetas_cliente
for each row execute function public.set_actualizado_en();   -- función creada en sku_especificaciones_v1.sql

-- RLS — mismo criterio que sku_recetas / sku_receta_partes (master u operativo_prod escriben)
alter table public.sku_recetas_cliente enable row level security;

drop policy if exists lectura_con_perfil     on public.sku_recetas_cliente;
drop policy if exists insert_master_o_prod   on public.sku_recetas_cliente;
drop policy if exists update_master_o_prod   on public.sku_recetas_cliente;
drop policy if exists delete_master_o_prod   on public.sku_recetas_cliente;

create policy lectura_con_perfil on public.sku_recetas_cliente
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_master_o_prod on public.sku_recetas_cliente
  for insert to authenticated with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy update_master_o_prod on public.sku_recetas_cliente
  for update to authenticated using (public.es_master() or public.rol_actual() = 'operativo_prod')
  with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy delete_master_o_prod on public.sku_recetas_cliente
  for delete to authenticated using (public.es_master() or public.rol_actual() = 'operativo_prod');

revoke all on public.sku_recetas_cliente from anon;
grant select, insert, update, delete on public.sku_recetas_cliente to authenticated;
grant usage, select on sequence public.sku_recetas_cliente_id_seq to authenticated;

-- Verificar
select count(*) as filas from public.sku_recetas_cliente;
