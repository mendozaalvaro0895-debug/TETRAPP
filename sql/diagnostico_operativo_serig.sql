-- 1) ¿Existe el usuario y con qué perfil (si tiene)?
select u.id as user_id, u.email, u.email_confirmed_at, p.rol, p.nombre
from auth.users u
left join public.perfiles p on p.user_id = u.id
where u.email ilike '%serig%';

-- 2) Si la fila de arriba muestra rol = NULL (usuario sin perfil) o no
--    aparece ninguna fila, correr esto reemplazando el user_id exacto
--    que haya salido arriba (o el email si el user sí existe):
insert into public.perfiles (user_id, rol, nombre)
select id, 'operativo_serig', 'Operativos Serigrafía'
from auth.users where email = 'serigrafia@tetrapp.app'
on conflict (user_id) do update set rol = 'operativo_serig', nombre = 'Operativos Serigrafía';

-- 3) Verificar de nuevo:
select u.id as user_id, u.email, p.rol, p.nombre
from auth.users u
join public.perfiles p on p.user_id = u.id
where u.email ilike '%serig%';

-- 4) Probar rol_actual() como lo vería la sesión de Heidy (ejecutar
--    esto ESTANDO logueado como serigrafia@tetrapp.app, no como owner/postgres,
--    o simplemente confirmar que el join de arriba muestra el rol correcto)
