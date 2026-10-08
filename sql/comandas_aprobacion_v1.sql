-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Aprobación de comandas de Tapas (pendiente / aprobada / rechazada)
--
-- Cada ingreso que hace el personal (formulario de registro-tapas.html y bot de
-- WhatsApp) nace PENDIENTE y solo cuenta en los termómetros, Productividad y el
-- Dashboard cuando Álvaro lo APRUEBA desde comandas.html. Lo que carga el master
-- desde comandas.html (formulario manual e importador de reportes) nace aprobado.
--
-- Truco del backfill: la columna se crea con default 'aprobada' para que TODO lo
-- que ya existe quede aprobado, y recién después se cambia el default a 'pendiente'
-- para lo nuevo. (Si se creara con default 'pendiente', todo el histórico quedaría
-- pendiente y los termómetros se vaciarían.)
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- Escritura de estado: solo master (política update_master ya existente en comandas).
-- ════════════════════════════════════════════════════════════════

alter table public.comandas add column if not exists estado_aprobacion text not null default 'aprobada';
alter table public.comandas add column if not exists aprobado_por      text;
alter table public.comandas add column if not exists aprobado_en       timestamptz;
alter table public.comandas add column if not exists motivo_rechazo    text;

alter table public.comandas drop constraint if exists comandas_estado_aprobacion_check;
alter table public.comandas
  add constraint comandas_estado_aprobacion_check
  check (estado_aprobacion in ('pendiente', 'aprobada', 'rechazada'));

-- Lo NUEVO que no diga nada (operarios, bot de WhatsApp) queda pendiente
alter table public.comandas alter column estado_aprobacion set default 'pendiente';

create index if not exists comandas_estado_aprobacion_idx on public.comandas (estado_aprobacion);

notify pgrst, 'reload schema';

-- Verificación 1: las 4 columnas
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'comandas'
  and column_name in ('estado_aprobacion', 'aprobado_por', 'aprobado_en', 'motivo_rechazo')
order by column_name;

-- Verificación 2: todo lo existente debe salir 'aprobada'
select estado_aprobacion, count(*) from public.comandas group by 1;
