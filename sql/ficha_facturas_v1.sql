-- ════════════════════════════════════════════════════════════════
-- ficha_facturas — confirmación MANUAL del cruce ficha ↔ facturación (nov/2026)
-- tapas.html cruza solo cada ficha con la tabla `ventas` (cliente + SKU + fecha). Esta tabla guarda las correcciones de master:
--   modo 'vinculada' → "esta línea de factura SÍ es de esta ficha" (confirmar una sugerencia o agregar una que el cruce no halló), con `und`
--   modo 'excluida'  → "esta línea de factura NO es de esta ficha" (el cruce no la vuelve a sugerir para ella)
-- La línea de factura se identifica por serie + docu + sku y NO por ventas.id: el importador de ventas.html reemplaza por rango de
-- fechas y los id cambian en cada reimportación.
-- Lectura: cualquiera con perfil · escribir: SOLO master.
-- Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.ficha_facturas (
  id           uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.solicitudes(id) on delete cascade,
  serie        text not null,
  docu         integer not null,
  sku          text not null,
  modo         text not null check (modo in ('vinculada', 'excluida')),
  und          integer check (und is null or und > 0),
  nota         text,
  creado_por   text,
  created_at   timestamptz not null default now(),
  constraint ficha_facturas_linea_uk unique (solicitud_id, serie, docu, sku),
  constraint ficha_facturas_und_ck check (modo <> 'vinculada' or und is not null)
);

create index if not exists idx_ficha_facturas_solicitud on public.ficha_facturas(solicitud_id);
create index if not exists idx_ficha_facturas_doc       on public.ficha_facturas(serie, docu, sku);

alter table public.ficha_facturas enable row level security;

drop policy if exists lectura_con_perfil on public.ficha_facturas;
drop policy if exists insert_master      on public.ficha_facturas;
drop policy if exists update_master      on public.ficha_facturas;
drop policy if exists delete_master      on public.ficha_facturas;

create policy lectura_con_perfil on public.ficha_facturas
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_master on public.ficha_facturas
  for insert to authenticated with check (public.rol_actual() = 'master');
create policy update_master on public.ficha_facturas
  for update to authenticated
  using (public.rol_actual() = 'master') with check (public.rol_actual() = 'master');
create policy delete_master on public.ficha_facturas
  for delete to authenticated using (public.rol_actual() = 'master');

revoke all on public.ficha_facturas from anon;
grant select, insert, update, delete on public.ficha_facturas to authenticated;

notify pgrst, 'reload schema';

-- Verificación: debe listar las 4 políticas
-- select policyname, cmd from pg_policies where tablename = 'ficha_facturas';
