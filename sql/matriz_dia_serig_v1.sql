-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Matriz de posiciones POR DÍA (Serigrafía) v1.1
-- Registra quién cubrió cada puesto (rol + línea) cada día, para
-- congelar el roster "tal como quedó" y poder corregir días atrás.
--
-- SEPARADA de asistencia_diaria a propósito: guardar una posición NO
-- debe marcar a nadie presente/ausente.
--
--   mtx_pos = clave de celda de la matriz:
--             "flameador-2", "imprime-3", "recibe-1",
--             "supervisor", "auxiliar", o "" (sin rol / pool ese día)
--
-- v1.1: agrega el GRANT a authenticated (faltaba en v1.0 → todo acceso
-- denegado a nivel de tabla, aunque hubiera política) y usa los helpers
-- rol_actual()/es_master() como el resto de tablas del proyecto.
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Es idempotente.
--
-- NOTA: sql/asistencia_mtx_pos_v1.sql quedó SUPERSEDIDO por este. La
-- columna asistencia_diaria.rol que aquel agregaba SÍ se sigue usando
-- (widget de asistencia + PDF); su columna mtx_pos ya no.
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

-- 1) GRANT a nivel de tabla — IMPRESCINDIBLE (sin esto se niega todo)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.matriz_dia_serig TO authenticated;

-- 2) RLS con el patrón del proyecto: leer cualquier perfil, escribir solo master
ALTER TABLE public.matriz_dia_serig ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mds_all_auth ON public.matriz_dia_serig;  -- política vieja de v1.0

DROP POLICY IF EXISTS mds_select ON public.matriz_dia_serig;
CREATE POLICY mds_select ON public.matriz_dia_serig
  FOR SELECT TO authenticated USING (public.rol_actual() IS NOT NULL);

DROP POLICY IF EXISTS mds_insert ON public.matriz_dia_serig;
CREATE POLICY mds_insert ON public.matriz_dia_serig
  FOR INSERT TO authenticated WITH CHECK (public.es_master());

DROP POLICY IF EXISTS mds_update ON public.matriz_dia_serig;
CREATE POLICY mds_update ON public.matriz_dia_serig
  FOR UPDATE TO authenticated USING (public.es_master()) WITH CHECK (public.es_master());

DROP POLICY IF EXISTS mds_delete ON public.matriz_dia_serig;
CREATE POLICY mds_delete ON public.matriz_dia_serig
  FOR DELETE TO authenticated USING (public.es_master());

-- Refrescar el caché de esquema de PostgREST
NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN — tabla + políticas + grant:
-- ════════════════════════════════════════════════════════════════
SELECT 'tabla'    AS que, table_name AS nombre FROM information_schema.tables
  WHERE table_schema='public' AND table_name='matriz_dia_serig'
UNION ALL
SELECT 'politica', policyname FROM pg_policies
  WHERE schemaname='public' AND tablename='matriz_dia_serig'
UNION ALL
SELECT 'grant', privilege_type FROM information_schema.role_table_grants
  WHERE table_schema='public' AND table_name='matriz_dia_serig' AND grantee='authenticated';
