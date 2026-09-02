-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Permitir area='moldes' en personal
--
-- Mismo CHECK constraint que ya tocamos para 'produccion'/'molino'/
-- 'bodega' — se reemplaza completo para sumar este valor nuevo.
-- Moldes todavía no tiene módulo propio en la app; este registro de
-- personal sirve de base para cuando se construya.
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal drop constraint if exists personal_area_check;

alter table public.personal
  add constraint personal_area_check
  check (area in ('tapas', 'serig', 'produccion', 'molino', 'bodega', 'moldes'));

-- Verificación
select conname, pg_get_constraintdef(oid) as definicion
from pg_constraint
where conrelid = 'public.personal'::regclass and conname = 'personal_area_check';
