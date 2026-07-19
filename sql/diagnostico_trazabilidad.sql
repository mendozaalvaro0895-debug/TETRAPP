-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Diagnóstico previo al Tablero de Trazabilidad
-- SOLO LECTURA. No modifica nada.
--
-- Una sola consulta que devuelve TODO en una tabla (bloque | resultado).
-- El SQL Editor de Supabase solo muestra el resultado de la última
-- sentencia; por eso todo va unificado con UNION ALL.
-- Correr completo y pegar la tabla de vuelta.
-- ════════════════════════════════════════════════════════════════

WITH
-- A. ¿Está poblado el multiplicador de TIROS?
--    tiros_impresos ≈ envases × solicitud_lineas.tiros
a AS (
  SELECT 'A · tiros'::text AS bloque,
         ('tiros=' || COALESCE(tiros,0) || '  →  ' || n || ' líneas')::text AS resultado
  FROM (
    SELECT sl.tiros AS tiros, COUNT(*) AS n
    FROM solicitud_lineas sl
    JOIN solicitudes s ON s.id = sl.solicitud_id
    WHERE s.area = 'serig'
    GROUP BY sl.tiros
  ) q
),

-- B. La salida de bodega: ¿guarda SKU BASE o IMPRESO?
b AS (
  SELECT 'B · salida SKU'::text AS bloque,
         (tipo || '  →  ' || movs || ' mov / ' || und || ' und')::text AS resultado
  FROM (
    SELECT
      CASE
        WHEN m.solicitud_id IS NULL THEN 'sin pedido vinculado'
        WHEN EXISTS (SELECT 1 FROM solicitud_lineas sl
                     WHERE sl.solicitud_id = m.solicitud_id AND sl.sku_base = m.sku_original)
          THEN 'coincide BASE (correcto)'
        WHEN EXISTS (SELECT 1 FROM solicitud_lineas sl
                     WHERE sl.solicitud_id = m.solicitud_id AND sl.sku = m.sku_original)
          THEN 'coincide IMPRESO (revisar)'
        ELSE 'no coincide con ninguno'
      END                         AS tipo,
      COUNT(*)                    AS movs,
      COALESCE(SUM(m.cantidad),0) AS und
    FROM movimientos_materiales m
    WHERE m.tipo = 'salida_bodega' AND COALESCE(m.area,'serig') = 'serig'
    GROUP BY 1
  ) q
),

-- C. ¿Cuánto PT vive en cada tabla? (fuente de verdad)
c AS (
  SELECT 'C · fuente PT'::text AS bloque,
         ('movimientos entrada_pt  →  ' || COUNT(*) || ' filas / ' || COALESCE(SUM(cantidad),0) || ' und')::text AS resultado
  FROM movimientos_materiales
  WHERE tipo = 'entrada_pt' AND COALESCE(area,'serig') = 'serig'
  UNION ALL
  SELECT 'C · fuente PT'::text,
         ('entregas_serig  →  ' || COUNT(*) || ' filas')::text
  FROM entregas_serig
),

-- D. Columnas reales de entregas_serig
d AS (
  SELECT 'D · entregas_serig cols'::text AS bloque,
         COALESCE(string_agg(column_name, ', ' ORDER BY ordinal_position),
                  '(tabla vacía o inexistente)')::text AS resultado
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'entregas_serig'
),

-- E. ¿Están poblados los sku_base en los pedidos?
e AS (
  SELECT 'E · sku_base'::text AS bloque,
         ('total líneas=' || COUNT(*) ||
          '  con_sku_base=' || COUNT(*) FILTER (WHERE sl.sku_base IS NOT NULL AND sl.sku_base <> ''))::text AS resultado
  FROM solicitud_lineas sl
  JOIN solicitudes s ON s.id = sl.solicitud_id
  WHERE s.area = 'serig'
),

-- F. Sanity del destino recién agregado a Flameado
f AS (
  SELECT 'F · destino flameado'::text AS bloque,
         ('total=' || COUNT(*) ||
          '  con_destino_sku=' || COUNT(destino_sku) ||
          '  con_solicitud_id=' || COUNT(solicitud_id))::text AS resultado
  FROM registro_flameado_serig
  WHERE area = 'serig'
)

SELECT * FROM a
UNION ALL SELECT * FROM b
UNION ALL SELECT * FROM c
UNION ALL SELECT * FROM d
UNION ALL SELECT * FROM e
UNION ALL SELECT * FROM f
ORDER BY bloque, resultado;
