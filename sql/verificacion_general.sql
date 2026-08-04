-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Verificación general de SQLs corridos
-- Pega este bloque completo en Supabase Dashboard → SQL Editor → Run
--
-- Es UNA sola consulta (UNION ALL) para que el editor muestre todas
-- las filas de una vez — si se corre como varios `select` sueltos,
-- Supabase solo enseña el resultado del último.
-- No modifica nada, solo lee.
-- ════════════════════════════════════════════════════════════════

select 1 as orden, 'A. produccion_diaria existe + RLS' as chequeo,
       tablename as detalle_1, rowsecurity::text as detalle_2, null as detalle_3
from pg_tables where schemaname = 'public' and tablename = 'produccion_diaria'

union all
select 2, 'B. politica: ' || policyname, cmd, roles::text, null
from pg_policies where schemaname = 'public' and tablename = 'produccion_diaria'

union all
select 3, 'C. columna inventario: ' || column_name, data_type, null, null
from information_schema.columns
where table_schema = 'public' and table_name = 'inventario'
  and column_name in ('meta_12hrs','maquina_default','precio_ponderado_manual')

union all
select 4, 'D. columna documento', data_type, column_default, null
from information_schema.columns
where table_schema = 'public' and table_name = 'produccion_diaria' and column_name = 'documento'

union all
select 5, 'D. indice unico con documento', indexname, null, null
from pg_indexes
where schemaname = 'public' and tablename = 'produccion_diaria'
  and indexname = 'ux_prod_fecha_turno_maq_sku_doc'

union all
select 6, 'E. seed historico (SHEETS)',
       count(*)::text || ' lineas, ' || count(distinct fecha)::text || ' dias',
       min(fecha)::text || ' -> ' || max(fecha)::text,
       to_char(sum(cantidad),'FM999,999,999') || ' unidades'
from public.produccion_diaria where documento = 'SHEETS'

union all
select 7, 'F. catalogo poblado',
       'con_meta=' || count(*) filter (where meta_12hrs is not null)::text,
       'con_maquina=' || count(*) filter (where maquina_default is not null)::text,
       'con_precio=' || count(*) filter (where precio_ponderado_manual is not null)::text
from public.inventario

union all
select 8, 'G. ventas existe + RLS', tablename, rowsecurity::text, null
from pg_tables where schemaname = 'public' and tablename = 'ventas'

union all
select 9, 'G. politica ventas: ' || policyname, cmd, roles::text, null
from pg_policies where schemaname = 'public' and tablename = 'ventas'

union all
select 10, 'H. columna ventas: ' || column_name, data_type, null, null
from information_schema.columns
where table_schema = 'public' and table_name = 'ventas'
  and column_name in ('fecha','familia','descripcion_familia','codigo_cliente')

union all
select 11, 'I. filas en ventas',
       count(*)::text, min(fecha)::text, max(fecha)::text
from public.ventas

union all
select 12, 'J. rechazos existe + RLS', tablename, rowsecurity::text, null
from pg_tables where schemaname = 'public' and tablename = 'rechazos'

order by orden, chequeo;
