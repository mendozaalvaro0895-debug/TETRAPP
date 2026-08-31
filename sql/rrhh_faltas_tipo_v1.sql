-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Agregar columna `tipo` a rrhh_faltas
-- Permite distinguir ausencias de tardanzas en la misma tabla.
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- Requiere que sql/rrhh_faltas_v1.sql ya haya corrido.
-- ════════════════════════════════════════════════════════════════

-- ── 1. Agregar columna tipo ───────────────────────────────────────
alter table public.rrhh_faltas
  add column if not exists tipo text not null default 'ausencia'
  check (tipo in ('ausencia','tardanza'));

-- Filas ya existentes (creadas antes de este script) quedan con
-- tipo='ausencia', que es correcto: toda falta auto-generada desde
-- la Asistencia Mensual corresponde a ausencia, no tardanza.

-- ── 2. Refrescar caché PostgREST ─────────────────────────────────
notify pgrst, 'reload schema';

-- ── 3. Verificación ──────────────────────────────────────────────
select column_name, data_type, column_default, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name   = 'rrhh_faltas'
  and column_name  = 'tipo';
