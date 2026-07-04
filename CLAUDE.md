# TETRAPP — Sistema Digital de Producción y Procesos
## Tetraplastic · Guatemala · Usuario: Álvaro Mendoza (Administrador)

---

## Stack y Deploy
- Frontend: HTML vanilla autónomo por módulo (sin frameworks). CSS inline en cada archivo.
- Base de datos: Supabase (PostgreSQL) vía API REST
- Deploy: Vercel auto-deploy desde rama `main`
- Repo: github.com/mendozaalvaro0895-debug/TETRAPP
- Git: push siempre a AMBAS ramas → `git push origin master` + `git push origin master:main`

## Supabase
- URL: https://rohdxjuuvpgrhevfsrye.supabase.co
- KEY (publishable): sb_publishable_PayfE36QRzwOnP6zA2TDSQ_oj4vnB5i
- Cada HTML crea su propio cliente `db` inline (no usa shared/supabase.js)
- `exec_sql` RPC no disponible con publishable key — DDL debe correrse manual en el dashboard

---

## Arquitectura actual
Cada HTML es AUTÓNOMO: cliente db propio, CSS en `<style>`, funciones y datos inline.
`shared/styles.css` es el único archivo compartido — se carga en todos los HTML como
`<link rel="stylesheet" href="shared/styles.css">` ANTES del `<style>` propio.
Los `.js` en shared/ eran huérfanos y se borraron (jul/2026).

### Módulos y su estado
| Archivo | Estado | Descripción |
|---|---|---|
| `index.html` | ✅ Activo | Fachada principal — 6 cards de módulo |
| `tapas.html` | ✅ Activo | Módulo completo Tapas (hub + pedidos + movimientos + personal) |
| `serigrafia.html` | ⚠️ Parcial | Solo Personal activo; resto muestra "En construcción" |
| `comandas.html` | ✅ Activo | Registro de producción diaria por operario |
| `dashboard.html` | ✅ Activo | KPIs ejecutivos globales |
| `inventario.html` | ✅ Activo | Gestión de SKUs, existencias, importación Excel |
| `produccion.html` | 🔒 Placeholder | "En desarrollo" — sin funcionalidad real |

### Módulos bloqueados (nav-locked vía CSS)
- Ventas y Bodega: `<a class="nav-locked">` — bloqueados en toda la navegación global

---

## Design System v1.0 — shared/styles.css

### Paleta CSS (variables en :root)
- Teal (marca):   `--teal #1A6B5B`, `--teal-l #2A8B75`, `--teal-xl #E8F5F2`, `--teal-dark #134F43`
- Amber:          `--amber #D97706`
- Red:            `--red #EF4444`, `--red-l` (light)
- Green:          `--green #16A34A`
- Producción:     `--prod #B07D2A`, `--prod-xl #FFFBEB`
- Ventas:         `--ventas #1D4ED8`, `--ventas-xl #EFF6FF`
- Bodega:         `--bodega #0E7490`, `--bodega-xl #ECFEFF`
- UI:             `--ink #0C0C0B`, `--bg #F7F6F2`, `--bg2 #F0EDEA`, `--card #FFFFFF`
- Tipografía:     `--display` (Playfair Display), `--sans` (DM Sans), `--mono` (DM Mono)

### Componentes y patrones establecidos
1. **Topbar**: fondo `#0C0C0B`, borde inferior teal, logo con dropdown de navegación global
2. **Logo-nav**: items activos con `nav-active`, bloqueados con `nav-locked` (🔒 via CSS `::after`)
3. **Sidenav**: iconos emoji, `.sn-btn` / `.sn-btn.active`
4. **Tabs**: `.tab` / `.tab.active` + `.tabs-r` (botones de acción a la derecha)
5. **Vistas**: `.view` con `display:flex/none` controlado por `switchTab()`
6. **KPI strip**: `.kpi-strip` horizontal con `.kpi` / `.kpi-l` / `.kpi-v` / `.kpi-s`
7. **Modales**: `.overlay` > `.modal` > `.mh` / `.mb` / `.mf` con animación `ds-slideUp`
8. **Segmented control**: `.seg-btn` / `.seg-active` — toggle dentro de una misma vista
9. **WIP view**: `.wip-view` con `.wip-icon` (animación `ds-float`), `.wip-title`, `.wip-chips`
10. **Sub-cards (hub)**: `.sub-card` con hover translate + shadow, `.sub-card-icon`, `.sub-stat`
11. **Autocomplete SKU**: `.sku-wrap` > `.sku-drop` con `.sku-opt` onmousedown
12. **Micro-animaciones**: `ds-dropDown` (nav), `ds-slideUp` (modales), `ds-float` (WIP),
    `btn:active { transform: scale(0.97) }`, progress `transition: width .75s`
13. **Responsive**: ≤1024px (2-col kpi), ≤768px (topbar wrap + modales full-width), ≤480px (1-col)

---

## tapas.html — Arquitectura de vistas (la más compleja)

