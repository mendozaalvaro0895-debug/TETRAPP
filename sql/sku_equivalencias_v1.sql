-- sku_equivalencias_v1.sql
-- Tabla de variantes de SKU: un código de producción que se factura bajo otro código.
-- Correr en Supabase Dashboard → SQL Editor.

create table if not exists sku_equivalencias (
  id           serial primary key,
  sku_prod     text not null,
  sku_fact     text not null,
  nota         text,
  creado_en    timestamptz default now(),
  unique (sku_prod, sku_fact)
);

alter table sku_equivalencias enable row level security;

-- master: lectura y escritura
create policy "master_all_equiv" on sku_equivalencias
  for all
  using  (exists (select 1 from perfiles where id = auth.uid() and rol = 'master'))
  with check (exists (select 1 from perfiles where id = auth.uid() and rol = 'master'));

-- visor: solo lectura
create policy "visor_read_equiv" on sku_equivalencias
  for select
  using (exists (select 1 from perfiles where id = auth.uid() and rol = 'visor'));
