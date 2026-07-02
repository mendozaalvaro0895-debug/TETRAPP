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
`shared/` solo contiene `styles.css` (usado por los 6 HTML). Los `.js` que había ahí
(supabase.js, helpers.js, data.js, inventario.js) eran huérfanos y con código desactualizado
(bugs ya corregidos en las copias inline) — se borraron en jul/2026.

### Módulos activos
- `index.html` — Landing con KPIs globales
- `tapas.html` — Solicitudes de producción área Tapas
- `serigrafia.html` — Solicitudes área Serigrafía
- `comandas.html` — Registro de producción diaria por operario
- `dashboard.html` — KPIs ejecutivos
- `inventario.html` — Gestión de SKUs, existencias e importación desde Excel
- `produccion.html` — Placeholder "en desarrollo" (aún sin funcionalidad real)

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
Ninguno abierto por ahora. Últimos cerrados (jul/2026):
- `registrarPerdida/EntradaPT/SalidaBodega` ya usan `sku_original`/`operador_id` correctamente.
- `cargarInventario()` ya pagina con `.range()` en lotes de 1000 (trae los 2358 SKUs).
- `ajustarExistencia()` en tapas.html y serigrafia.html ahora llama a las RPCs atómicas
  `descontar_inventario(p_sku, p_cantidad)` / `aumentar_inventario(p_sku, p_cantidad)`
  en vez de hacer select+update manual en JS (evita race conditions).
- Carpeta `shared/` limpiada: solo queda `styles.css`, los `.js` huérfanos se borraron.

## Reglas de trabajo OBLIGATORIAS
1. Antes de modificar cualquier archivo: mostrar diagnóstico y esperar aprobación explícita.
2. Nunca usar template literals anidados → usar funciones helper separadas.
3. No duplicar funciones de DB entre módulos (compartir cuando sea posible).
4. Siempre entregar archivos descargables listos para subir a GitHub.
5. Confirmar qué archivo base se usará antes de editar.

## Personal (referencia — datos reales viven en la tabla `personal`)
- Tapas: T0 Heidy (supervisora), T1-T9 operadores
- Serigrafía: S0 Luis Cordova (supervisor), S1-S7 operadores
