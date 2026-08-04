-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Verificación general de SQLs corridos
-- Pega este bloque completo en Supabase Dashboard → SQL Editor → Run
-- Cada sección imprime un resultado; revísalos de arriba a abajo.
-- No modifica nada, solo lee.
-- ════════════════════════════════════════════════════════════════

-- ── A. produccion_v1.sql — ¿existe la tabla y tiene RLS? ──────────
select 'A. produccion_diaria' as chequeo, tablename, rowsecurity
from pg_tables where schemaname = 'public' and tablename = 'produccion_diaria';

-- ── B. produccion_v1.sql — las 4 políticas ────────────────────────
select 'B. politicas produccion_diaria' as chequeo, policyname, cmd
from pg_policies where schemaname = 'public' and tablename = 'produccion_diaria'
order by policyname;

-- ── C. produccion_v1.sql — columnas nuevas en inventario ──────────
select 'C. columnas inventario' as chequeo, column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'inventario'
  and column_name in ('meta_12hrs','maquina_default','precio_ponderado_manual')
order by column_name;

-- ── D. produccion_v1.sql — columna documento + índice único ───────
select 'D. columna documento' as chequeo, column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'produccion_diaria' and column_name = 'documento';

select 'D. indice unico' as chequeo, indexname
from pg_indexes
where schemaname = 'public' and tablename = 'produccion_diaria'
  and indexname = 'ux_prod_fecha_turno_maq_sku_doc';

-- ── E. produccion_seed_historico.sql — ¿cargó? ────────────────────
select 'E. seed historico' as chequeo,
       count(*) as lineas, count(distinct fecha) as dias,
       min(fecha) as desde, max(fecha) as hasta,
       to_char(sum(cantidad),'FM999,999,999') as unidades
from public.produccion_diaria where documento = 'SHEETS';

-- ── F. produccion_seed_historico.sql — catálogo poblado ───────────
select 'F. catalogo poblado' as chequeo,
       count(*) filter (where meta_12hrs is not null)              as con_meta,
       count(*) filter (where maquina_default is not null)         as con_maquina,
       count(*) filter (where precio_ponderado_manual is not null) as con_precio
from public.inventario;

-- ── G. ventas_financiero_v1.sql — tabla y RLS ─────────────────────
select 'G. ventas RLS' as chequeo, tablename, rowsecurity
from pg_tables where schemaname = 'public' and tablename = 'ventas';

select 'G. politicas ventas' as chequeo, policyname, cmd
from pg_policies where schemaname = 'public' and tablename = 'ventas'
order by policyname;

-- ── H. ventas_financiero_v1.sql — columnas y tipo de fecha ────────
select 'H. columnas ventas' as chequeo, column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'ventas'
  and column_name in ('fecha','familia','descripcion_familia','codigo_cliente')
order by column_name;

-- ── I. ventas_financiero_v1.sql — ¿hay datos importados? ──────────
select 'I. filas ventas' as chequeo,
       count(*) as filas, min(fecha) as desde, max(fecha) as hasta
from public.ventas;

-- ── J. rechazos_rls_fix.sql — RLS de rechazos (pendiente histórico) ─
select 'J. rechazos RLS' as chequeo, tablename, rowsecurity
from pg_tables where schemaname = 'public' and tablename = 'rechazos';
