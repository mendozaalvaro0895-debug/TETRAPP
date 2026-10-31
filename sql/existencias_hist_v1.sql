-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Historial diario de existencias (Bodega 2 y Bodega 7)
-- La importación diaria de bodega.html sobrescribe `inventario.existencia`
-- e `insumos_b7.existencia`, así que no quedaba rastro de cuánto bajó cada
-- SKU. Esta tabla guarda una FOTO por SKU y día (la última carga del día
-- gana) para medir el consumo de Bodega 7 = suma de las bajadas entre
-- fotos consecutivas (Inicio de bodega.html → "Bodega 7 (consumo)").
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.existencias_hist (
  fecha       date    not null,           -- día de la carga, hora Guatemala
  bodega      text    not null,           -- 'B2' · 'B7'
  sku         text    not null,
  existencia  numeric not null default 0,
  creado_en   timestamptz not null default now(),
  primary key (fecha, bodega, sku)
);

do $$ begin
  alter table public.existencias_hist
    add constraint existencias_hist_bodega_check check (bodega in ('B2','B7'));
exception when duplicate_object then null; end $$;

create index if not exists idx_exhist_bodega_fecha on public.existencias_hist(bodega, fecha desc);
create index if not exists idx_exhist_sku          on public.existencias_hist(sku);

-- RLS: lectura con sesión; escritura solo master (es quien importa el inventario)
alter table public.existencias_hist enable row level security;

drop policy if exists "exhist_lectura" on public.existencias_hist;
create policy "exhist_lectura" on public.existencias_hist
  for select to authenticated using (true);

drop policy if exists "exhist_inserta_master" on public.existencias_hist;
create policy "exhist_inserta_master" on public.existencias_hist
  for insert to authenticated with check (public.es_master());

drop policy if exists "exhist_actualiza_master" on public.existencias_hist;
create policy "exhist_actualiza_master" on public.existencias_hist
  for update to authenticated using (public.es_master()) with check (public.es_master());

drop policy if exists "exhist_borra_master" on public.existencias_hist;
create policy "exhist_borra_master" on public.existencias_hist
  for delete to authenticated using (public.es_master());

revoke all on public.existencias_hist from anon;
grant select, insert, update, delete on public.existencias_hist to authenticated;

-- Foto inicial con la existencia actual (las importaciones de B2 y B7 del
-- 31-oct-2026 ya se habían hecho al crear la tabla). No pisa una foto existente.
insert into public.existencias_hist (fecha, bodega, sku, existencia)
select (now() at time zone 'America/Guatemala')::date, 'B7', sku, coalesce(existencia, 0)
from public.insumos_b7 where sku is not null
on conflict do nothing;

insert into public.existencias_hist (fecha, bodega, sku, existencia)
select (now() at time zone 'America/Guatemala')::date, 'B2', sku, coalesce(existencia, 0)
from public.inventario where sku is not null and coalesce(bodega, 'B2') = 'B2'
on conflict do nothing;

-- Consumo por SKU desde p_desde: compara cada foto con la anterior del mismo SKU.
-- Bajadas = consumo, subidas = ingresos. Incluye como punto de partida la última
-- foto ANTERIOR a p_desde para no perder la bajada del primer día del período.
-- fotos/primera/ultima son de la bodega completa (iguales en todas las filas).
create or replace function public.consumo_existencias(p_bodega text, p_desde date)
returns table (sku text, consumo numeric, ingresos numeric, dias_baja int,
               fotos int, primera date, ultima date)
language sql stable security invoker set search_path = public as $$
  with base as (
    select coalesce(max(fecha), p_desde) as f0
    from existencias_hist where bodega = p_bodega and fecha < p_desde
  ),
  h as (
    select e.sku, e.fecha, e.existencia,
           lag(e.existencia) over (partition by e.sku order by e.fecha) as prev
    from existencias_hist e, base
    where e.bodega = p_bodega and e.fecha >= base.f0
  ),
  f as (
    select count(distinct e.fecha)::int as fotos, min(e.fecha) as primera, max(e.fecha) as ultima
    from existencias_hist e, base
    where e.bodega = p_bodega and e.fecha >= base.f0
  )
  select h.sku,
         sum(greatest(h.prev - h.existencia, 0)),
         sum(greatest(h.existencia - h.prev, 0)),
         (count(*) filter (where h.existencia < h.prev))::int,
         f.fotos, f.primera, f.ultima
  from h, f
  where h.prev is not null
  group by h.sku, f.fotos, f.primera, f.ultima
  having sum(abs(h.existencia - h.prev)) > 0
  union all
  -- fila sin SKU solo para informar cuántas fotos hay cuando todavía no hay cambios
  select null, 0, 0, 0, f.fotos, f.primera, f.ultima from f
$$;

revoke all on function public.consumo_existencias(text, date) from anon;
grant execute on function public.consumo_existencias(text, date) to authenticated;

notify pgrst, 'reload schema';

select bodega, fecha, count(*) from public.existencias_hist group by 1, 2 order by 1, 2;
