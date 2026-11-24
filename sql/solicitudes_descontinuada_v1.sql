-- DESCONTINUAR fichas (nov/2026): master da por cerrada una ficha ya entregada (o que ya no se va a producir) para que deje de
-- pedir componentes en las alertas de Bajo Stock. La ficha pasa a estado 'lista' SIN marca de completada de Tapas (no queda
-- visible en Fichas de Trabajo) y estas dos columnas dicen quién y cuándo; "Reactivar" las limpia y la devuelve a nueva/parcial.
alter table public.solicitudes
  add column if not exists descontinuada_por text,
  add column if not exists descontinuada_en timestamptz;
