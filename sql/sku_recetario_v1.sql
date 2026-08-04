-- sku_recetario_v1.sql
-- Recetario de SKUs: un SKU facturable puede tener N partes (base, accesorio, proceso).
-- Reemplaza sku_equivalencias (tabla aún vacía).
-- Correr en Supabase Dashboard → SQL Editor.

-- 1. Eliminar tabla anterior (vacía, sin datos que perder)
drop table if exists public.sku_equivalencias;

-- 2. Cabecera: una fila por SKU facturable
create table if not exists public.sku_recetas (
  id          serial primary key,
  sku_fact    text not null unique,
  descripcion text,
  creado_en   timestamptz default now()
);

-- 3. Partes: N filas por receta (base, accesorio, proceso)
create table if not exists public.sku_receta_partes (
  id          serial primary key,
  receta_id   int not null references public.sku_recetas(id) on delete cascade,
  orden       smallint not null default 1,
  tipo        text not null check (tipo in ('base','accesorio','proceso')),
  codigo      text not null,
  nota        text,
  creado_en   timestamptz default now()
);

-- ── RLS sku_recetas ──────────────────────────────────────────────
alter table public.sku_recetas enable row level security;

drop policy if exists lectura_con_perfil on public.sku_recetas;
drop policy if exists insert_master       on public.sku_recetas;
drop policy if exists update_master       on public.sku_recetas;
drop policy if exists delete_master       on public.sku_recetas;

create policy lectura_con_perfil on public.sku_recetas
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_master on public.sku_recetas
  for insert to authenticated with check (public.es_master());
create policy update_master on public.sku_recetas
  for update to authenticated using (public.es_master()) with check (public.es_master());
create policy delete_master on public.sku_recetas
  for delete to authenticated using (public.es_master());

revoke all on public.sku_recetas from anon;
grant select, insert, update, delete on public.sku_recetas to authenticated;
grant usage, select on sequence public.sku_recetas_id_seq to authenticated;

-- ── RLS sku_receta_partes ────────────────────────────────────────
alter table public.sku_receta_partes enable row level security;

drop policy if exists lectura_con_perfil on public.sku_receta_partes;
drop policy if exists insert_master       on public.sku_receta_partes;
drop policy if exists update_master       on public.sku_receta_partes;
drop policy if exists delete_master       on public.sku_receta_partes;

create policy lectura_con_perfil on public.sku_receta_partes
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_master on public.sku_receta_partes
  for insert to authenticated with check (public.es_master());
create policy update_master on public.sku_receta_partes
  for update to authenticated using (public.es_master()) with check (public.es_master());
create policy delete_master on public.sku_receta_partes
  for delete to authenticated using (public.es_master());

revoke all on public.sku_receta_partes from anon;
grant select, insert, update, delete on public.sku_receta_partes to authenticated;
grant usage, select on sequence public.sku_receta_partes_id_seq to authenticated;
