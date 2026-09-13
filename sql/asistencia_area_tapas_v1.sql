-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Permitir area='tapas' en asistencia_diaria
--
-- La tabla `asistencia_diaria` (igual que `personal`) se creó manual en
-- el dashboard de Supabase, sin CREATE TABLE versionado. Si tiene un CHECK
-- constraint que solo permitía 'serig' (mismo patrón que bloqueó
-- area='produccion' en `personal` — ver sql/personal_area_produccion_v1.sql),
-- la Asistencia Mensual de Tapas (view-inicio, tapas.html) fallará con:
--   "new row for relation "asistencia_diaria" violates check constraint
--    "asistencia_diaria_area_check""
--
-- Este script es defensivo e idempotente: si el constraint no existe con
-- ese nombre exacto, el DROP simplemente no hace nada y el ADD lo crea
-- de cero con ambos valores permitidos. Correr en Supabase Dashboard →
-- SQL Editor.
-- ════════════════════════════════════════════════════════════════

alter table public.asistencia_diaria drop constraint if exists asistencia_diaria_area_check;

alter table public.asistencia_diaria
  add constraint asistencia_diaria_area_check check (area in ('tapas', 'serig'));

-- Refrescar caché PostgREST
notify pgrst, 'reload schema';

-- ── Verificación ────────────────────────────────────────────────
-- 1) Debe mostrar el constraint con ambos valores:
select conname, pg_get_constraintdef(oid) as definicion
from pg_constraint
where conrelid = 'public.asistencia_diaria'::regclass and conname = 'asistencia_diaria_area_check';

-- 2) Si el constraint tiene OTRO nombre (no 'asistencia_diaria_area_check'),
--    esta consulta lo muestra para que se ajuste el script:
select conname, pg_get_constraintdef(oid) as definicion
from pg_constraint
where conrelid = 'public.asistencia_diaria'::regclass and contype = 'c';
