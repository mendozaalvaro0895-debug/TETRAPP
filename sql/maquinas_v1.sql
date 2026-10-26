-- ════════════════════════════════════════════════════════════
-- Tabla `maquinas` — catálogo de máquinas de Producción (oct/2026)
-- Fuente: tabla que Álvaro compartió (marca/modelo/centro/estación) + la lista
-- de nombres que deben verse en el desplegable de Ingreso.
--
-- `produccion_diaria.maquina` (smallint) y `inventario.maquina_default` NO cambian:
-- siguen guardando el `id` de esta tabla. Las máquinas 1-5, 7 y 10 conservan su
-- id de siempre, así el historial sigue apuntando a la misma máquina.
--
-- ⚠️ Dobles (#6, #8, #9): antes eran UNA máquina cada una (ambas estaciones
-- sumadas). Ahora son E1 y E2 (ids 61/62, 81/82, 91/92). Los ids viejos 6/8/9 quedan
-- como "(histórico)", activa=false: solo sirven para ver/editar filas viejas, no
-- aparecen en los desplegables nuevos. No se adivina a qué estación pertenecía cada fila.
-- ⚠️ 11 y 12 existían en el código sin tipo ni nombre; quedan 'sin_definir' (inactivas) y el
-- reporte las sigue ignorando igual que antes.
-- ⚠️ "Vieja/Nueva": 200 → A5=Vieja, A6 (IU945)=Nueva · 120 → A5 (IU445)=Vieja, YIZUMI=Nueva
-- (confirmado por Álvaro). `marca`/`modelo` es mi separación de la columna MODELO de su
-- tabla ("KINGSWELL MACHINE" → marca; "YIZUMI A5" → marca YIZUMI + modelo A5; "IBM35" → modelo)
-- — corregir desde el dashboard si algo no cuadra.
-- Idempotente: se puede volver a correr (actualiza la metadata por id).
-- ════════════════════════════════════════════════════════════

create table if not exists public.maquinas (
  id         smallint primary key,
  nombre     text not null unique,   -- como se ve en los desplegables
  corto      text not null,          -- etiqueta corta (tablas/pills)
  tipo       text not null,          -- sopladora | iny_sopladora | inyectora | historico | sin_definir
  marca      text,
  modelo     text,
  centro     text,                   -- ÚNICA / 130 MM / 150 MM (sopladoras)
  estacion   text,                   -- ÚNICA / DOBLE / 4 ESTACIONES / 5 ESTACIONES
  referencia text,                   -- ej. IU945, IU445
  foto       text,                   -- nombre de archivo en img/maquinas/ (sin .png); null = 'maq'||id
  orden      smallint not null default 0,
  activa     boolean not null default true
);

alter table public.maquinas enable row level security;

drop policy if exists lectura_con_perfil on public.maquinas;
drop policy if exists insert_master on public.maquinas;
drop policy if exists update_master on public.maquinas;
drop policy if exists delete_master on public.maquinas;

create policy lectura_con_perfil on public.maquinas
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_master on public.maquinas
  for insert to authenticated with check (public.es_master());
create policy update_master on public.maquinas
  for update to authenticated using (public.es_master()) with check (public.es_master());
create policy delete_master on public.maquinas
  for delete to authenticated using (public.es_master());

revoke all on public.maquinas from anon;
grant select, insert, update, delete on public.maquinas to authenticated;

