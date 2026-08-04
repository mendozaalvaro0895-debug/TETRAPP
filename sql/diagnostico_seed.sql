-- Diagnóstico: ¿qué fecha(s) del seed histórico faltan o quedaron incompletas?
-- Solo lectura. Compara este resultado contra la tabla de "líneas por fecha"
-- que Claude ya tiene calculada del archivo original.
select fecha, count(*) as lineas, to_char(sum(cantidad),'FM999,999,999') as unidades
from public.produccion_diaria
where documento = 'SHEETS'
group by fecha
order by fecha;
