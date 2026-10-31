-- ════════════════════════════════════════════════════════════════
-- Bucket de Storage 'envases' (fotos del envase en el Recetario: produccion.html y ventas.html)
-- sql/sku_recetario_fotos_v1.sql dejó las políticas pero el bucket nunca se creó (paso manual) →
-- "Error al subir la foto: Bucket not found". Público a propósito (la app usa getPublicUrl).
-- Límite 6 MB (igual que el chequeo del front) y solo imágenes. Idempotente.
-- ════════════════════════════════════════════════════════════════
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('envases', 'envases', true, 6291456,
        array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/avif'])
on conflict (id) do update
  set public = true, file_size_limit = 6291456,
      allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/avif'];
