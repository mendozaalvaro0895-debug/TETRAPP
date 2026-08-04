-- sku_recetario_directo_v1.sql
-- Agrega columna es_directo a sku_recetas para marcar SKUs que se
-- venden bajo el mismo código que se producen (sin proceso adicional).
-- Correr en Supabase Dashboard → SQL Editor.

alter table public.sku_recetas
  add column if not exists es_directo boolean default false;
