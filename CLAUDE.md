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
| `comandas.html` | ✅ Activo | Registro de producción diaria por operario (vista admin) |
| `registro-tapas.html` | ✅ Activo | Formulario móvil para rol `operativo` (tapas@tetrapp.app): el operario elige su nombre y registra su comanda ya concluida (sin campo Estado, sin devolución de material); correlativo CMD-### lo asigna trigger DB; supervisor se lee en vivo de `personal` (rol='supervisor', area='tapas', activo=true) — nunca hardcodeado |
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
view-personal   (grid de operadores)
(view-dash y el modal de paro de máquina se eliminaron jul/2026 — eran código muerto)
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
| `personal` | Operarios/supervisores (codigo UNIQUE, proceso_hab, color_hex, rol: 'operador'\|'supervisor') — fuente única de verdad; registro-tapas.html lee el supervisor activo de aquí, no lo hardcodea |
| `inventario` | 2358 SKUs activos (sku, descripcion, existencia, facturable, activo) |
| `movimientos_materiales` | Trazabilidad (tipo: 'salida_bodega' \| 'entrada_pt') |
| `rechazos` | ✅ Existe (la creó movimientos_serigrafia_v1.sql) — RLS pendiente: correr sql/rechazos_rls_fix.sql |
| `perfiles` | Roles de acceso: master / visor / operativo (ver sql/operativo_tapas_v1.sql) |
| `paros_maquina` | Registro de paros |
| `comandas` + `comanda_tareas` | Producción diaria |
| `clientes`, `cat_procesos`, `asistencia` | Catálogos |
| `v_solicitudes`, `v_capacidad_hoy` | Vistas |

### RPCs atómicas disponibles en Supabase
- `descontar_inventario(p_sku, p_cantidad)` — usar en lugar de select+update manual
- `aumentar_inventario(p_sku, p_cantidad)` — ídem

---

## Bugs y pendientes

### Bugs históricos #1/#2/#3 — RESUELTOS (verificado jul/2026)
- #1 nombres de campo: corregido; incluía `rechSkuInput()` usando `inventario` en vez de `inventarioCache`
- #2 paginación: `cargarInventario()` ya pagina con `.range()` en lotes de 1000
- #3 race conditions: `ajustarExistencia()` ya usa las RPCs atómicas
Limpieza jul/2026 en tapas.html: eliminados view-dash/renderDash, modal paro máquina completo,
animPop y CSS huérfano (.rechazo-*, .rbadge, --serig-m, --gold).

### SQL pendiente de correr en Supabase (dashboard → SQL Editor)
1. `sql/rechazos_rls_fix.sql` — activa RLS en la tabla rechazos
2. `sql/operativo_tapas_v1.sql` — rol `operativo` + usuario tapas@tetrapp.app (crearlo antes
   en Auth → Users) + políticas INSERT en comandas/comanda_tareas + trigger correlativo CMD-###

### Roles de acceso (shared/auth.js v1.1)
- `master` → todo · `visor` → solo lectura (banner Modo Visual)
- `operativo` → enjaulado en registro-tapas.html; RLS solo le permite INSERT en comandas/comanda_tareas

### Metas de productividad — DOS tablas distintas, no confundir
1. `CAPACIDADES` en registro-tapas.html (y su copia en comandas.html) — und/hora por tarea
   individual de una comanda. Actualizada jul/2026: armado/liner/banda/encajado manual = 1000,
   flameado/impresión = 1167, máquinas = 2500, default = 1000. Incluye las 5 tareas nuevas
   (Revisado, Limpiar pestaña, Apoyo Serigrafía, Apoyo Producción, Otra tarea) a 1000.
   ⚠️ La copia en comandas.html sigue en 833 — pendiente de sincronizar si se pide.
2. `METAS` en tapas.html — und/hora por proceso, usada solo para estimar tiempo de entrega de
   solicitudes/pedidos (armado=1500, liner=1500, etc.). Sistema aparte, no se tocó esta sesión.

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
- Tapas: T0 Heidy (supervisora en tabla `personal`, aún sin actualizar), T1-T9 operadores
  - ⚠️ Supervisora actual real: **Yenifer** — la tabla `personal` sigue sin actualizar (pendiente,
    lo hará Álvaro). registro-tapas.html YA lee el supervisor en vivo de esta tabla
    (rol='supervisor', activo=true), así que en cuanto se actualice el registro de Heidy→Yenifer
    el formulario lo reflejará automáticamente, sin tocar código.
- Serigrafía: S0 Luis Cordova (supervisor), S1-S7 operadores
