-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Permitir area='molino' y area='bodega' en personal
--
-- Mismo CHECK constraint que ya tocamos para 'produccion'
-- (sql/personal_area_produccion_v1.sql) — se vuelve a reemplazar
-- completo para sumar estos dos valores nuevos. Molino y Bodega
-- todavía no tienen módulo propio en la app; este registro de
-- personal sirve de base para cuando se construyan.
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal drop constraint if exists personal_area_check;

alter table public.personal
  add constraint personal_area_check
  check (area in ('tapas', 'serig', 'produccion', 'molino', 'bodega'));

-- Verificación
select conname, pg_get_constraintdef(oid) as definicion
from pg_constraint
where conrelid = 'public.personal'::regclass and conname = 'personal_area_check';
