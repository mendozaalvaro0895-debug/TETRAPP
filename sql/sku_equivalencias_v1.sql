-- sku_equivalencias_v1.sql
-- Tabla de variantes de SKU: un código de producción que se factura bajo otro código.
-- Correr en Supabase Dashboard → SQL Editor.

create table if not exists public.sku_equivalencias (
  id           serial primary key,
  sku_prod     text not null,
  sku_fact     text not null,
  nota         text,
  creado_en    timestamptz default now(),
  unique (sku_prod, sku_fact)
);

alter table public.sku_equivalencias enable row level security;

drop policy if exists "lectura_con_perfil"  on public.sku_equivalencias;
drop policy if exists "insert_master"        on public.sku_equivalencias;
drop policy if exists "update_master"        on public.sku_equivalencias;
drop policy if exists "delete_master"        on public.sku_equivalencias;

create policy lectura_con_perfil on public.sku_equivalencias
  for select to authenticated using (public.rol_actual() is not null);

create policy insert_master on public.sku_equivalencias
  for insert to authenticated with check (public.es_master());

create policy update_master on public.sku_equivalencias
  for update to authenticated using (public.es_master()) with check (public.es_master());

create policy delete_master on public.sku_equivalencias
  for delete to authenticated using (public.es_master());

revoke all on public.sku_equivalencias from anon;
