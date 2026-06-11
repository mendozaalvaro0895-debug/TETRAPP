# TETRAPP — Sistema Digital de Producción y Procesos
## Tetraplastic · Guatemala · Usuario: Alvaro Mendoza (Administrador)

## Stack
- Frontend: HTML vanilla (sin frameworks) + CSS inline por módulo
- Base de datos: Supabase (PostgreSQL) vía API REST
- Deploy: Vercel (auto-deploy desde rama `main`)
- Repo: github.com/mendozaalvaro0895-debug/TETRAPP

## Supabase
- URL: https://rohdxjuuvpgrhevfsrye.supabase.co
- KEY (publishable): sb_publishable_PayfE36QRzwOnP6zA2TDSQ_oj4vnB5i
- Cada HTML crea su propio cliente `db` inline (no usa shared/supabase.js)

## Arquitectura actual
Cada HTML es AUTÓNOMO (todo inline): su propio cliente db, CSS en <style>, funciones y datos.
Los archivos en shared/ están HUÉRFANOS — ningún HTML los carga actualmente.

### Módulos activos
- `index.html` — Landing con KPIs globales
- `tapas.html` — Solicitudes de producción área Tapas (1266 líneas)
- `serigrafia.html` — Solicitudes área Serigrafía (1244 líneas)
- `comandas.html` — Registro de producción diaria por operario (890 líneas)
- `dashboard.html` — KPIs ejecutivos (215 líneas)

### Tablas Supabase (schema v2.0)
- `solicitudes` — encabezado de órdenes (código auto T-001/S-001 via trigger)
- `solicitud_lineas` — líneas de producto por solicitud (incluye operadores_ids TEXT[])
- `solicitud_operadores` — operadores asignados
- `solicitud_historial` — historial de cambios de estado
- `personal` — operadores y supervisores (codigo UNIQUE, proceso_hab, color_hex)
- `inventario` — 2358 SKUs activos (columnas: sku, descripcion, existencia, facturable, activo)
- `movimientos_materiales` — trazabilidad (columnas REALES: id, solicitud_id, tipo, sku_original, cantidad, motivo_perdida, operador_id, observaciones, created_at)
- `paros_maquina` — registro de paros
- `comandas` + `comanda_tareas` — producción diaria
- `clientes`, `cat_procesos`, `asistencia` — catálogos
- Vistas: `v_solicitudes`, `v_capacidad_hoy`

## Bugs conocidos (pendientes de corregir)
1. 🔴 `registrarPerdida/EntradaPT/SalidaBodega` en tapas.html y serigrafia.html insertan
   campos `sku` y `usuario` pero la tabla tiene `sku_original` y `operador_id`.
   → Trazabilidad rota. Prioridad ALTA.

2. 🔴 `cargarInventario()` en tapas.html y serigrafia.html usa `.limit(200)` pero hay
   2358 SKUs activos → 92% de productos no se puede buscar.
   → Quitar el límite o paginar. Prioridad ALTA.

3. 🟡 RPCs `descontar_inventario()` y `aumentar_inventario()` existen en Supabase
   pero el frontend nunca las llama → existencia no se ajusta al registrar movimientos.

4. 🟡 Carpeta `shared/` con 5 archivos orphanos (nadie los carga).
   Decidir: consolidar ahí o borrar.

## Reglas de trabajo OBLIGATORIAS
1. Antes de modificar cualquier archivo: mostrar diagnóstico y esperar aprobación explícita.
2. Nunca usar template literals anidados → usar funciones helper separadas.
3. No duplicar funciones de DB entre módulos (compartir cuando sea posible).
4. Siempre entregar archivos descargables listos para subir a GitHub.
5. Confirmar qué archivo base se usará antes de editar.

## Personal (data.js — referencia, no se carga en producción)
- Tapas: T0 Heidy (supervisora), T1-T9 operadores
- Serigrafía: S0 Luis Cordova (supervisor), S1-S7 operadores
