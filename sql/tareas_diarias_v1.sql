-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Guía de alimentación diaria (index.html)
--
-- Registra tareas obligatorias del día que NO se pueden deducir de otra
-- tabla. Hoy:
--   · inventario_am / inventario_pm — las escribe bodega.html al importar
--     el Excel de existencias (antes solo vivía en localStorage, por eso
--     solo se veía desde el mismo equipo).
--   · omitir_guia — master elige "Omitir hoy" en index.html y deja motivo.
-- Las requis, ventas y asistencia se verifican contra sus propias tablas
-- (movimientos_materiales, entregas_serig, ventas, asistencia_diaria).
--
-- Lectura: cualquier autenticado (index.html la consulta con cualquier rol).
-- Escritura: solo master.
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.tareas_diarias (
  id          uuid primary key default gen_random_uuid(),
  fecha       date not null,
  tarea       text not null
              check (tarea in ('inventario_am', 'inventario_pm', 'omitir_guia')),
  estado      text not null default 'hecha'
              check (estado in ('hecha', 'omitida')),
  motivo      text,
  usuario     text,
  created_at  timestamptz not null default now()
);

create index if not exists tareas_diarias_fecha_idx
  on public.tareas_diarias (fecha, tarea);

alter table public.tareas_diarias enable row level security;

drop policy if exists "tareasdiarias_lectura" on public.tareas_diarias;
create policy "tareasdiarias_lectura" on public.tareas_diarias
  for select to authenticated
  using (true);

drop policy if exists "tareasdiarias_escritura_master" on public.tareas_diarias;
create policy "tareasdiarias_escritura_master" on public.tareas_diarias
  for insert to authenticated
  with check (public.es_master());

drop policy if exists "tareasdiarias_borra_master" on public.tareas_diarias;
create policy "tareasdiarias_borra_master" on public.tareas_diarias
  for delete to authenticated
  using (public.es_master());

revoke all on public.tareas_diarias from anon;
grant select, insert, delete on public.tareas_diarias to authenticated;

notify pgrst, 'reload schema';
