-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Permitir area='oficina' en personal
--
-- Mismo CHECK constraint que ya tocamos para produccion/molino/bodega/
-- moldes/mantenimiento/torno — se reemplaza completo para sumar este
-- valor nuevo. Salió al terminar de reconciliar personal contra la
-- hoja "ASISTENCIA DE PLANTA": el grupo "Oficina/Administración" de
-- la hoja no tenía dónde entrar. Oficina no tiene módulo propio en la
-- app todavía — este registro de personal sirve de base para cuando
-- se construya, mismo patrón que las áreas anteriores.
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal drop constraint if exists personal_area_check;

alter table public.personal
  add constraint personal_area_check
  check (area in ('tapas', 'serig', 'produccion', 'molino', 'bodega', 'moldes', 'mantenimiento', 'torno', 'oficina'));

-- Verificación
select conname, pg_get_constraintdef(oid) as definicion
from pg_constraint
where conrelid = 'public.personal'::regclass and conname = 'personal_area_check';
