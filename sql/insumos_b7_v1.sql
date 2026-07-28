-- ══════════════════════════════════════════════════════════════════
-- INSUMOS BODEGA 7 — Serigrafía v1
-- Corre en Supabase → SQL Editor (una sola vez)
-- ──────────────────────────────────────────────────────────────────
-- PASO 1: Nuevas columnas en inventario
-- ══════════════════════════════════════════════════════════════════
ALTER TABLE inventario
  ADD COLUMN IF NOT EXISTS bodega       TEXT    DEFAULT 'B2',
  ADD COLUMN IF NOT EXISTS stock_minimo NUMERIC DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_inventario_bodega ON inventario(bodega);

-- ══════════════════════════════════════════════════════════════════
-- PASO 2: Registra / actualiza los 51 insumos de Bodega 7
-- • Si el SKU ya existe  → asigna bodega='B7' y stock_minimo
--   (preserva la existencia actual)
-- • Si el SKU no existe  → lo inserta con existencia=0
--   (se actualizará en la próxima importación de Bodega 7)
-- ══════════════════════════════════════════════════════════════════
INSERT INTO inventario (sku, descripcion, existencia, facturable, activo, bodega, stock_minimo)
VALUES
  ('6240', 'AZUL COBALTO POLICAT (R2-2191)',          0, false, true, 'B7', 2),
  ('6251', 'AZUL MEDIO POLICAT R2-2013',               0, false, true, 'B7', 2),
  ('6252', 'AZUL TURQUEZA POLICAT R2-2012',            0, false, true, 'B7', 2),
  ('6235', 'AZUL ULTRA POLICAT (R2-2020)',             0, false, true, 'B7', 2),
  ('6245', 'BICROMATO (U5-2002)',                      0, false, true, 'B7', 2),
  ('6237', 'BLANCO POLICAT (R2-6011)',                 0, false, true, 'B7', 2),
  ('6328', 'BUGAMBILIA POLICAT',                       0, false, true, 'B7', 2),
  ('6256', 'CAFE POLICAT',                             0, false, true, 'B7', 2),
  ('6735', 'CATALIZADOR EPOXICO',                      0, false, true, 'B7', 2),
  ('7139', 'CATALIZADOR EPOXICO ADE677',               0, false, true, 'B7', 2),
  ('6242', 'CATALIZADOR POLICAT (R2-100)',              0, false, true, 'B7', 2),
  ('6339', 'CILINDRO DE GAS DE 100 LIBRAS',            0, false, true, 'B7', 1),
  ('6342', 'CILINDRO DE GAS DE 25 LIBRAS',             0, false, true, 'B7', 1),
  ('6341', 'CILINDRO DE GAS DE 35 LIBRAS',             0, false, true, 'B7', 1),
  ('6734', 'EPOXICA APAQUE WHITE NAZDAR',               0, false, true, 'B7', 2),
  ('6733', 'EPOXICA MAGENTA NAZDAR',                   0, false, true, 'B7', 1),
  ('6320', 'GALON THINNER',                            0, false, true, 'B7', 3),
  ('6250', 'HULE ANCHO (HAN)',                         0, false, true, 'B7', 4),
  ('6401', 'HULE CUADRADO',                            0, false, true, 'B7', 4),
  ('6793', 'HULE DIAMANTE DUREZA 80',                  0, false, true, 'B7', 4),
  ('6330', 'MALLA AMARILLA N.0 380 150/ 380-34',       0, false, true, 'B7', 4),
  ('6312', 'MALLA AMARILLA NO. 330',                   0, false, true, 'B7', 4),
  ('6377', 'MALLA AMARILLA NO. 355',                   0, false, true, 'B7', 4),
  ('6313', 'MALLA AMARILLA NO.305 (ANCHO 65)',         0, false, true, 'B7', 4),
  ('6376', 'MALLA BLANCA 305',                         0, false, true, 'B7', 4),
  ('6301', 'MALLA BLANCA NO. 120 (ANCHO 65)',          0, false, true, 'B7', 4),
  ('6324', 'MANDARINA POLICAT',                        0, false, true, 'B7', 2),
  ('6236', 'NEGRO POLICAT (R2-1011)',                   0, false, true, 'B7', 2),
  ('6238', 'ORO ROJIZO POLICAT (R2-4092)',              0, false, true, 'B7', 2),
  ('6239', 'PLATA POLICAT (R2-6091)',                   0, false, true, 'B7', 2),
  ('6120', 'PLIEGOS DE PAPEL CRAFT',                   0, false, true, 'B7', 500),
  ('6354', 'POLIYALL BLACK PA70',                      0, false, true, 'B7', 2),
  ('6863', 'POLIYALL BRIGHT RED PA52',                 0, false, true, 'B7', 2),
  ('7057', 'POLIYALL EMERALD GREEN PA30',              0, false, true, 'B7', 2),
  ('7118', 'POLIYALL REFLEX BLUE PA450',               0, false, true, 'B7', 2),
  ('6700', 'POLIYALL YELLOW PA21',                     0, false, true, 'B7', 2),
  ('6457', 'REMOVEDOR DE EMULSION LIQUIDO',            0, false, true, 'B7', 2),
  ('6322', 'ROJO ESCARLATA POLICAT',                   0, false, true, 'B7', 2),
  ('6246', 'SERICLIN (U9-9200)',                       0, false, true, 'B7', 2),
  ('6247', 'SERISOL (U5-4020)',                        0, false, true, 'B7', 2),
  ('6249', 'SOLVENTE (P1-300)',                        0, false, true, 'B7', 2),
  ('6309', 'SOLVENTE ACONDICIONADOR P1-600',           0, false, true, 'B7', 2),
  ('6300', 'SOLVENTE LIMPIA PANTALLAS P103',           0, false, true, 'B7', 3),
  ('6243', 'SOLVENTE RETARDANTE (P1-901)',              0, false, true, 'B7', 2),
  ('6736', 'SOLVENTE RETARDER EPOXICO',                0, false, true, 'B7', 2),
  ('6439', 'SOLVENTE RETARDER EPOXICO ER-189',         0, false, true, 'B7', 2),
  ('6865', 'SOLVENTE RETARDER PARA POLIYALL PAQ8',    0, false, true, 'B7', 2),
  ('7116', 'TINTA EPOXICA SILVER ER-187',              0, false, true, 'B7', 2),
  ('6257', 'VERDE BANDERA POLICAT',                    0, false, true, 'B7', 2),
  ('6321', 'VERDE BRILLANTE POLICAT',                  0, false, true, 'B7', 2),
  ('6241', 'VIOLETA POLICAT (R2-8164)',                0, false, true, 'B7', 2)
ON CONFLICT (sku) DO UPDATE SET
  bodega       = 'B7',
  stock_minimo = EXCLUDED.stock_minimo;
-- La columna existencia NO se toca si el SKU ya existe.
