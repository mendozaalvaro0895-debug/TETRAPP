-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Planos de planta v1.0 (plano-nivel2.html)
-- Tabla nueva:
--   · planos   (una fila = una VERSIÓN guardada del plano de un nivel;
--               guardar nunca pisa la anterior)
-- Storage:
--   · bucket privado `planos` (modelo GLB del Nivel 1 hecho en SketchUp,
--     vista previa PNG de cada versión)
--
-- Es idempotente: se puede correr varias veces sin romper nada.
-- Patrón RLS (igual que mejoras_planta): es_master() escribe ·
--   rol_actual() IS NOT NULL lee.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.planos (
  id           uuid primary key default gen_random_uuid(),
  nivel        smallint not null check (nivel in (1, 2)),
  version      integer  not null,
  nombre       text     not null default 'Plano de planta',
  nota         text,
  datos        jsonb    not null,   -- JSON v2 del plano (formato "tetrapp-plano")
  modelo_path  text,                -- ruta en bucket `planos` del GLB importado (opcional)
  vista_path   text,                -- ruta en bucket `planos` de la vista previa PNG (opcional)
  n_elementos  integer,
  creado_por   uuid default auth.uid(),
  creado_en    timestamptz not null default now(),
  unique (nivel, version)
);

create index if not exists idx_planos_nivel_version on public.planos(nivel, version desc);

alter table public.planos enable row level security;

drop policy if exists planos_lectura       on public.planos;
drop policy if exists planos_insert_master on public.planos;
drop policy if exists planos_update_master on public.planos;
drop policy if exists planos_delete_master on public.planos;

create policy planos_lectura       on public.planos for select using (rol_actual() is not null);
create policy planos_insert_master on public.planos for insert with check (es_master());
create policy planos_update_master on public.planos for update using (es_master()) with check (es_master());
create policy planos_delete_master on public.planos for delete using (es_master());

grant select, insert, update, delete on public.planos to authenticated;

-- ── Storage ──────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('planos', 'planos', false)
on conflict (id) do nothing;

drop policy if exists planos_storage_lectura on storage.objects;
drop policy if exists planos_storage_insert  on storage.objects;
drop policy if exists planos_storage_update  on storage.objects;
drop policy if exists planos_storage_delete  on storage.objects;

create policy planos_storage_lectura on storage.objects for select
  using (bucket_id = 'planos' and rol_actual() is not null);
create policy planos_storage_insert on storage.objects for insert
  with check (bucket_id = 'planos' and es_master());
create policy planos_storage_update on storage.objects for update
  using (bucket_id = 'planos' and es_master()) with check (bucket_id = 'planos' and es_master());
create policy planos_storage_delete on storage.objects for delete
  using (bucket_id = 'planos' and es_master());

-- ── v2 (oct/2026): copia de trabajo compartida ──────────────────
-- La fila version = 0 de cada nivel es la COPIA DE TRABAJO que ve cualquier equipo
-- (el plano la sobrescribe solo con cada cambio). version >= 1 son las versiones guardadas.
alter table public.planos add column if not exists actualizado_en timestamptz not null default now();
