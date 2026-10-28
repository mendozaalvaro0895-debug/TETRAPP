-- ════════════════════════════════════════════════════════════════
-- tapas_ficha_comentarios — comentarios de la supervisora sobre una ficha de Tapas
-- Pestaña "Pedidos" de registro-tapas.html (rol supervisor_tapas / operativo): "💬 Agregar comentario" en cada
-- ficha para dejar una solicitud de cambio u observación. El master los ve en tapas.html (chip "💬 N" y ventana
-- de la ficha) y los marca como atendidos.
-- Por qué una tabla aparte: el rol de Tapas NO puede escribir en `solicitudes` (ni en su columna `notas`).
-- Lectura: cualquiera con perfil · Agregar: master, supervisor_tapas, operativo · Marcar atendido / borrar: SOLO master.
-- Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.tapas_ficha_comentarios (
  id           uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.solicitudes(id) on delete cascade,
  comentario   text not null check (length(btrim(comentario)) > 0),
  autor        text,
  estado       text not null default 'pendiente' check (estado in ('pendiente', 'atendido')),
  atendido_por text,
  atendido_en  timestamptz,
  created_at   timestamptz not null default now()
);

create index if not exists idx_tapas_ficha_coment_solicitud on public.tapas_ficha_comentarios(solicitud_id);
create index if not exists idx_tapas_ficha_coment_estado    on public.tapas_ficha_comentarios(estado);

alter table public.tapas_ficha_comentarios enable row level security;

drop policy if exists lectura_con_perfil on public.tapas_ficha_comentarios;
drop policy if exists insert_tapas       on public.tapas_ficha_comentarios;
drop policy if exists update_master      on public.tapas_ficha_comentarios;
drop policy if exists delete_master      on public.tapas_ficha_comentarios;

create policy lectura_con_perfil on public.tapas_ficha_comentarios
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_tapas on public.tapas_ficha_comentarios
  for insert to authenticated
  with check (public.rol_actual() in ('master', 'supervisor_tapas', 'operativo'));
create policy update_master on public.tapas_ficha_comentarios
  for update to authenticated
  using (public.rol_actual() = 'master')
  with check (public.rol_actual() = 'master');
create policy delete_master on public.tapas_ficha_comentarios
  for delete to authenticated
  using (public.rol_actual() = 'master');

revoke all on public.tapas_ficha_comentarios from anon;
grant select, insert, update, delete on public.tapas_ficha_comentarios to authenticated;

notify pgrst, 'reload schema';

-- Verificación: debe listar las 4 políticas
-- select policyname, cmd from pg_policies where tablename = 'tapas_ficha_comentarios';
