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
--   - Prueba también la variante singular de cada palabra (quita una
--     "s" final) para tolerar plurales.
--   - Acota la búsqueda a `facturable = true` y bodega 2 (producto
--     terminado facturable) — igual filtro que usa bodega.html →
--     Existencias por default.
-- ═══════════════════════════════════════════════════════════════

create or replace function public.bot_buscar_sku(p_texto text)
returns table(sku text, descripcion text, hits int)
language sql
stable
security definer
set search_path = public
as $$
  with toks as (
    select
      tok,
      case when length(tok) > 3 and right(tok, 1) = 's'
           then left(tok, length(tok) - 1)
           else tok end as tok_sing
    from (
      select unnest(string_to_array(
        lower(translate(trim(p_texto), 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN')),
        ' '
      )) as tok
    ) t
    where length(tok) >= 2
  ),
  inv as (
    select
      i.sku::text as sku,
      i.descripcion,
      lower(translate(i.descripcion, 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN')) as desc_norm
    from inventario i
    where i.activo = true
      and coalesce(i.facturable, true) = true
      and (i.bodega is null or i.bodega = 'B2')
  )
  select
    inv.sku,
    inv.descripcion,
    (
      select count(*)::int from toks t
      where inv.desc_norm like '%' || t.tok || '%'
         or inv.desc_norm like '%' || t.tok_sing || '%'
    ) as hits
  from inv
  where trim(coalesce(p_texto, '')) <> ''
  order by hits desc, length(inv.descripcion) asc
  limit 8;
$$;

grant execute on function public.bot_buscar_sku(text) to anon;

notify pgrst, 'reload schema';

-- Verificación — debería devolver el SKU 10090 (TAPA ELIPTICA VERDE
-- CAREFUR ARMADA CON BANDA SINERGIA) con hits altos:
select * from public.bot_buscar_sku('elipticas carefur');
