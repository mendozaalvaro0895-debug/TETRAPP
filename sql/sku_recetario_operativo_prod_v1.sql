-- Abre escritura del Recetario (sku_recetas, sku_receta_partes, sku_especificaciones)
-- al rol operativo_prod, además de master. Pedido por Álvaro sep/2026: el personal de
-- Producción entra por produccion.html (su propia pantalla operativa) y necesita poder
-- capturar la ficha técnica (Material/Colorante/Peso/Ciclo) y el resto del Recetario ahí
-- mismo, sin depender de que un master lo haga. Mismo alcance que el resto de Recetario
-- (fotos, partes, todas las áreas) — no se limita solo a la sección de Producción.
--
-- Reemplaza las policies insert/update/delete "solo master" por "master O operativo_prod"
-- en las 3 tablas. La policy de lectura no cambia (ya era para cualquier rol autenticado).

-- ── sku_recetas ──────────────────────────────────────────────────────────
drop policy if exists insert_master on public.sku_recetas;
drop policy if exists update_master on public.sku_recetas;
drop policy if exists delete_master on public.sku_recetas;

create policy insert_master_o_prod on public.sku_recetas
  for insert to authenticated
  with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy update_master_o_prod on public.sku_recetas
  for update to authenticated
  using (public.es_master() or public.rol_actual() = 'operativo_prod')
  with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy delete_master_o_prod on public.sku_recetas
  for delete to authenticated
  using (public.es_master() or public.rol_actual() = 'operativo_prod');

-- ── sku_receta_partes ────────────────────────────────────────────────────
drop policy if exists insert_master on public.sku_receta_partes;
drop policy if exists update_master on public.sku_receta_partes;
drop policy if exists delete_master on public.sku_receta_partes;

create policy insert_master_o_prod on public.sku_receta_partes
  for insert to authenticated
  with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy update_master_o_prod on public.sku_receta_partes
  for update to authenticated
  using (public.es_master() or public.rol_actual() = 'operativo_prod')
  with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy delete_master_o_prod on public.sku_receta_partes
  for delete to authenticated
  using (public.es_master() or public.rol_actual() = 'operativo_prod');

-- ── sku_especificaciones ─────────────────────────────────────────────────
drop policy if exists insert_master on public.sku_especificaciones;
drop policy if exists update_master on public.sku_especificaciones;
drop policy if exists delete_master on public.sku_especificaciones;

create policy insert_master_o_prod on public.sku_especificaciones
  for insert to authenticated
  with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy update_master_o_prod on public.sku_especificaciones
  for update to authenticated
  using (public.es_master() or public.rol_actual() = 'operativo_prod')
  with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy delete_master_o_prod on public.sku_especificaciones
  for delete to authenticated
  using (public.es_master() or public.rol_actual() = 'operativo_prod');
