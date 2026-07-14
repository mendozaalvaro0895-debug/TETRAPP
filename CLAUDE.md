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
- El cliente `db` lo provee `shared/auth.js` a TODAS las páginas (guardián de sesión + roles);
  ningún HTML declara ya SUPA_URL/SUPA_KEY/db propios
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
| `serigrafia.html` | ✅ Activo | Módulo admin Serigrafía: Inicio (board de solicitudes) + Movimientos + Productividad (lecturas de contador por línea, con diagnóstico si la fecha elegida está vacía) + Personal (asistencia con grid mensual, veladas, PDF) + link a Dashboard |
| `registro-serigrafia.html` | ✅ Activo | Formulario móvil rol `operativo_serig` (serigrafia@tetrapp.app). Pantalla 0 = selección de tarea: 🔥 Flameado (una bolsa por registro: hora, envase autocomplete, cantidad, Para línea 1-4; "otra bolsa" conserva flameador/envase/línea) · 🖨 Impresión (lectura de contador por línea/momento inicio-mediodía-fin-velada, foto opcional, paros del turno) · 📦 Empaque (operador o "apoyo de otra área" con area_origen, SKU + cantidad, fecha/hora automáticas). Errores de guardado se muestran en recuadro rojo persistente |
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
Tabs: Inicio · Movimientos · Productividad · Personal · Dashboard (link)
view-inicio        (board de solicitudes por línea, entregados, orden sin asignar)
view-movimientos   (salidas/ingresos serig + resumen por ficha)
view-productividad (lecturas de registro_tiros_serig por fecha; si la fecha
                    está vacía, buildUltimasLecturasHint() muestra las últimas
                    10 lecturas de la tabla sin filtro, clicables para saltar
                    a su fecha — distingue "base vacía" de "fecha equivocada")
view-personal      (grid personal + asistencia diaria/mensual, veladas, PDF)
```

## registro-serigrafia.html — Flujos (rol operativo_serig)

```
scrTarea (pantalla 0, default) → 3 tarjetas: flameado / impresion / empaque
Impresión: scrSel → scrForm (contador, momentos, paros, foto) → scrOk (gráfico)
Flameado:  scrSelFlam → scrFormFlam → scrOkFlam   (tabla registro_flameado_serig)
Empaque:   scrSelEmp (+tarjeta "Apoyo de otra área" → ovApoyo) → scrFormEmp
           → scrOkEmp                              (tabla registro_empaque_serig)
mostrarPantalla() alterna sobre el array PANTALLAS.
buildOpCardGen(op, fn) genera las tarjetas de operario para los 3 flujos.
skuDescDe(inputId) extrae {sku, descripcion} de un input con acGen.
Apoyo externo: operador_codigo=null + area_origen (tapas/produccion/bodega/otra)
— NO se agrega a la tabla personal.
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
| `perfiles` | Roles de acceso: master / visor / operativo / operativo_serig |
| `paros_maquina` | Registro de paros (legado tapas) |
| `registro_tiros_serig` | Lecturas de contador por línea/fecha/momento (inicio/mediodia/fin/velada) + hora + foto_url — la llena Impresión en registro-serigrafia.html; la lee Productividad en serigrafia.html. RLS reparada con sql/fix_rls_serig_v2.sql (corrido jul/2026) |
| `paros_serig` | Paros por línea/fecha con motivo (incl. EMPAQUE con envase+cantidad) — registrados desde el formulario del operador |
| `registro_flameado_serig` | Una fila por bolsa flameada: hora, flameador, sku/descripcion, cantidad, para_linea 1-4 (sql/registro_procesos_serig_v1.sql) |
| `registro_empaque_serig` | Empaques: operador_codigo (null = apoyo externo), area_origen, sku/descripcion, cantidad (sql/registro_procesos_serig_v1.sql) |
| `entregas_serig` | Entregas/requis de serigrafía (migradas desde localStorage) |
| `asistencia_diaria` | Asistencia por fecha/área/turno (presente/ausente/tarde/velada) — la usan serigrafia.html Personal y sus PDFs |
| `comandas` + `comanda_tareas` | Producción diaria |
| `clientes`, `cat_procesos`, `asistencia`, `configuracion` | Catálogos / preferencias UI |
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
3. `sql/registro_procesos_serig_v1.sql` — crea registro_flameado_serig + registro_empaque_serig
   con RLS (pendiente de confirmar; sin él los flujos Flameado/Empaque fallan con recuadro rojo)

### SQL ya corridos (referencia, jul/2026)
- `sql/seguridad_v1.sql` — blindaje: perfiles + rol_actual()/es_master() + anon sin privilegios.
  ⚠️ Su sección C BORRA TODAS las políticas del schema y recrea solo las genéricas: si se
  re-corre, hay que re-correr después los fix de políticas específicas (insert_operativo_serig etc.)
