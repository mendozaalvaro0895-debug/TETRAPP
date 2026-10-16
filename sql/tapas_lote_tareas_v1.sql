-- ════════════════════════════════════════════════════════════════
-- tapas_lote_tareas — qué operario inicia qué proceso en cada lote en proceso
-- Pestaña "Pedidos" de registro-tapas.html (sesión tapas@tetrapp.app).
-- Requiere sql/tapas_lotes_v1.sql (SQL pendiente #35) corrido ANTES.
-- Un lote (parcial o ficha completa) pasa por varios procesos (armado, liner,
-- flameado, impresión, encajado…): cada vez que alguien lo inicia se guarda una
-- fila aquí con el operario y el proceso. Historial útil también para Recetarios/ML
-- (quién hace qué, y en qué orden, para cada producto).
-- Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.tapas_lote_tareas (
  id              uuid primary key default gen_random_uuid(),
  lote_id         uuid not null references public.tapas_lotes(id) on delete cascade,
  proceso         text not null,
  operario_codigo text,
  operario_nombre text,
  iniciado_en     timestamptz not null default now()
);

create index if not exists idx_tapas_lote_tareas_lote on public.tapas_lote_tareas(lote_id);

alter table public.tapas_lote_tareas enable row level security;

drop policy if exists lectura_con_perfil on public.tapas_lote_tareas;
drop policy if exists insert_tapas       on public.tapas_lote_tareas;
drop policy if exists update_tapas       on public.tapas_lote_tareas;
drop policy if exists delete_tapas       on public.tapas_lote_tareas;

create policy lectura_con_perfil on public.tapas_lote_tareas
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_tapas on public.tapas_lote_tareas
  for insert to authenticated
  with check (public.rol_actual() in ('master','supervisor_tapas','operativo'));
create policy update_tapas on public.tapas_lote_tareas
  for update to authenticated
  using (public.rol_actual() in ('master','supervisor_tapas','operativo'))
  with check (public.rol_actual() in ('master','supervisor_tapas','operativo'));
create policy delete_tapas on public.tapas_lote_tareas
  for delete to authenticated
  using (public.rol_actual() in ('master','supervisor_tapas','operativo'));

revoke all on public.tapas_lote_tareas from anon;
grant select, insert, update, delete on public.tapas_lote_tareas to authenticated;

notify pgrst, 'reload schema';

-- Verificación: debe listar las 4 políticas
-- select policyname, cmd from pg_policies where tablename = 'tapas_lote_tareas';
