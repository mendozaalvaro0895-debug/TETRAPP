-- ════════════════════════════════════════════════════════════════
-- solicitudes.plazo_tipo — "Entregas parciales" (OC abierta) / "Pendiente" en lugar de una fecha límite
-- Tapas: hay clientes que dejan una OC grande abierta y van pidiendo por parciales, así que la ficha
-- no tiene UNA fecha límite. plazo_tipo = 'fecha' (default, usa fecha_limite) | 'parciales' | 'pendiente'.
-- En los dos últimos fecha_limite queda en null (por eso se quita el NOT NULL, si lo tenía).
-- Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

alter table public.solicitudes
  add column if not exists plazo_tipo text not null default 'fecha';

alter table public.solicitudes drop constraint if exists solicitudes_plazo_tipo_check;
alter table public.solicitudes
  add constraint solicitudes_plazo_tipo_check check (plazo_tipo in ('fecha', 'parciales', 'pendiente'));

alter table public.solicitudes alter column fecha_limite drop not null;

notify pgrst, 'reload schema';

-- Verificación:
-- select plazo_tipo, count(*) from public.solicitudes group by 1;
