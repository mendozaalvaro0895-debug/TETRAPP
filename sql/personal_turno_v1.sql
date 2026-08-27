-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Columna turno en personal (Producción: Turno Alex / Gabino)
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal add column if not exists turno text;

alter table public.personal drop constraint if exists personal_turno_check;
alter table public.personal
  add constraint personal_turno_check check (turno is null or turno in ('alex', 'gabino'));

-- Verificación
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'personal' and column_name = 'turno';
