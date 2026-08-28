-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Turno de Producción (Alex / Gabino) en columna PROPIA
--
-- ⚠️ `personal` YA TENÍA una columna `turno` (texto libre, valores
-- 'AM' en TODAS las filas de TODAS las áreas — no la usa ningún HTML
-- del repo, parece dato viejo/no explotado, pero es dato real y no
-- se toca). El intento anterior (sql/personal_turno_v1.sql) quiso
-- reusar ese mismo nombre para "Alex"/"Gabino" y chocó con esos
-- datos. Esta versión usa una columna NUEVA y separada.
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal add column if not exists turno_produccion text;

alter table public.personal drop constraint if exists personal_turno_produccion_check;
alter table public.personal
  add constraint personal_turno_produccion_check
  check (turno_produccion is null or turno_produccion in ('alex', 'gabino'));

notify pgrst, 'reload schema';

-- Verificación
select conname, pg_get_constraintdef(oid) as definicion
from pg_constraint
where conrelid = 'public.personal'::regclass and conname = 'personal_turno_produccion_check';
