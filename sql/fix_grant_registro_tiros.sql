-- Fix: falta el GRANT base sobre la tabla para el rol authenticated.
-- Las politicas RLS ya estaban bien, pero sin este GRANT Postgres
-- rechaza la operacion antes de siquiera evaluar la politica
-- ("permission denied for table" en vez de "violates row-level security policy").
grant select, insert, update, delete on public.registro_tiros_serig to authenticated;

-- Verificar que quedo otorgado:
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'registro_tiros_serig'
order by grantee, privilege_type;
