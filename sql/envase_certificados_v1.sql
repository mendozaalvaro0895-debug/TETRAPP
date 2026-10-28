-- ════════════════════════════════════════════════════════════
-- Tabla `envase_certificados` — fichas de calidad de cada envase (oct/2026)
-- Fuente: "CERTIFICADOS PRO..xlsx" (Google Drive de servicioalcliente@tetraplastic.com),
-- 31 certificados de calidad, uno por modelo de envase (NO por SKU: un modelo tiene varios
-- SKU por color/cliente). El vínculo con `inventario.sku` va en `skus` (text[]) y se marca
-- `skus_confirmado=false` hasta que alguien lo revise.
--
-- Valores del certificado: RESULTADO / MINIMO / MAXIMO por característica (mm y g).
-- `unidades_tarima` se calcula (unidades por bolsa × bolsas por tarima).
-- ⚠️ Dos celdas del Excel tienen errores evidentes y se guardaron en NULL (el original queda en
--   `notas_datos`): ancho mín. de SALOE 750 (11.80) y Ø ext. boquilla máx. de BABY SHAMPOO (24.70).
-- ⚠️ Los certificados NO traen lote/correlativo/fecha salvo NUTRIDERM 12 OZ.
-- Idempotente: se puede volver a correr (upsert por `clave`).
-- ════════════════════════════════════════════════════════════

