-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Columna turno en personal (Producción: Turno Alex / Gabino)
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

-- 1. Mostrar qué constraint hay ANTES de tocar nada (diagnóstico)
select conname, pg_get_constraintdef(oid) as definicion_actual
from pg_constraint
where conrelid = 'public.personal'::regclass and conname = 'personal_turno_check';

-- 2. Columna (por si no existiera todavía)
alter table public.personal add column if not exists turno text;

-- 3. Reemplazar el constraint por la definición correcta, sea cual
--    sea la que había antes (columna creada manual en el dashboard
--    con otra regla, versión vieja de este script, etc.)
alter table public.personal drop constraint if exists personal_turno_check;
alter table public.personal
  add constraint personal_turno_check check (turno is null or turno in ('alex', 'gabino'));

-- 4. Refrescar caché PostgREST
notify pgrst, 'reload schema';

-- 5. Mostrar el constraint DESPUÉS — debe decir exactamente:
--    CHECK (((turno IS NULL) OR (turno = ANY (ARRAY['alex'::text, 'gabino'::text]))))
select conname, pg_get_constraintdef(oid) as definicion_final
from pg_constraint
where conrelid = 'public.personal'::regclass and conname = 'personal_turno_check';
