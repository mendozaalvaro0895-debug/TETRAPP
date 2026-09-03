-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Operario por fila en produccion_diaria (Sopladoras)
--
-- Mismo patrón que la máquina: se asigna manualmente por fila al
-- cargar un screenshot/PDF, en la captura manual, y editable después
-- desde "✏️ Máquinas / Operarios". `operador_codigo` referencia
-- personal.codigo (igual que asistencia_diaria.operador_codigo en
-- Serigrafía) — NO es una FK a personal.id, es texto libre que debe
-- coincidir con el código de alguien con area='produccion' en
-- gestion.html.
--
-- El índice único pasa a incluir operador_codigo: si dos filas del
-- mismo día/turno/máquina/sku/documento tienen operarios DISTINTOS
-- (ej. relevo de almuerzo cargado como fila aparte), quedan como
-- registros separados en vez de fusionarse en una sola fila con la
-- cantidad sumada y el operario de la primera.
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.produccion_diaria
  add column if not exists operador_codigo text not null default '';

drop index if exists public.ux_prod_fecha_turno_maq_sku_doc;

create unique index if not exists ux_prod_fecha_turno_maq_sku_doc_op
  on public.produccion_diaria (fecha, turno, maquina, sku, documento, operador_codigo);

create index if not exists idx_prod_operador on public.produccion_diaria(operador_codigo);

notify pgrst, 'reload schema';

-- Verificación
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'produccion_diaria' and column_name = 'operador_codigo';

select indexname, indexdef from pg_indexes
where schemaname = 'public' and tablename = 'produccion_diaria';
