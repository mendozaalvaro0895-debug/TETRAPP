-- ════════════════════════════════════════════════════════════
-- Tabla `moldes` — catálogo de moldes de Producción (Sopladoras)
-- Alimenta el autocompletado de "Molde" y "Cavidades" en el Recetario
-- (produccion.html → área Producción). Lista inicial importada de
-- "MOLDES Y CICLOS - SEP 2026.xlsx" (Álvaro, sep/2026) — 88 moldes
-- únicos (la hoja traía 90 filas, 2 duplicadas exactas).
-- ⚠️ Fila 'TARRO BARE 600 ML': el nombre en el Excel original tenía un
-- carácter ilegible/corrupto ('TARRO BAR? 600 ML') — se dejó como
-- mejor lectura razonable, Álvaro puede corregirlo desde la app si
-- el nombre real es otro (ej. con tilde: BARÉ).
-- Se puede seguir agregando moldes nuevos directamente desde la app
-- (Recetario → especificaciones de Producción → campo Molde), sin
-- volver a correr este script — el alta es un simple insert desde ahí.
-- ════════════════════════════════════════════════════════════

create table if not exists public.moldes (
  id bigint generated always as identity primary key,
  nombre text not null unique,
  cavidades int,
  ciclo_seg numeric,
  creado_por text,
  creado_en timestamptz not null default now()
);

alter table public.moldes enable row level security;

drop policy if exists lectura_con_perfil on public.moldes;
drop policy if exists insert_master_o_prod on public.moldes;
drop policy if exists update_master on public.moldes;
drop policy if exists delete_master on public.moldes;

create policy lectura_con_perfil on public.moldes
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_master_o_prod on public.moldes
  for insert to authenticated
  with check (public.es_master() or public.rol_actual() = 'operativo_prod');
create policy update_master on public.moldes
  for update to authenticated using (public.es_master()) with check (public.es_master());
create policy delete_master on public.moldes
  for delete to authenticated using (public.es_master());

revoke all on public.moldes from anon;
grant select, insert, update, delete on public.moldes to authenticated;

-- Realtime opcional — mismo patrón que produccion_diaria/registro_tiros_serig,
-- por si en el futuro se quiere ver el catálogo actualizarse en vivo entre
-- equipos. No es indispensable para el autocompletado (se recarga al abrir
-- el Recetario), se deja comentado por ahora:
-- alter publication supabase_realtime add table public.moldes;

-- ── Datos iniciales (88 moldes, sep/2026) ──────────────────────
insert into public.moldes (nombre, cavidades, ciclo_seg) values
  ('240 LINE BEBE CAREFUR', 2, 20),
  ('BABY SHAMPOO 220', 1, 8),
  ('BARRILITO 300 ML', 2, 20),
  ('BASE 33', 4, 20),
  ('BASE PUSH PULL', 8, 20),
  ('BIO BEIGE', 2, 20),
  ('BULLET 200 ML/CUELLO28/324', 2, 18),
  ('BULLET 400 ML', 2, 20),
  ('BULLET 640 ML', 2, 18),
  ('CAREFUR', 2, 20),
  ('CILINDRO 120 ML', 1, 13),
  ('CILINDRO 240 ML CUELLO 28/24', 2, 10),
  ('CILINDRO 4 ONZ', 2, 13),
  ('CILINDRO 400 ML BULLET', 2, 20),
  ('CILINDRO 500 ML', 1, 13),
  ('CILINDRO 500 ML CHUBBY', 2, 20),
  ('CILINDRO 500 ML CUELLO LARGO 28', 2, 20),
  ('COLA DE RATON', 2, 15),
  ('CONTRAPA 28/410', 8, 15),
  ('CONTRATAPA 33', 6, 21.6),
  ('JOHNSON', 1, 13),
  ('KERA CLEIRE 60 ML', 2, 12),
  ('KONTROL 100 ML JR', 2, 20),
  ('LITRO CUELLO 28', 4, 24),
  ('LITRO CUELLO 33', 4, 24),
  ('LITRO PVC NUEVO', 1, 14),
  ('LIVE 200 ML JR', 2, 20),
  ('LIVE 500 ML', 2, 20),
  ('LUNA 400 ML', 2, 20),
  ('LUNA 780 ML', 2, 24),
  ('MANZANITA', 2, 16),
  ('MEDIO BARRILITO', null, null),
  ('MEDIO LITRO GORDO 33', 1, 12.1),
  ('OCTAGONAL JABONERO', 1, 13),
  ('OVAL 2.2', 1, 12),
  ('OVAL KONTROL 400 ML', 2, 24),
  ('PASTILLERO AMERICAN NATURAL', 1, 14),
  ('PASTILLERO CUADRADO', 1, 14),
  ('PASTILLERO REDONDO FARMALLA', 2, 13),
  ('PASTILLERO SCENTIA', 2, 17),
  ('PEINE', null, null),
  ('PIRAMIDAL', 1, 12),
  ('REGIO 4 ONZAS', 1, 13),
  ('ROLL ON CABEZON', 5, 22.5),
  ('ROLL ON GRANDE', 5, 22.5),
  ('ROLL ON LISO', 5, 3.618),
  ('ROLL ON MINI', 5, 18),
  ('ROLL ON OVAL JR', 4, 14.4),
  ('SALOE 750', 2, 24),
  ('SALONS INTENS 750', 2, 20),
  ('SEDAL OVAL 300 ML', 2, 20),
  ('SEDAL OVAL JR 80 ML', 2, 17),
  ('TALCO 120 ML', 2, 20),
  ('TALCO 240 ML', 2, 20),
  ('TALCO 60 ML', 2, 12),
  ('TAPA 20/415', 6, 22.5),
  ('TAPA 28/410', 4, 20),
  ('TAPA 90 "', 4, 15),
  ('TAPA 93', 4, 20),
  ('TAPA BASE DOMO 55"', 2, 20),
  ('TAPA ELIPTICA', 8, 20),
  ('TAPA FORZA 100 MM LISA', 4, 16),
  ('TAPA FORZA 70 MM J&J', 4, 12),
  ('TAPA FORZA 70 MM VESA', 4, 12),
  ('TAPA GENERICA', 4, 24),
  ('TAPA ROLL MINI', null, null),
  ('TAPA ROLL ON CABEZON', 2, 20),
  ('TAPA ROLL ON GRANDE', null, null),
  ('TAPA ROLLL ON JR', 2, 16),
  ('TARO WARNER BROSS', 2, 20),
  ('TARRO 1.3', 1, 14),
  ('TARRO 320', 2, 20),
  ('TARRO 350 ML', 1, 10),
  ('TARRO 9 ONZ OCTAGONAL', 2, 24),
  ('TARRO 908', 2, 21.8),
  ('TARRO BARE 600 ML', 2, 24),
  ('TARRO CHEMER 250', 2, 18),
  ('TARRO CREMERO 150 VIXY', 2, 16),
  ('TARRO DIAMANTE VIEJO', 2, 16),
  ('TARRO FORZA 1000 REDONDO', 2, 24),
  ('TARRO FORZA 150', 2, 16),
  ('TARRO FORZA 300 REDONDO', 2, 16),
  ('TARRO NEVADO', 2, 16),
  ('TARRO SKALA 1000', 1, 12),
  ('TARRO VASELINA 100 GMS', 2, 22.5),
  ('TARRO VASELINA 56 GMS', 2, 16),
  ('TARRO VESA 450 ML JR', 2, 20),
  ('TARRO VESA GRANDE 1K', 2, 22)
on conflict (nombre) do nothing;
