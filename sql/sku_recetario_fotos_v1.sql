-- ════════════════════════════════════════════════════════════════
-- Foto del envase en sku_recetas (Recetario de SKUs)
-- Correr en Supabase Dashboard → SQL Editor
-- ════════════════════════════════════════════════════════════════

-- 1. Agregar columna foto_url
ALTER TABLE public.sku_recetas
  ADD COLUMN IF NOT EXISTS foto_url TEXT;

-- 2. Crear el bucket 'envases' en Storage (Dashboard → Storage → New bucket)
--    Nombre: envases · Public bucket: SÍ (para que las fotos carguen sin firma)
--    Este paso NO se puede hacer por SQL/API con la key publishable — es manual.

-- 3. Políticas RLS para el bucket 'envases' en Storage (mismo patrón que 'tiros')

-- Subida: usuarios autenticados (master)
CREATE POLICY "envases: autenticados pueden subir"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'envases');

-- Sobreescritura (upsert al mismo path — reemplazar foto existente)
CREATE POLICY "envases: autenticados pueden actualizar"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'envases');

-- Borrado
CREATE POLICY "envases: autenticados pueden borrar"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'envases');

-- 4. Verificar
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'sku_recetas'
ORDER BY ordinal_position;
