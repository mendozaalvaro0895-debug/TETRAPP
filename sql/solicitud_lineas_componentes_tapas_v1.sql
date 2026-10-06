-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Componentes de la ficha de Tapas (Base, Contratapa, Liner, Banda)
--
-- El formulario "Nueva solicitud · Tapas" (tapas.html) guarda el SKU de cada componente
-- en la línea del pedido. `sku_base` ya existe (venía de "SKU materia prima"); se agregan
-- las otras tres. Las alertas de bajo stock del Inicio de Tapas leen sku_base y
-- sku_contratapa. Sin correr esto, guardar una solicitud con Contratapa/Liner/Banda falla
-- (la ficha NO queda a medias: se borra y se avisa en pantalla).
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.solicitud_lineas add column if not exists sku_base       text;
alter table public.solicitud_lineas add column if not exists sku_contratapa text;
alter table public.solicitud_lineas add column if not exists sku_liner      text;
alter table public.solicitud_lineas add column if not exists sku_banda      text;

notify pgrst, 'reload schema';

-- Verificación: deben salir las 4 columnas
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'solicitud_lineas'
  and column_name in ('sku_base', 'sku_contratapa', 'sku_liner', 'sku_banda')
order by column_name;
