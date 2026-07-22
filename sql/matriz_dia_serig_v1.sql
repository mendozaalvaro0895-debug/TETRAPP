-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Matriz de posiciones POR DÍA (Serigrafía) v1.0
-- Registra quién cubrió cada puesto (rol + línea) cada día, para
-- congelar el roster "tal como quedó" y poder corregir días atrás.
--
-- SEPARADA de asistencia_diaria a propósito: guardar una posición NO
-- debe marcar a nadie presente/ausente. La asistencia sigue en su
-- tabla; aquí solo vive la posición de la matriz.
--
--   mtx_pos = clave de celda de la matriz:
--             "flameador-2", "imprime-3", "recibe-1",
--             "supervisor", "auxiliar", o "" (sin rol / pool ese día)
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor ANTES de usar
-- la función nueva. Es idempotente (se puede correr varias veces).
--
-- NOTA: sql/asistencia_mtx_pos_v1.sql quedó SUPERSEDIDO por este.
-- La columna asistencia_diaria.rol que aquel agregaba SÍ se sigue
-- usando (widget de asistencia + PDF); su columna mtx_pos ya no.
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.matriz_dia_serig (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha           date NOT NULL,
  operador_codigo text NOT NULL,
  area            text NOT NULL DEFAULT 'serig',
  mtx_pos         text,
  updated_at      timestamptz DEFAULT now(),
  UNIQUE (fecha, operador_codigo, area)
);

CREATE INDEX IF NOT EXISTS idx_matriz_dia_fecha ON public.matriz_dia_serig (fecha);

-- RLS: la maneja el admin (master) autenticado desde serigrafia.html.
ALTER TABLE public.matriz_dia_serig ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mds_all_auth ON public.matriz_dia_serig;
CREATE POLICY mds_all_auth ON public.matriz_dia_serig
  FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

-- Refrescar el caché de esquema de PostgREST (evita PGRST205 tras crear la tabla)
NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN — la tabla y su política deben existir:
-- ════════════════════════════════════════════════════════════════
SELECT 'tabla'   AS que, table_name  AS nombre FROM information_schema.tables
  WHERE table_schema='public' AND table_name='matriz_dia_serig'
UNION ALL
SELECT 'politica', policyname FROM pg_policies
  WHERE schemaname='public' AND tablename='matriz_dia_serig';
