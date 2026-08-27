-- ════════════════════════════════════════════════════════════════
-- sku_especificaciones — ficha técnica extensible por SKU y área
-- Fase 2 del Recetario unificado (Tapas / Serigrafía / Producción)
-- Correr en Supabase Dashboard → SQL Editor
-- ════════════════════════════════════════════════════════════════

create table if not exists public.sku_especificaciones (
  id              bigserial primary key,
  sku             text not null,
  area            text not null check (area in ('tapas','serigrafia','produccion')),
  campo           text not null,
  valor           text,
  nota            text,
  actualizado_por text,
  actualizado_en  timestamptz default now(),
  unique (sku, area, campo)
);

create index if not exists idx_sku_especificaciones_sku on public.sku_especificaciones(sku);

-- actualizado_en siempre lo pone el servidor (evita líos de zona horaria del
-- cliente) — se actualiza solo en cada insert/update, sin que el front la mande.
create or replace function public.set_actualizado_en()
returns trigger language plpgsql as $$
begin
  new.actualizado_en = now();
  return new;
end;
$$;

drop trigger if exists trg_sku_especificaciones_actualizado_en on public.sku_especificaciones;
create trigger trg_sku_especificaciones_actualizado_en
before insert or update on public.sku_especificaciones
for each row execute function public.set_actualizado_en();

-- ── RLS — mismo criterio que sku_recetas: lectura con perfil, escritura solo
--    master por ahora. Cuando cada área tenga su propia pantalla operativa
--    (ej. registro-serigrafia.html), se puede abrir escritura por rol específico
--    con una policy adicional que compare rol_actual() contra la columna area.
alter table public.sku_especificaciones enable row level security;

drop policy if exists lectura_con_perfil on public.sku_especificaciones;
drop policy if exists insert_master       on public.sku_especificaciones;
drop policy if exists update_master       on public.sku_especificaciones;
drop policy if exists delete_master       on public.sku_especificaciones;

create policy lectura_con_perfil on public.sku_especificaciones
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_master on public.sku_especificaciones
  for insert to authenticated with check (public.es_master());
create policy update_master on public.sku_especificaciones
  for update to authenticated using (public.es_master()) with check (public.es_master());
create policy delete_master on public.sku_especificaciones
  for delete to authenticated using (public.es_master());

revoke all on public.sku_especificaciones from anon;
grant select, insert, update, delete on public.sku_especificaciones to authenticated;
grant usage, select on sequence public.sku_especificaciones_id_seq to authenticated;

-- Verificar
select column_name, data_type
from information_schema.columns
where table_name = 'sku_especificaciones'
order by ordinal_position;