create table if not exists public.envase_certificados (
  id              bigint generated always as identity primary key,
  clave           text not null unique,        -- slug estable
  nombre_hoja     text not null,               -- nombre de la pestaña del Excel
  nombre_comercial text not null,              -- "Nombre comercial del producto" del certificado
  capacidad_ml    numeric,
  material        text not null default 'POLIETILENO (HDPE) 100% VIRGEN',
  color           text,
  peso_g numeric, peso_min_g numeric, peso_max_g numeric,
  altura_mm numeric, altura_min_mm numeric, altura_max_mm numeric,
  cuello_mm numeric, cuello_min_mm numeric, cuello_max_mm numeric,
  boq_int_mm numeric, boq_int_min_mm numeric, boq_int_max_mm numeric,
  boq_ext_mm numeric, boq_ext_min_mm numeric, boq_ext_max_mm numeric,
  ancho_mm numeric, ancho_min_mm numeric, ancho_max_mm numeric,
  unidades_bolsa  integer,
  bolsas_tarima   integer,
  unidades_tarima integer generated always as (unidades_bolsa * bolsas_tarima) stored,
  prueba_fuga     text not null default 'CUMPLE - ensayo de hermeticidad con H2O sin fugas',
  prueba_impacto  text not null default 'CUMPLE - ensayo de impacto, 2 caídas libres, envases sin fisuras',
  caida_m         numeric not null default 1.5,
  observaciones   text not null default 'Envase fabricado en polietileno de Alta Densidad (HDPE) 100% virgen con acabado nacarado mediante proceso de extrusión-soplo. Material de excelente calidad que otorga textura suave, alta resistencia mecánica y facilidad de manipulación. Apto para cosméticos y cuidado personal.',
  codigo_cert     text,                        -- campo CODIGO del certificado (solo Nutriderm lo trae)
  lote            text,
  correlativo     text,
  fecha_emision   date,
  skus            text[] not null default '{}',-- SKU de inventario que usan este envase
  skus_confirmado boolean not null default false,
  notas_datos     text,                        -- anomalías detectadas en el Excel
  fuente          text not null default 'CERTIFICADOS PRO..xlsx (Drive, 26-oct-2026)',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists envase_certificados_skus_gin on public.envase_certificados using gin (skus);

alter table public.envase_certificados enable row level security;
drop policy if exists lectura_con_perfil on public.envase_certificados;
drop policy if exists insert_master on public.envase_certificados;
drop policy if exists update_master on public.envase_certificados;
drop policy if exists delete_master on public.envase_certificados;
create policy lectura_con_perfil on public.envase_certificados
  for select to authenticated using (public.rol_actual() is not null);
create policy insert_master on public.envase_certificados
  for insert to authenticated with check (public.es_master());
create policy update_master on public.envase_certificados
  for update to authenticated using (public.es_master()) with check (public.es_master());
create policy delete_master on public.envase_certificados
  for delete to authenticated using (public.es_master());
revoke all on public.envase_certificados from anon;
grant select, insert, update, delete on public.envase_certificados to authenticated;

-- (clave, hoja, comercial, cap_ml, color, peso, min, max, alto, min, max, cuello, min, max,
--  Øint, min, max, Øext, min, max, ancho, min, max, uds_bolsa, bolsas_tarima)
insert into public.envase_certificados
 (clave,nombre_hoja,nombre_comercial,capacidad_ml,color,peso_g,peso_min_g,peso_max_g,altura_mm,altura_min_mm,altura_max_mm,cuello_mm,cuello_min_mm,cuello_max_mm,boq_int_mm,boq_int_min_mm,boq_int_max_mm,boq_ext_mm,boq_ext_min_mm,boq_ext_max_mm,ancho_mm,ancho_min_mm,ancho_max_mm,unidades_bolsa,bolsas_tarima)
values
 ('litro-28','LITRO 28','LITRO BLANCO HOMBROS REDONDOS 28/410',1000,null,58,56,60,266,265.7,266.3,17,16.7,17.3,21.5,21.2,21.8,27.7,27.5,27.9,76,75.7,76.3,100,20),
 ('manzanita-150','MANZANITA','ENVASE MANZANITA NACARADO HDPE 150G',150,null,15,14,16,61.5,61,61.8,11.2,11,11.5,45.5,45.2,45.8,55,54.7,55.3,73,72.5,73.5,500,6),
 ('luna-750','LUNA 750','LUNA 750 ML',750,null,60,58,62,260.5,260.2,260.8,17,16.7,17.3,21.5,21.2,21.8,27.7,27.5,27.9,99.5,99.2,99.8,100,20),
 ('bullet-400','BULLET 400 ML','BULLET 400 ML',400,null,35,34,36,215,214.7,215.3,17,16.7,17.3,21.5,21.2,21.8,27.7,27.5,27.9,56.3,56,56.6,100,20),
 ('bullet-200','BULLET 200 ML','BULLET 200 ML',200,null,25,24,26,157,156.7,157.3,17,16.7,17.3,21.5,21.2,21.8,27.7,27.5,27.9,49,48.7,49.3,200,20),
 ('litro-33','LITRO 33','LITRO CUELLO 33',1000,null,58,56,60,253.2,252.9,253.5,20.5,20.2,20.8,25.5,25.2,25.8,32.5,32.2,32.8,79.5,79.2,79.8,100,20),
 ('cilindrico-500-largo','CILINDRICO 500 ML LARGO','CILINDRICO 500 ML LARGO',500,null,38,37,39,248.5,248.2,248.8,17,16.7,17.3,21.5,21.2,21.8,27.7,27.5,27.9,52.3,52,52.6,100,20),
 ('cilindrico-bala-350','CILINDRICO BALA 350 ML','CILINDRICO BALA 350 ML',320,null,30,29,31,243.5,243.2,243.8,17,16.7,17.3,21.5,21.2,21.8,27.7,27.5,27.9,50,49.7,50.3,100,20),
 ('barrilito-300','BARRILITO 300 ML','BARRILITO 300 ML',300,null,28,27,29,121,120.7,121.3,13.4,13.1,13.7,21.5,21.2,21.8,27.7,27.5,27.9,64,63.7,64.3,150,20),
 ('luna-400','LUNA 400 ML','MEDIA LUNA 400 ML',400,null,35,34,36,201.2,200.9,201.5,17,16.7,17.3,21.5,21.2,21.8,27.7,27.5,27.9,81.5,81.2,81.8,200,20),
 ('lulu-500','ENVASE LULU 500 ML','ENVASE LULU 500 ML',500,null,40,39,41,236.5,236.2,236.8,17,16.7,17.3,21.5,21.2,21.8,27.7,27.5,27.9,61.5,61.2,61.8,200,20),
 ('soft-lady-curvo-300','SOFT LADY CURVO 300 ML','SC-SIL-PUSHPULL-300',300,null,29,28,30,193.5,193.2,193.8,17,16.7,17.3,21.5,21.2,21.8,27.7,27.5,27.9,72.3,72,72.6,200,20),
 ('soft-lady-curvo-180','SOFT LADY CURVO 180 ML','SC-SIL-SPRAY-180',180,null,20,19,21,167.5,167.2,167.8,18,17.8,18.2,18.7,18.5,18.8,23,22.8,23.2,57.7,57.5,57.9,200,20),
 ('kontrol-400','KONTROL 400 ML','OVAL KONTROL 400 ML',400,'BLANCO',40,39,41,213,212.8,213.2,21,20.8,21.2,14.5,14.3,14.7,21,20.8,21.2,72.5,72.3,72.7,200,20),
 ('live-500','LIVE 500 ML','LIVE 500 ML',500,'BLANCO',40,39,41,221.5,221.3,221.7,21,20.8,21.2,14.5,14.3,14.7,21,20.8,21.2,82.2,82,82.4,200,20),
 ('live-250-chamer','LIVE 250 ML CHAMER','LIVE 250 ML CHAMER',250,'BLANCO',28,27,29,170.5,170.3,170.7,21,20.8,21.2,14.5,14.3,14.7,21,20.8,21.2,76.6,76.4,76.8,200,20),
 ('live-220-jj','LIVE 220 ML J&J','LIVE 220 ML J&J',220,'BLANCO',28,27,29,159.3,159.2,159.5,21,20.8,21.2,14.5,14.3,14.7,21,20.8,21.2,75.8,75.6,76,200,20),
 ('linea-bebe-240','LINEA BEBE 240 ML','240 LINEA BEBE',240,'BLANCO',28,27,29,149,148.8,149.2,21,20.8,21.2,14.5,14.3,14.7,21,20.8,21.2,79.3,79.1,79.5,200,20),
 ('linea-bebe-carefur-240','LINEA BEBE CAREFUR 240 ML','LINEA BEBE CAREFUR 240 ML',240,'BLANCO',28,27,29,159.8,159.6,160,21,20.8,21.2,14.5,14.3,14.7,21,20.8,21.2,79,78.8,79.2,200,20),
 ('nutriderm-12oz','ENVASE NUTRIDERM 12 OZ','NUTRIDERM 12 OZ',360,'BLANCO',38,36,40,179.5,179.2,179.8,17,16.7,17.3,21.4,21.1,21.5,27.6,27.3,27.9,80.5,80.2,80.8,200,20),
 ('saloe-750','ENVASE SALOE 750 ML','SALOE 750 ML',750,'BLANCO',60,58,62,284.5,284.3,284.7,21,20.8,21.2,14.5,14.3,14.7,21,20.8,21.2,112,null,112.2,100,20),
 ('kontrol-jr-100','KONTROL JR 100 ML','KONTROL JR 100 ML',100,'BLANCO',14,13,15,125.5,125.3,125.7,21,20.8,21.2,14.5,14.3,14.7,21,20.8,21.2,63.3,63.1,63.5,100,20),
 ('oval-sc-400-sinergia','OVAL SC 400 ML SINERGIA','OVAL SC 400 ML SINERGIUA',400,'AMARILLO',45,43,47,179.5,179.2,179.8,16.5,16.2,16.8,21.5,21.2,21.8,27.3,27,27.6,100,99.7,100.3,100,20),
 ('bio-beige-400','BIO BEIGE 400 ML','BIO BEIGE 400 ML',400,'NACARADO',35,34,36,225.5,225.2,225.8,21.5,21.2,21.8,20.6,20.3,20.9,27.3,27,27.6,88,87.7,88.3,100,20),
 ('baby-shampoo-220','220 BABY SHAMPOO','BABY SHAMPOO 220 ML',220,'FUCSIA',25,24,26,169.8,169.6,170,17,16.8,17.2,20.2,20,20.4,27.5,27.3,null,69.8,69.6,70,100,20),
 ('pastillero-an-150','PASTILLERO AN 150 ML HDPE','PASTILLERO A.N. 150 ML',150,'BLANCO',20,19,21,95,94.8,95.2,9.2,9,9.4,28.7,28.5,28.9,36.7,36.5,36.9,55,54.8,55.2,200,20),
 ('pastillero-cuadrado-85','PASTILLERO CUADRADO','PASTILLERO CUADRADO 85 ML',85,'BLANCO',12,11,13,80.5,80.2,80.8,17,16.7,17.3,21,20.7,21.3,27.5,27.2,27.8,47.5,47.2,47.8,200,20),
 ('pastillero-dorado-scentia','PASTILLERO DORADO SCENTIA','PASTILLERO SCENTIA DORADO',150,'DORADO',14,13,15,92.8,92.6,93,9.2,9,9.4,29.3,29.1,29.5,36.7,36.5,36.9,52.6,52.4,52.8,200,20),
 ('cilindrico-4oz','CILINDRICO 4 OZ','CILINDRICO 4 OZ',120,'DORADO',14,13,15,124.5,124.3,124.7,19.3,19.1,19.5,14.6,14.4,14.8,19.7,19.5,19.9,41.5,41.3,41.7,500,20),
 ('nutri-milk-200','ENVASE NUTRI MILK','NUTRI MILK 200 ML',200,'BLANCO',20,19,21,143,142.8,143.2,9.2,9,9.4,32.2,32,32.4,36.7,36.5,36.8,51.5,51.3,51.7,200,20),
 ('pastillero-pvc-85-verde','PASTILLERO PVC FARMALLA','PASTILLERO 85 ML PVC VERDE',85,'VERDE TRASLUCIDO',12,11,13,81,80.8,81.2,9.2,9,9.4,29.6,29.4,29.8,36.7,36.5,36.8,45,44.8,45.2,200,20)
on conflict (clave) do update set
  nombre_hoja=excluded.nombre_hoja, nombre_comercial=excluded.nombre_comercial, capacidad_ml=excluded.capacidad_ml,
  color=excluded.color, peso_g=excluded.peso_g, peso_min_g=excluded.peso_min_g, peso_max_g=excluded.peso_max_g,
  altura_mm=excluded.altura_mm, altura_min_mm=excluded.altura_min_mm, altura_max_mm=excluded.altura_max_mm,
  cuello_mm=excluded.cuello_mm, cuello_min_mm=excluded.cuello_min_mm, cuello_max_mm=excluded.cuello_max_mm,
  boq_int_mm=excluded.boq_int_mm, boq_int_min_mm=excluded.boq_int_min_mm, boq_int_max_mm=excluded.boq_int_max_mm,
  boq_ext_mm=excluded.boq_ext_mm, boq_ext_min_mm=excluded.boq_ext_min_mm, boq_ext_max_mm=excluded.boq_ext_max_mm,
  ancho_mm=excluded.ancho_mm, ancho_min_mm=excluded.ancho_min_mm, ancho_max_mm=excluded.ancho_max_mm,
  unidades_bolsa=excluded.unidades_bolsa, bolsas_tarima=excluded.bolsas_tarima, updated_at=now();

-- Excepciones por certificado
update public.envase_certificados set material='POLIETILENO (HDPE) 50% / (LDPE) 50%',
  notas_datos='Único con mezcla HDPE 50% + LDPE 50%; el resto es HDPE 100% virgen.' where clave='barrilito-300';
update public.envase_certificados set
  notas_datos='El nombre dice 350 ML pero la capacidad certificada es 320 ml (el SKU de inventario sí dice 350).' where clave='cilindrico-bala-350';
update public.envase_certificados set
  notas_datos='Celda suelta "16.8" en el Excel (junto al peso), sin significado claro; no se guardó.' where clave='luna-750';
update public.envase_certificados set
  notas_datos='Celda suelta "-13.4" en el Excel; no se guardó.' where clave in ('luna-400','lulu-500');
update public.envase_certificados set
  notas_datos='Celda suelta "-18" junto a Altura del cuello; no se guardó. El "lote" del certificado trae el nombre SC-SIL-SPRAY-180 (parece nombre interno del producto).' where clave='soft-lady-curvo-180';
update public.envase_certificados set
  notas_datos='El nombre comercial del Excel trae SC-SIL-PUSHPULL-300 (nombre interno del producto).' where clave='soft-lady-curvo-300';
update public.envase_certificados set codigo_cert='214325', lote='6429', correlativo='1', fecha_emision='2026-10-23',
  notas_datos='Único certificado emitido (con código, lote, correlativo y fecha). El código 214325 NO existe en inventario; el SKU parecido es 214825 "CREMA NURIDERM 12 OZ BLANCO" (posible error de dedo en el Excel). Tolerancia de peso 36-40 g (±2), más amplia que en los demás.' where clave='nutriderm-12oz';
update public.envase_certificados set
  notas_datos='Ancho máximo del envase: resultado 112.00, mínimo "11.80" (error de dedo, ¿111.80?) → se guardó NULL.' where clave='saloe-750';
update public.envase_certificados set
  notas_datos='El nombre en el Excel dice "SINERGIUA" (error de dedo de SINERGIA).' where clave='oval-sc-400-sinergia';
update public.envase_certificados set
  notas_datos='Ø exterior de boquilla: resultado 27.50, mín 27.30, máx "24.70" (error de dedo, ¿27.70?) → se guardó NULL.' where clave='baby-shampoo-220';
update public.envase_certificados set
  notas_datos='Celda suelta "8.8" junto a Altura; no se guardó. Misma capacidad (150 ml) que PASTILLERO AN pero otras medidas (más ancho de boquilla, 14 g vs 20 g).' where clave='pastillero-dorado-scentia';
update public.envase_certificados set
  notas_datos='Color DORADO en el Excel (puede ser copia del certificado anterior; los SKU de 4 oz existen en muchos colores). Capacidad 120 ml (el nombre dice 4 OZ ≈ 118 ml). 500 uds por bolsa.' where clave='cilindrico-4oz';
update public.envase_certificados set
  material='POLICLORURO DE VINILO (PVC) rígido 100% virgen, libre de BPA y ftalatos. No exponer a temperaturas superiores a 50°C ni a luz solar directa prolongada.',
  caida_m=0.5,
  observaciones='Envase fabricado en Policloruro de Vinilo (PVC) 100% virgen con acabado brillante mediante proceso de extrusión-soplado. Material de alta transparencia, brillo y rigidez, con excelente resistencia química y facilidad de manipulación. Apto para productos farmacéuticos, cosméticos y cuidado personal.',
  notas_datos='Único PVC del archivo: prueba de impacto desde 0.5 m (los demás 1.5 m).' where clave='pastillero-pvc-85-verde';
update public.envase_certificados set
  notas_datos='Los primeros 13 certificados (LITRO 28 … SOFT LADY 180) no traen el campo COLOR; el texto de observaciones los describe como acabado nacarado.' where clave in ('litro-28');

-- Vínculo con inventario (SUGERIDO, skus_confirmado=false): SKU de Bodega 2 cuyo nombre corresponde al modelo.
-- Sin vínculo todavía: luna-750 (el SKU 10435 es "LUNA 780 ML", ¿es el mismo?) y nutri-milk-200.
-- Se aplicó con un UPDATE ... FROM (values (clave, array[sku...])) filtrando contra inventario; para
-- rehacerlo: update public.envase_certificados set skus = array['10025',...] where clave = '...';
