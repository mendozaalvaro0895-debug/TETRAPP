-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Columna edad en tabla personal
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal add column if not exists edad smallint;

-- Refrescar caché PostgREST
notify pgrst, 'reload schema';

-- Verificación
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'personal' and column_name = 'edad';
