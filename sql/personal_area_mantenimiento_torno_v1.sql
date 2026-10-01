-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Permitir area='mantenimiento' y area='torno' en personal
--
-- Mismo CHECK constraint que ya tocamos para produccion/molino/bodega/
-- moldes — se reemplaza completo para sumar estos dos valores nuevos.
-- Salieron al reconciliar personal contra "ASISTENCIA DE PLANTA"
-- (Google Sheets) — Gerardo González y Josué Gamaliel Choc son de
-- Mantenimiento, Ludwin Alvarez Pérez es de Torno, y en personal
-- no había dónde ponerlos (quedaron mal clasificados en produccion/
-- moldes). Ninguna de las dos áreas tiene módulo propio en la app
-- todavía — este registro de personal sirve de base para cuando se
-- construyan, mismo patrón que molino/bodega/moldes.
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal drop constraint if exists personal_area_check;

alter table public.personal
  add constraint personal_area_check
  check (area in ('tapas', 'serig', 'produccion', 'molino', 'bodega', 'moldes', 'mantenimiento', 'torno'));

-- Verificación
select conname, pg_get_constraintdef(oid) as definicion
from pg_constraint
where conrelid = 'public.personal'::regclass and conname = 'personal_area_check';