```
switchTab(tab) controla qué view se muestra.
'rechazos' es ALIAS → switchTab('movimientos') + setMovVista('rechazos')

view-inicio     (HUB — default al cargar)
  4 KPIs globales + 5 sub-cards:
  Pedidos → switchTab('tapas')
  Procesos → switchTab('movimientos')
  Personal → switchTab('personal')
  Rechazos → switchTab('rechazos')  [alias]
  Dashboard → dashboard.html

view-tapas      (Solicitudes — split pane: lista + detalle)
view-movimientos (Módulo UNIFICADO con segmented control de 3)
  [📤 Salidas de Bodega] [📦 Ingresos PT] [⛔ Rechazos]
  Comparten: movDesde/movHasta, movBuscar, kpi-strip (mkpi-v1..v4), movTabla
  setMovVista('salida'|'ingreso'|'rechazos') actualiza todo
  movRegistrar() delega a abrirModalMov() o abrirModalRechazo()
view-dash       (mini-dashboard área)
view-personal   (grid de operadores)
```

### Botones de acción rápida (tabs-r en tapas.html)
- `+ Nueva Solicitud` → `abrirForm()`
- `📋 Comandas` → link a comandas.html
- `⬆⬇ Movimiento ▾` → dropdown con: 📤 Salida / 📦 Ingreso PT / ⛔ Registrar Rechazo

---

## serigrafia.html — Arquitectura de vistas

```
view-personal   (ACTIVO por defecto — display:flex en HTML)
view-wip        (shared — muestra "En Construcción" con WIP_CONFIG)
Tabs WIP: serig, salidas, ingresos → showWipView(key)
switchTab() revisa WIP_TABS array antes de renderizar
```

---

## Tablas Supabase (schema v2.0)

| Tabla | Descripción |
|---|---|
| `solicitudes` | Órdenes (código T-001/S-001 via trigger DB) |
| `solicitud_lineas` | Líneas de producto (operadores_ids TEXT[]) |
| `solicitud_operadores` | Asignación de operadores |
| `solicitud_historial` | Historial de cambios de estado |
| `personal` | Operarios/supervisores (codigo UNIQUE, proceso_hab, color_hex) |
| `inventario` | 2358 SKUs activos (sku, descripcion, existencia, facturable, activo) |
| `movimientos_materiales` | Trazabilidad (tipo: 'salida_bodega' \| 'entrada_pt') |
| `rechazos` | ⚠️ PENDIENTE DE CREAR en Supabase (SQL disponible) |
| `paros_maquina` | Registro de paros |
| `comandas` + `comanda_tareas` | Producción diaria |
| `clientes`, `cat_procesos`, `asistencia` | Catálogos |
| `v_solicitudes`, `v_capacidad_hoy` | Vistas |

### RPCs atómicas disponibles en Supabase
- `descontar_inventario(p_sku, p_cantidad)` — usar en lugar de select+update manual
- `aumentar_inventario(p_sku, p_cantidad)` — ídem

---

## Bugs activos (pendientes de corregir)

### Bug #1 — ALTA prioridad · tapas.html
Algunas funciones de movimientos usan nombres de campo incorrectos.
- `sku` en lugar de `sku_original`
- `usuario` en lugar de `operador_id`
Causa: copias antiguas del código antes de la migración del schema.

### Bug #2 — ALTA prioridad · tapas.html
`cargarInventario()` puede tener `.limit()` sin paginación → solo carga una fracción de los 2358 SKUs.
Fix correcto: paginar con `.range()` en lotes de 1000 hasta agotar resultados.

### Bug #3 — MEDIA prioridad · tapas.html
`ajustarExistencia()` hace select+update manual en JS en vez de llamar a las RPCs atómicas.
Esto genera race conditions bajo carga simultánea.

### Tabla rechazos — PENDIENTE
La tabla `rechazos` no existe aún en Supabase. El módulo la detecta y muestra aviso.
SQL de creación disponible (solicitarlo al asistente si se necesita).

---

## Reglas de trabajo OBLIGATORIAS
1. **Diagnóstico primero**: antes de modificar cualquier archivo, mostrar diagnóstico y esperar aprobación explícita.
2. **Sin template literals anidados**: usar funciones helper separadas (ej: `buildRechazoRow(r)`).
3. **No duplicar lógica de DB** entre módulos.
4. **Confirmar archivo base** antes de editar (especialmente tapas.html — es el más largo).
5. **Git siempre a ambas ramas**: `git push origin master && git push origin master:main`
6. **Verificar referencias eliminadas**: tras borrar IDs o funciones, grep para confirmar que no quedan usos huérfanos.
7. **var sobre const/let** en funciones globales de tapas.html (evitar errores de redeclaración entre módulos cargados múltiples veces).

---

## Personal (referencia — datos reales viven en la tabla `personal`)
- Tapas: T0 Heidy (supervisora), T1-T9 operadores
- Serigrafía: S0 Luis Cordova (supervisor), S1-S7 operadores
