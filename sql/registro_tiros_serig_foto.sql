-- ════════════════════════════════════════════════════════════════
-- Foto del contador en registro_tiros_serig
-- Correr en Supabase Dashboard → SQL Editor
-- ════════════════════════════════════════════════════════════════

-- 1. Agregar columna foto_url
ALTER TABLE public.registro_tiros_serig
  ADD COLUMN IF NOT EXISTS foto_url TEXT;

-- 2. Políticas RLS para el bucket 'tiros' en Storage
--    (el bucket ya existe y es public para lectura)

-- Subida: usuarios autenticados (operarios de serig@, master)
CREATE POLICY "tiros: autenticados pueden subir"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'tiros');

-- Sobreescritura (upsert al mismo path)
CREATE POLICY "tiros: autenticados pueden actualizar"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'tiros');

-- Borrado (admin hace limpieza de fotos antiguas)
CREATE POLICY "tiros: autenticados pueden borrar"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'tiros');

-- 3. Verificar
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'registro_tiros_serig'
ORDER BY ordinal_position;
