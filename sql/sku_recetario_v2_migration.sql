-- sku_recetario_v2_migration.sql
-- Agrega columnas que no existían en la versión inicial de sku_recetas.
-- Correr en Supabase Dashboard → SQL Editor.
-- SOLO si ya corriste sku_recetario_v1.sql y la tabla ya existe.

alter table public.sku_recetas
  add column if not exists area       text check (area in ('tapas','serigrafia','produccion')),
  add column if not exists es_directo boolean default false,
  add column if not exists guardado   boolean default false;
