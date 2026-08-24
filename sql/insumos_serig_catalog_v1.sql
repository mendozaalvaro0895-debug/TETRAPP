-- ============================================================
-- INSUMOS SERIGRAFÍA — Catálogo v1 (Ago 2026)
-- 53 SKUs de Bodega 7 etiquetados como area='serig'
-- ============================================================
-- PASO 1: Añadir columna area (idempotente)
ALTER TABLE insumos_b7 ADD COLUMN IF NOT EXISTS area TEXT DEFAULT 'general';

-- PASO 2: Marcar como 'serig' los SKUs ya existentes
--         También corrige el stock_minimo al valor oficial del Excel
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6240';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6251';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6252';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6235';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6245';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6237';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6328';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6256';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6735';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '7139';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6242';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 1   WHERE sku = '6339';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 1   WHERE sku = '6342';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 1   WHERE sku = '6341';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6734';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 1   WHERE sku = '6733';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 3   WHERE sku = '6320';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 4   WHERE sku = '6250';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 4   WHERE sku = '6401';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 4   WHERE sku = '6793';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 4   WHERE sku = '6330';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 4   WHERE sku = '6312';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 4   WHERE sku = '6377';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 4   WHERE sku = '6313';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 4   WHERE sku = '6376';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 4   WHERE sku = '6301';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6324';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6236';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6238';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6239';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 50  WHERE sku = '6120'; -- 50 uni (Excel row duplicado: se usa 50, no 500)
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6354';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6863';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '7057';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '7118';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6700';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6457';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6322';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6246';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6247';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6249';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6309';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 3   WHERE sku = '6300';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6243';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6736';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6439';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6865';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '7116';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6257';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6321';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 2   WHERE sku = '6241';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 500 WHERE sku = '6095';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 10  WHERE sku = '6128';
UPDATE insumos_b7 SET area = 'serig', stock_minimo = 100 WHERE sku = '6323';

-- PASO 3: Insertar los SKUs que NO existen todavía en insumos_b7
INSERT INTO insumos_b7 (sku, descripcion, stock_minimo, existencia, area, activo)
SELECT v.sku, v.descripcion, v.stock_minimo, 0, 'serig', true
FROM (VALUES
  ('6240', 'AZUL COBALTO POLICAT (R2-2191)',          2),
  ('6251', 'AZUL MEDIO POLICAT R2-2013',              2),
  ('6252', 'AZUL TURQUEZA POLICAT R2-2012',           2),
  ('6235', 'AZUL ULTRA POLICAT (R2-2020)',            2),
  ('6245', 'BICROMATO (U5-2002)',                     2),
  ('6237', 'BLANCO POLICAT (R2-6011)',                2),
  ('6328', 'BUGAMBILIA POLICAT',                      2),
  ('6256', 'CAFE POLICAT',                            2),
  ('6735', 'CATALIZADOR EPOXICO',                     2),
  ('7139', 'CATALIZADOR EPOXICO ADE677',              2),
  ('6242', 'CATALIZADOR POLICAT (R2-100)',             2),
  ('6339', 'CILINDRO DE GAS DE 100 LIBRAS',           1),
  ('6342', 'CILINDRO DE GAS DE 25 LIBRAS',            1),
  ('6341', 'CILINDRO DE GAS DE 35 LIBRAS',            1),
  ('6734', 'EPOXICA APAQUE WHITE NAZDAR',             2),
  ('6733', 'EPOXICA MAGENTA NAZDAR',                  1),
  ('6320', 'GALON THINNER',                           3),
  ('6250', 'HULE ANCHO (HAN)',                        4),
  ('6401', 'HULE CUADRADO',                           4),
  ('6793', 'HULE DIAMANTE DUREZA 80',                 4),
  ('6330', 'MALLA AMARILLA N.0 380 150/ 380-34',      4),
  ('6312', 'MALLA AMARILLA NO. 330',                  4),
  ('6377', 'MALLA AMARILLA NO. 355',                  4),
  ('6313', 'MALLA AMARILLA NO.305 (ANCHO 65)',        4),
  ('6376', 'MALLA BLANCA 305',                        4),
  ('6301', 'MALLA BLANCA NO. 120 (ANCHO 65)',         4),
  ('6324', 'MANDARINA POLICAT',                       2),
  ('6236', 'NEGRO POLICAT (R2-1011)',                 2),
  ('6238', 'ORO ROJIZO POLICAT (R2-4092)',            2),
  ('6239', 'PLATA POLICAT (R2-6091)',                 2),
  ('6120', 'PLIEGOS DE PAPEL CRAFT',                 50),
  ('6354', 'POLIYALL BLACK PA70',                     2),
  ('6863', 'POLIYALL BRIGHT RED PA52',                2),
  ('7057', 'POLIYALL EMERALD GREEN PA30',             2),
  ('7118', 'POLIYALL REFLEX BLUE PA450',              2),
  ('6700', 'POLIYALL YELLOW PA21',                    2),
  ('6457', 'REMOVEDOR DE EMULSION LIQUIDO',           2),
  ('6322', 'ROJO ESCARLATA POLICAT',                  2),
  ('6246', 'SERICLIN (U9-9200)',                      2),
  ('6247', 'SERISOL (U5-4020)',                       2),
  ('6249', 'SOLVENTE (P1-300)',                       2),
  ('6309', 'SOLVENTE ACONDICIONADOR P1-600',          2),
  ('6300', 'SOLVENTE LIMPIA PANTALLAS P103',          3),
  ('6243', 'SOLVENTE RETARDANTE (P1-901)',            2),
  ('6736', 'SOLVENTE RETARDER EPOXICO',               2),
  ('6439', 'SOLVENTE RETARDER EPOXICO ER-189',        2),
  ('6865', 'SOLVENTE RETARDER PARA POLIYALL PAQ8',   2),
  ('7116', 'TINTA EPOXICA SILVER ER-187',             2),
  ('6257', 'VERDE BANDERA POLICAT',                   2),
  ('6321', 'VERDE BRILLANTE POLICAT',                 2),
  ('6241', 'VIOLETA POLICAT (R2-8164)',               2),
  ('6095', 'BOLSAS DE 3 @',                         500),
  ('6128', 'SELLADORES',                             10),
  ('6323', 'LIBRA DE RETAZO DE TELA',               100)
) AS v(sku, descripcion, stock_minimo)
WHERE NOT EXISTS (SELECT 1 FROM insumos_b7 WHERE sku = v.sku);

-- VERIFICAR: ¿cuántos quedaron etiquetados como serig?
SELECT count(*), area FROM insumos_b7 GROUP BY area ORDER BY area;
