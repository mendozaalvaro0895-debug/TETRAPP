-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Movimientos de Insumos (Bodega 07 / Molino)
-- Destino de las requis MPI/MPS de SICAF, repartidas desde la Central
-- de Ingreso del index. Correr COMPLETO en Supabase Dashboard → SQL Editor.
-- Idempotente.
-- ════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. TABLA movimientos_insumos
-- ─────────────────────────────────────────────────────────────
create table if not exists public.movimientos_insumos (
  id              uuid primary key default gen_random_uuid(),
  area            text not null,                 -- 'bodega' · 'molino'
  tipo            text not null,                  -- 'ingreso' · 'salida'
  prefijo         text,                            -- prefijo original SICAF: MPI, MPS, etc.
  num_documento   text,                            -- ej. "MPI 655"
  fecha           date not null,                   -- fecha REAL de la transacción (no la de descarga del reporte)
  sku             text,                            -- código de inventario — cualquier SKU válido,
                                                     -- incluye "Molido" cuando aplique (a veces se vende)
  descripcion     text,
  cantidad        numeric not null default 0,
  costo_unitario  numeric,
  valor_total     numeric,
  referencia_sicaf text,                           -- campo "Referencia" de SICAF: texto libre, solo pista
  observaciones   text,
  created_at      timestamptz not null default now()
);

alter table public.movimientos_insumos
  add constraint movimientos_insumos_area_check
  check (area in ('bodega','molino'));

alter table public.movimientos_insumos
  add constraint movimientos_insumos_tipo_check
  check (tipo in ('ingreso','salida'));

create index if not exists idx_movinsumos_area_fecha on public.movimientos_insumos(area, fecha desc);
create index if not exists idx_movinsumos_sku         on public.movimientos_insumos(sku);
create index if not exists idx_movinsumos_documento    on public.movimientos_insumos(num_documento);

-- ─────────────────────────────────────────────────────────────
-- 2. RLS — lectura para cualquier autenticado (soporta rol visor de
--    solo lectura, igual que movimientos_materiales/produccion_diaria);
--    escritura master-only (todavía no existe rol operativo para
--    Bodega/Molino, a diferencia de rrhh_faltas que es master-only total
--    por ser dato sensible de RRHH — este no lo es)
-- ─────────────────────────────────────────────────────────────
alter table public.movimientos_insumos enable row level security;

drop policy if exists "movinsumos_lectura" on public.movimientos_insumos;
create policy "movinsumos_lectura" on public.movimientos_insumos
  for select to authenticated
  using (true);

drop policy if exists "movinsumos_escritura_master" on public.movimientos_insumos;
create policy "movinsumos_escritura_master" on public.movimientos_insumos
  for insert to authenticated
  with check (public.es_master());

drop policy if exists "movinsumos_actualiza_master" on public.movimientos_insumos;
create policy "movinsumos_actualiza_master" on public.movimientos_insumos
  for update to authenticated
  using (public.es_master())
  with check (public.es_master());

drop policy if exists "movinsumos_borra_master" on public.movimientos_insumos;
create policy "movinsumos_borra_master" on public.movimientos_insumos
  for delete to authenticated
  using (public.es_master());

revoke all on public.movimientos_insumos from anon;
grant select, insert, update, delete on public.movimientos_insumos to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3. Refrescar caché PostgREST
-- ─────────────────────────────────────────────────────────────
notify pgrst, 'reload schema';

-- ─────────────────────────────────────────────────────────────
-- 4. Verificación
-- ─────────────────────────────────────────────────────────────
select tablename, rowsecurity from pg_tables
where schemaname = 'public' and tablename = 'movimientos_insumos';

select count(*) as filas_iniciales from public.movimientos_insumos;
