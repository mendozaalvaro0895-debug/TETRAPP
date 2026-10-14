-- ════════════════════════════════════════════════════════════════
-- tapas_lotes — pedidos / parciales que Tapas marca "en proceso"
-- Pestaña "Pedidos" de registro-tapas.html (sesión tapas@tetrapp.app).
-- Una ficha (solicitud) puede tener varios lotes: el cliente deja una OC grande
-- y la va pidiendo por partes (ej. 3,000 de una ficha de 5,000). La supervisora
-- u operarios marcan cuántas unidades están trabajando; el lote se da por
-- completado SOLO al registrar el ingreso PT vinculado a la ficha (movimientos_materiales
-- tipo 'entrada_pt'), así que aquí no se guarda "completado": se calcula.
-- Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.tapas_lotes (
  id           uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.solicitudes(id) on delete cascade,
  cantidad     integer not null check (cantidad > 0),
  marcado_por  text,
  marcado_en   timestamptz not null default now()
);

create index if not exists idx_tapas_lotes_solicitud on public.tapas_lotes(solicitud_id);

alter table public.tapas_lotes enable row level security;

drop policy if exists lectura_con_perfil on public.tapas_lotes;
drop policy if exists insert_tapas       on public.tapas_lotes;
drop policy if exists update_tapas       on public.tapas_lotes;
drop policy if exists delete_tapas       on public.tapas_lotes;

create policy lectura_con_perfil on public.tapas_lotes
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_tapas on public.tapas_lotes
  for insert to authenticated
  with check (public.rol_actual() in ('master','supervisor_tapas','operativo'));
create policy update_tapas on public.tapas_lotes
  for update to authenticated
  using (public.rol_actual() in ('master','supervisor_tapas','operativo'))
  with check (public.rol_actual() in ('master','supervisor_tapas','operativo'));
create policy delete_tapas on public.tapas_lotes
  for delete to authenticated
  using (public.rol_actual() in ('master','supervisor_tapas','operativo'));

revoke all on public.tapas_lotes from anon;
grant select, insert, update, delete on public.tapas_lotes to authenticated;

notify pgrst, 'reload schema';

-- Verificación: debe listar las 4 políticas
-- select policyname, cmd from pg_policies where tablename = 'tapas_lotes';
