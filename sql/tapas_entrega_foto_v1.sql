-- ════════════════════════════════════════════════════════════════
-- Foto opcional en cada ENTREGA que registra la supervisora de Tapas (registro-tapas.html → Pedidos → ficha → 🚚 ENTREGA)
--   · tapas_entregas_parciales.foto_path → ruta de la foto dentro del bucket privado `tapas-entregas` ("<solicitud_id>/<marca de tiempo>.jpg")
--   · bucket `tapas-entregas`            → privado, máx. 5 MB, solo imágenes. Las fotos se ven con enlaces firmados (caducan en minutos).
--       lectura/subida: master, supervisor_tapas y operativo · borrar: master y supervisor_tapas
--   · tapas_registrar_entrega            → ahora recibe `p_foto` (opcional). Reemplaza a la versión de 6 parámetros.
-- Correr DESPUÉS de sql/tapas_entrega_v1.sql. Idempotente. Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

alter table public.tapas_entregas_parciales add column if not exists foto_path text;

-- Bucket privado
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('tapas-entregas', 'tapas-entregas', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists tapas_entregas_foto_insert on storage.objects;
create policy tapas_entregas_foto_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'tapas-entregas' and coalesce(public.rol_actual(), '') in ('master', 'supervisor_tapas', 'operativo'));

drop policy if exists tapas_entregas_foto_select on storage.objects;
create policy tapas_entregas_foto_select on storage.objects for select to authenticated
  using (bucket_id = 'tapas-entregas' and coalesce(public.rol_actual(), '') in ('master', 'supervisor_tapas', 'operativo'));

drop policy if exists tapas_entregas_foto_delete on storage.objects;
create policy tapas_entregas_foto_delete on storage.objects for delete to authenticated
  using (bucket_id = 'tapas-entregas' and coalesce(public.rol_actual(), '') in ('master', 'supervisor_tapas'));

-- La función cambia de firma (se agrega p_foto): se borra la anterior para no dejar dos versiones ambiguas
drop function if exists public.tapas_registrar_entrega(uuid, integer, boolean, date, text, text);

create or replace function public.tapas_registrar_entrega(
  p_id uuid, p_cantidad integer, p_completa boolean default false,
  p_fecha date default null, p_nota text default null, p_por text default null,
  p_foto text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_estado text;
  v_nuevo  uuid;
  v_dest   text;
begin
  if coalesce(public.rol_actual(), '') not in ('master', 'supervisor_tapas', 'operativo') then
    raise exception 'Sin permiso para registrar entregas';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0';
  end if;
  if p_foto is not null and p_foto not like (p_id::text || '/%') then
    raise exception 'Ruta de foto no válida';
  end if;
  select estado into v_estado from public.solicitudes where id = p_id and area = 'tapas';
  if not found then
    raise exception 'Ficha de Tapas no encontrada';
  end if;
  if v_estado = 'lista' then
    raise exception 'La ficha ya está COMPLETADA; usa Deshacer si fue un error';
  end if;

  v_dest := case when coalesce(p_completa, false) then 'lista' else 'parcial' end;

  insert into public.tapas_entregas_parciales (solicitud_id, cantidad, fecha, nota, registrado_por, cierra, foto_path)
  values (p_id, p_cantidad, coalesce(p_fecha, current_date), nullif(btrim(coalesce(p_nota, '')), ''), p_por, coalesce(p_completa, false), nullif(btrim(coalesce(p_foto, '')), ''))
  returning id into v_nuevo;

  update public.solicitudes
     set estado = v_dest, marcado_tapas_por = p_por, marcado_tapas_en = now()
   where id = p_id;
  update public.solicitud_lineas set estado = v_dest where solicitud_id = p_id;
  return v_nuevo;
end;
$$;

revoke all on function public.tapas_registrar_entrega(uuid, integer, boolean, date, text, text, text) from public, anon;
grant execute on function public.tapas_registrar_entrega(uuid, integer, boolean, date, text, text, text) to authenticated;

notify pgrst, 'reload schema';
