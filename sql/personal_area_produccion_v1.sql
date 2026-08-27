-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Permitir area='produccion' en personal
-- La tabla `personal` tiene un CHECK constraint (creado manual en el
-- dashboard, no versionado) que solo permitía 'tapas'/'serig'. Bloqueaba
-- crear personas de Producción desde gestion.html con el error:
--   "new row for relation "personal" violates check constraint
--    "personal_area_check""
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal drop constraint if exists personal_area_check;

alter table public.personal
  add constraint personal_area_check check (area in ('tapas', 'serig', 'produccion'));

-- Verificación
select conname, pg_get_constraintdef(oid) as definicion
from pg_constraint
where conrelid = 'public.personal'::regclass and conname = 'personal_area_check';
