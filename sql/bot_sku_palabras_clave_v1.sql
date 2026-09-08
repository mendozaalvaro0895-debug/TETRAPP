-- ═══════════════════════════════════════════════════════════════
-- TETRAPP — Bot WhatsApp: palabras clave entrenables por SKU
-- Correr en Supabase Dashboard → SQL Editor. Requiere haber corrido
-- antes sql/bot_buscar_sku_v2.sql (este archivo lo reemplaza otra
-- vez, agregando la búsqueda por alias — es autocontenido, se puede
-- correr solo también).
--
-- Qué es:
--   Tabla `sku_palabras_clave` (sku, palabra) para enseñarle al bot
--   apodos/sinónimos que la descripción OFICIAL del inventario no
--   trae — ej. si algún día un cliente/color/apodo suelto debe
--   apuntar a un SKU específico sin que esa palabra exista en
--   `inventario.descripcion`. Se administra a mano (SQL Editor por
--   ahora) — Álvaro decide qué agregar cuando el matching automático
--   no alcance.
--
-- Nota: el ejemplo "elípticas Carefur" → SKU 10090 YA lo resuelve el
-- fix de bot_buscar_sku_v2.sql solo (tildes+plural), porque "CAREFUR"
-- y "ELIPTICA" ya están en la descripción oficial. Esta tabla es para
-- los casos donde la palabra NO aparece en absoluto en el catálogo.
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.sku_palabras_clave (
  id          serial primary key,
  sku         text not null,
  palabra     text not null,
  nota        text,
  creado_en   timestamptz default now(),
  unique (sku, palabra)
);

alter table public.sku_palabras_clave enable row level security;

drop policy if exists "lectura_con_perfil" on public.sku_palabras_clave;
drop policy if exists "insert_master"      on public.sku_palabras_clave;
drop policy if exists "update_master"      on public.sku_palabras_clave;
drop policy if exists "delete_master"      on public.sku_palabras_clave;

create policy lectura_con_perfil on public.sku_palabras_clave
  for select to authenticated using (public.rol_actual() is not null);

create policy insert_master on public.sku_palabras_clave
  for insert to authenticated with check (public.es_master());

create policy update_master on public.sku_palabras_clave
  for update to authenticated using (public.es_master()) with check (public.es_master());

create policy delete_master on public.sku_palabras_clave
  for delete to authenticated using (public.es_master());

revoke all on public.sku_palabras_clave from anon;
grant select, insert, update, delete on public.sku_palabras_clave to authenticated;

-- ── bot_buscar_sku (v4) — match por PALABRA COMPLETA, no subcadena ─
-- v3 usaba LIKE '%tok%', que hacía match de "tapa" DENTRO de
-- "CONTRATAPA" — inflaba por igual a CONTRATAPA/BASE TAPA/TAPA/ENVASE
-- con tapa y el SKU correcto nunca se distinguía. v4 compara la
-- palabra completa (con la misma tolerancia a plural de siempre)
-- contra cada palabra de la descripción, así "tapa" ya NO matchea
-- "contratapa" pero sigue matcheando "tapa" dentro de "BASE TAPA X"
-- (son dos palabras separadas, esa sí es la misma pieza).
create or replace function public.bot_buscar_sku(p_texto text)
returns table(sku text, descripcion text, hits int)
language sql
stable
security definer
set search_path = public
as $$
  with toks as (
    select distinct
      case when length(w) > 3 and right(w, 1) = 's' then left(w, length(w) - 1) else w end as stem
    from unnest(string_to_array(
      lower(translate(trim(p_texto), 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN')),
      ' '
    )) as w
    where length(w) >= 2
  ),
  inv as (
    select
      i.sku::text as sku,
      i.descripcion,
      (
        select array_agg(distinct
          case when length(w) > 3 and right(w, 1) = 's' then left(w, length(w) - 1) else w end
        )
        from unnest(string_to_array(
          lower(translate(i.descripcion, 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN')),
          ' '
        )) as w
        where length(w) >= 2
      ) as desc_stems
    from inventario i
    where i.activo = true
      and coalesce(i.facturable, true) = true
      and (i.bodega is null or i.bodega = 'B2')
  ),
  alias as (
    select
      k.sku,
      array_agg(distinct
        case when length(w) > 3 and right(w, 1) = 's' then left(w, length(w) - 1) else w end
      ) as alias_stems
    from public.sku_palabras_clave k,
      unnest(string_to_array(
        lower(translate(k.palabra, 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN')),
        ' '
      )) as w
    where length(w) >= 2
    group by k.sku
  )
  select
    inv.sku,
    inv.descripcion,
    (
      (select count(*)::int from toks t where t.stem = any(coalesce(inv.desc_stems, array[]::text[])))
      +
      (select count(*)::int from toks t
       join alias a on a.sku = inv.sku
       where t.stem = any(coalesce(a.alias_stems, array[]::text[])))
    ) as hits
  from inv
  where trim(coalesce(p_texto, '')) <> ''
  order by hits desc, length(inv.descripcion) asc
  limit 8;
$$;

grant execute on function public.bot_buscar_sku(text) to anon;

notify pgrst, 'reload schema';

-- Ejemplo de cómo enseñarle un apodo (ajusta sku/palabra según haga falta):
-- insert into public.sku_palabras_clave (sku, palabra, nota) values
--   ('10090', 'ovalada verde', 'apodo que usa Fulano en el grupo, no aparece en la descripción');
