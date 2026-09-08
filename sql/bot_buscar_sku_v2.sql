-- ═══════════════════════════════════════════════════════════════
-- TETRAPP — Bot WhatsApp: bot_buscar_sku v2 (fix + entrenamiento)
-- Correr en Supabase Dashboard → SQL Editor
--
-- Por qué:
--   1. bot_buscar_sku (sql/bot_rpcs_v1.sql, sección 4) NUNCA llegó a
--      crearse en producción — verificado llamando la RPC directo:
--      responde "function not found" mientras que bot_insertar_tiro
--      sí existe. Resultado: el bot jamás vincula SKU, sin importar
--      cómo se escriba el mensaje.
--   2. El matching original comparaba palabra por palabra tal cual
--      (LIKE simple), sin quitar tildes ni tolerar plural — "elípticas"
--      nunca hacía match contra "ELIPTICA" del catálogo.
--   3. No filtraba por bodega/facturación — podía traer filas que no
--      aplican a producción (ej. Bodega 5 = rechazos).
--
-- Qué corrige:
--   - Normaliza tildes en ambos lados (mensaje y catálogo).
--   - Compara PALABRA COMPLETA (con tolerancia a plural, quita una "s"
--     final), no subcadena — v3 usaba LIKE '%tok%' y eso hacía match
--     de "tapa" DENTRO de "CONTRATAPA", inflando por igual TAPA/
--     CONTRATAPA/BASE TAPA/ENVASE-con-tapa sin poder distinguirlos.
--   - Acota la búsqueda a `facturable = true` y bodega 2 (producto
--     terminado facturable) — igual filtro que usa bodega.html →
--     Existencias por default.
--
-- ⚠️ Esta función se vuelve a reemplazar en sql/bot_sku_palabras_clave_v1.sql
-- (agrega búsqueda por alias) — esa es la versión final que queda
-- corriendo. Este archivo se mantiene sincronizado para que sirva
-- solo también, pero si tocás el matching, actualizá los DOS.
-- ═══════════════════════════════════════════════════════════════

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
  )
  select
    inv.sku,
    inv.descripcion,
    (select count(*)::int from toks t where t.stem = any(coalesce(inv.desc_stems, array[]::text[]))) as hits
  from inv
  where trim(coalesce(p_texto, '')) <> ''
  order by hits desc, length(inv.descripcion) asc
  limit 12;
$$;

grant execute on function public.bot_buscar_sku(text) to anon;

notify pgrst, 'reload schema';

-- Verificación — debería devolver el SKU 10090 (TAPA ELIPTICA VERDE
-- CAREFUR ARMADA CON BANDA SINERGIA) con hits altos:
select * from public.bot_buscar_sku('elipticas carefur');
