-- ══════════════════════════════════════════════════════════════════
-- DIAGNÓSTICO + FIX: Requi 1117 → S-076 + S-022
-- Corre PRIMERO el bloque de DIAGNÓSTICO. Luego, según los resultados,
-- corre el bloque de FIX que corresponda.
-- Dashboard Supabase → SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- ── PASO 1: DIAGNÓSTICO ────────────────────────────────────────────
-- Muestra el estado actual de salidas e ingresos para S-076 y S-022.

-- 1a. UUIDs y estado de las fichas
--     (la columna real es "codigo", no "id_display")
SELECT id, codigo, cliente_nombre AS cliente, estado
FROM solicitudes
WHERE codigo IN ('S-076', 'S-022')
ORDER BY codigo;

-- 1b. Salidas de bodega vinculadas a S-076 o S-022
SELECT mm.id,
       mm.num_documento,
       mm.sku_original,
       mm.cantidad,
       mm.solicitud_id,
       s.codigo,
       mm.created_at::date AS fecha
FROM movimientos_materiales mm
LEFT JOIN solicitudes s ON s.id = mm.solicitud_id
WHERE mm.tipo  = 'salida_bodega'
  AND mm.area  = 'serig'
  AND s.codigo IN ('S-076', 'S-022')
ORDER BY mm.created_at;

-- 1c. Salidas cuyo num_documento contiene "1117"
--     (por si la salida no está vinculada todavía a ninguna ficha)
SELECT mm.id,
       mm.num_documento,
       mm.sku_original,
       mm.cantidad,
       mm.solicitud_id,
       s.codigo,
       mm.created_at::date AS fecha
FROM movimientos_materiales mm
LEFT JOIN solicitudes s ON s.id = mm.solicitud_id
WHERE mm.tipo  = 'salida_bodega'
  AND mm.area  = 'serig'
  AND mm.num_documento ILIKE '%1117%'
ORDER BY mm.created_at;

-- 1d. Ingresos PT (entregas_serig) vinculados a S-076 o S-022
--     sol_id es TEXT en entregas_serig → cast a uuid para el JOIN
SELECT es.id,
       es.requi,
       es.cant,
       es.sol_id,
       es.fecha,
       s.codigo,
       es.lineas
FROM entregas_serig es
LEFT JOIN solicitudes s ON s.id = es.sol_id::uuid
WHERE s.codigo IN ('S-076', 'S-022')
ORDER BY es.fecha;


-- ══════════════════════════════════════════════════════════════════
-- ── PASO 2: FIX ───────────────────────────────────────────────────
-- Después de ver los resultados del diagnóstico, aplica el escenario
-- que corresponda. Solo corre UNO de los escenarios según lo que
-- veas arriba.
-- ══════════════════════════════════════════════════════════════════

-- ── ESCENARIO A: Hay UNA salida de 7,500 ligada a S-076
--    → Ajustar a 4,650 y agregar registro nuevo de 3,000 para S-022
-- ──────────────────────────────────────────────────────────────────
-- Reemplaza los valores entre <...> con los reales del diagnóstico:
--   <UUID_SALIDA>     → id de la fila en movimientos_materiales (1b o 1c)
--   <UUID_SOL_S076>   → id de S-076 en solicitudes (1a)
--   <UUID_SOL_S022>   → id de S-022 en solicitudes (1a)

/*
BEGIN;

-- Ajustar la salida existente a 4,650 (para S-076)
UPDATE movimientos_materiales
SET    cantidad = 4650,
       solicitud_id = '<UUID_SOL_S076>'
WHERE  id = '<UUID_SALIDA>';

-- Insertar nuevo registro de salida para S-022 (3,000 und)
INSERT INTO movimientos_materiales
  (tipo, area, num_documento, sku_original, cantidad, solicitud_id, observaciones)
SELECT
  'salida_bodega',
  'serig',
  num_documento,          -- misma Requi 1117
  sku_original,           -- mismo SKU 214763
  3000,
  '<UUID_SOL_S022>',
  'Split Requi 1117 → S-022 (3,000 und)'
FROM movimientos_materiales
WHERE id = '<UUID_SALIDA>';

COMMIT;
*/


-- ── ESCENARIO B: Hay DOS salidas (una por ficha) con montos incorrectos
--    → Actualizar cada una a la cantidad correcta
-- ──────────────────────────────────────────────────────────────────
-- Reemplaza:
--   <UUID_SALIDA_S076> → id de la fila ligada a S-076
--   <UUID_SALIDA_S022> → id de la fila ligada a S-022

/*
BEGIN;

UPDATE movimientos_materiales
SET cantidad = 4650
WHERE id = '<UUID_SALIDA_S076>';

UPDATE movimientos_materiales
SET cantidad = 3000
WHERE id = '<UUID_SALIDA_S022>';

COMMIT;
*/


-- ── ESCENARIO C: La salida tiene solicitud_id NULL (no vinculada)
--    → Actualizar para vincularla a S-076 (4,650) y agregar S-022 (3,000)
-- ──────────────────────────────────────────────────────────────────
-- Reemplaza:
--   <UUID_SALIDA>    → id de la fila sin solicitud_id
--   <UUID_SOL_S076>  → id de S-076
--   <UUID_SOL_S022>  → id de S-022

/*
BEGIN;

UPDATE movimientos_materiales
SET cantidad     = 4650,
    solicitud_id = '<UUID_SOL_S076>'
WHERE id = '<UUID_SALIDA>';

INSERT INTO movimientos_materiales
  (tipo, area, num_documento, sku_original, cantidad, solicitud_id, observaciones)
SELECT
  'salida_bodega', 'serig',
  num_documento, sku_original,
  3000,
  '<UUID_SOL_S022>',
  'Split Requi 1117 → S-022 (3,000 und)'
FROM movimientos_materiales
WHERE id = '<UUID_SALIDA>';

COMMIT;
*/