insert into public.maquinas (id, nombre, corto, tipo, marca, modelo, centro, estacion, referencia, foto, orden, activa) values
  -- Sopladoras (id, nombre, corto, tipo, marca, modelo, centro, estación, ref, foto, orden, activa)
  (1,  'SOPLADORA #1',   '#1',   'sopladora', 'KINGSWELL MACHINE', null, 'ÚNICA',  'ÚNICA', null, null,   1, true),
  (2,  'SOPLADORA #2',   '#2',   'sopladora', 'KINGSWELL MACHINE', null, '130 MM', 'ÚNICA', null, null,   2, true),
  (3,  'SOPLADORA #3',   '#3',   'sopladora', 'KINGSWELL MACHINE', null, '130 MM', 'ÚNICA', null, null,   3, true),
  (4,  'SOPLADORA #4',   '#4',   'sopladora', 'KINGSWELL MACHINE', null, '150 MM', 'ÚNICA', null, null,   4, true),
  (5,  'SOPLADORA #5',   '#5',   'sopladora', 'KINGSWELL MACHINE', null, '150 MM', 'ÚNICA', null, null,   5, true),
  (61, 'SOPLADORA #6E1', '#6E1', 'sopladora', 'DAWSON MACHINE',    null, '150 MM', 'DOBLE', null, 'maq6',  6, true),
  (62, 'SOPLADORA #6E2', '#6E2', 'sopladora', 'DAWSON MACHINE',    null, '150 MM', 'DOBLE', null, 'maq6',  7, true),
  (7,  'INY-SOPLADORA #7',  '#7',  'iny_sopladora', null, 'IBM35', null, '4 ESTACIONES', null, null,   8, true),
  (81, 'SOPLADORA #8E1', '#8E1', 'sopladora', 'DAWSON MACHINE',    null, '150 MM', 'DOBLE', null, 'maq8',  9, true),
  (82, 'SOPLADORA #8E2', '#8E2', 'sopladora', 'DAWSON MACHINE',    null, '150 MM', 'DOBLE', null, 'maq8', 10, true),
  (91, 'SOPLADORA #9E1', '#9E1', 'sopladora', 'DAWSON MACHINE',    null, '150 MM', 'DOBLE', null, 'maq9', 11, true),
  (92, 'SOPLADORA #9E2', '#9E2', 'sopladora', 'DAWSON MACHINE',    null, '150 MM', 'DOBLE', null, 'maq9', 12, true),
  (10, 'INY-SOPLADORA #10', '#10', 'iny_sopladora', null, 'IBM35', null, '5 ESTACIONES', null, null,  13, true),
  -- Inyectoras
  (21, 'INYECTORA 220',          'IY220',  'inyectora', 'HAICHEN', null, null, null, null,    null, 14, true),
  (22, 'INYECTORA 200 (Vieja)',  'IY200V', 'inyectora', 'YIZUMI',  'A5', null, null, null,    null, 15, true),
  (23, 'INYECTORA 200 (Nueva)',  'IY200N', 'inyectora', 'YIZUMI',  'A6', null, null, 'IU945', null, 16, true),
  (24, 'INYECTORA 150',          'IY150',  'inyectora', 'HAICHEN', null, null, null, null,    null, 17, true),
  (25, 'INYECTORA 120 (Vieja)',  'IY120V', 'inyectora', 'YIZUMI',  'A5', null, null, 'IU445', null, 18, true),
  (26, 'INYECTORA 120 (Nueva)',  'IY120N', 'inyectora', 'YIZUMI',  null, null, null, null,    null, 19, true),
  (27, 'INYECTORA 90',           'IY90',   'inyectora', 'HAICHEN', null, null, null, null,    null, 20, true),
  -- Históricos (solo para ver filas viejas)
  (6,  'SOPLADORA #6 (histórico)', '#6', 'historico', 'DAWSON MACHINE', null, '150 MM', 'DOBLE', null, 'maq6', 91, false),
  (8,  'SOPLADORA #8 (histórico)', '#8', 'historico', 'DAWSON MACHINE', null, '150 MM', 'DOBLE', null, 'maq8', 92, false),
  (9,  'SOPLADORA #9 (histórico)', '#9', 'historico', 'DAWSON MACHINE', null, '150 MM', 'DOBLE', null, 'maq9', 93, false),
  (11, 'MÁQUINA #11 (sin definir)', '#11', 'sin_definir', null, null, null, null, null, null, 98, false),
  (12, 'MÁQUINA #12 (sin definir)', '#12', 'sin_definir', null, null, null, null, null, null, 99, false)
on conflict (id) do update set
  nombre = excluded.nombre, corto = excluded.corto, tipo = excluded.tipo,
  marca = excluded.marca, modelo = excluded.modelo, centro = excluded.centro,
  estacion = excluded.estacion, referencia = excluded.referencia, foto = excluded.foto,
  orden = excluded.orden, activa = excluded.activa;
