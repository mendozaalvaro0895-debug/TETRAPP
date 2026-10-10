-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Sincronización de asistencia desde la hoja de Drive (index.html → api/asistencia-drive.js)
--
-- 1) asistencia_diaria.area solo admitía 'tapas' y 'serig'. La hoja "ASISTENCIA DE PLANTA" trae TODAS las
--    áreas, así que se amplía el CHECK (mismo patrón que sql/asistencia_area_tapas_v1.sql). Las otras
--    pantallas filtran por área, no se ven afectadas.
-- 2) personal.nombre_hoja — alias opcional: el nombre EXACTO como aparece en la hoja, para vincular a
--    mano a quien el cruce automático de nombres no pudo resolver (se llena desde index.html).
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.asistencia_diaria drop constraint if exists asistencia_diaria_area_check;
alter table public.asistencia_diaria
  add constraint asistencia_diaria_area_check
  check (area in ('tapas', 'serig', 'produccion', 'bodega', 'mantenimiento', 'torno', 'moldes', 'molino', 'oficina'));

alter table public.personal add column if not exists nombre_hoja text;

notify pgrst, 'reload schema';

-- ── Verificación ────────────────────────────────────────────────
select conname, pg_get_constraintdef(oid) as definicion
from pg_constraint
where conrelid = 'public.asistencia_diaria'::regclass and conname = 'asistencia_diaria_area_check';