- `sql/fix_rls_serig_v2.sql` — reparó registro_tiros_serig: política insert_operativo_serig,
  columna hora, CHECK momento con 'velada', y corrigió fechas UTC adelantadas un día

### Roles de acceso (shared/auth.js)
- `master` → todo · `visor` → solo lectura (banner Modo Visual)
- `operativo` → enjaulado en registro-tapas.html; RLS solo le permite INSERT en comandas/comanda_tareas
- `operativo_serig` → enjaulado en registro-serigrafia.html; INSERT en registro_tiros_serig,
  paros_serig, registro_flameado_serig, registro_empaque_serig
- La jaula vive en TETRA_PAGINAS_OPERATIVO (auth.js): rol → página permitida
- Sesiones expiran a 60 min de inactividad, EXCEPTO roles operativos (pantallas de planta)

### Metas de productividad — CUATRO tablas, sincronizadas jul/2026
Valores oficiales (und/hora), idénticos en las 4 copias:
- Armado, Liner, Banda (manual): **1500**
- Encajado: **3000**
- Flameado, Impresión: **1500**
- Armado, Liner (máquina — Press Top 28/33): **2500**
- Otras tareas (Revisado, Limpiar pestaña, Apoyo Serigrafía, Apoyo Producción, Otra tarea,
  y cualquier proceso sin meta explícita): **1200**

Dónde viven las 4 copias (misma lógica, 4 archivos porque cada HTML es autónomo — ver
Arquitectura actual):
1. `CAPACIDADES` en registro-tapas.html — und/hora por tarea individual (rol operativo)
2. `CAPACIDADES` en comandas.html — misma tabla, vista admin (su PROCS_LIST no incluye las
   4 tareas nuevas, solo necesita el default `manual`/`otro` en 1200)
3. `METAS` + `META_DEFAULT` en tapas.html — estima tiempo de entrega de solicitudes/pedidos
   (metaParaProcesos). Tiene claves muertas sin tocar (armado_pushpull=700, separar cavidad,
   limpiar grasa, armadora tapa 28, liner tapa 33) — inalcanzables desde el chip-selector de
   ALL_PROCS_TAPAS, se dejaron igual por ser reglas de negocio históricas no mencionadas.
4. `METAS` + `META_DEFAULT` en dashboard.html — calcula la eficiencia real mostrada en KPIs
   ejecutivos (metaProc), lee `comanda_tareas.proceso` tal cual se guardó desde 1/2.

⚠️ Si se agrega una tarea nueva a futuro, hay que agregarla en las 4 tablas (o al menos
confirmar que cae bien en el default de 1200) — no hay fuente única, es duplicación
intencional por la arquitectura autónoma de cada HTML.

---

## Reglas de trabajo OBLIGATORIAS
1. **Diagnóstico primero**: antes de modificar cualquier archivo, mostrar diagnóstico y esperar aprobación explícita.
2. **Sin template literals anidados**: usar funciones helper separadas (ej: `buildRechazoRow(r)`).
3. **No duplicar lógica de DB** entre módulos.
4. **Confirmar archivo base** antes de editar (especialmente tapas.html — es el más largo).
5. **Git siempre a ambas ramas**: `git push origin master && git push origin master:main`
6. **Verificar referencias eliminadas**: tras borrar IDs o funciones, grep para confirmar que no quedan usos huérfanos.
7. **var sobre const/let** en funciones globales de tapas.html (evitar errores de redeclaración entre módulos cargados múltiples veces).
8. **Fecha "hoy" SIEMPRE con `fechaHoy()`** (fecha local, existe en serigrafia.html y
   registro-serigrafia.html) — NUNCA `new Date().toISOString().slice(0,10)`: devuelve la fecha
   UTC y Guatemala es UTC-6, después de las 18:00 marca el día siguiente (bug que dejó
   Productividad "vacía" en jul/2026). `toISOString()` solo es válido sobre fechas ancladas a
   mediodía (`new Date(str + 'T12:00:00')`) o para timestamps completos (updated_at).

---

## Personal (referencia — datos reales viven en la tabla `personal`)
- Tapas: T0 Heidy (supervisora en tabla `personal`, aún sin actualizar), T1-T9 operadores
  - ⚠️ Supervisora actual real: **Yenifer** — la tabla `personal` sigue sin actualizar (pendiente,
    lo hará Álvaro). registro-tapas.html YA lee el supervisor en vivo de esta tabla
    (rol='supervisor', activo=true), así que en cuanto se actualice el registro de Heidy→Yenifer
    el formulario lo reflejará automáticamente, sin tocar código.
- Serigrafía: S0 Luis Cordova (supervisor), S1-S7 operadores
