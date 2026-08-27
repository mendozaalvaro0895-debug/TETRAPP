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
Cada HTML es AUTÓNOMO: CSS en `<style>`, funciones y datos inline. El cliente `db` y los
helpers de sesión/roles los provee `shared/auth.js`. `shared/styles.css` es el único archivo
de estilos compartido — se carga en todos los HTML como
`<link rel="stylesheet" href="shared/styles.css">` ANTES del `<style>` propio.

### Funciones serverless (Vercel) — carpeta `api/`
Node.js del lado servidor; secretos SOLO por `process.env.*` (nunca hardcodeados).
- `api/whatsapp.js` — bot WhatsApp (Twilio → Claude → INSERT con **service_role**, salta RLS).
  ⚠️ Valida firma `X-Twilio-Signature` (HMAC-SHA1, fail-closed) — sin `TWILIO_AUTH_TOKEN` rechaza TODO POST.
  Env: ANTHROPIC_API_KEY, SUPA_URL, SUPA_SERVICE_KEY, TWILIO_AUTH_TOKEN (obligatorio), TWILIO_WEBHOOK_URL, TETRA_WA_ALLOW.
- `api/parse-doc.js` — parsea foto de requi con Claude Vision → JSON {requi, fecha, productos[]}.
  ⚠️ PENDIENTE: CORS `*` + sin auth → gasto de tokens de Claude. Falta gatear con JWT de sesión.

### Módulos activos
| Archivo | Descripción |
|---|---|
| `index.html` | Fachada principal — 6 cards de módulo |
| `tapas.html` | Módulo completo Tapas: hub + pedidos + movimientos (salidas/ingresos/rechazos) + personal |
| `serigrafia.html` | Módulo admin Serigrafía: Inicio (board) + Movimientos + Productividad + Personal |
| `registro-serigrafia.html` | Formulario móvil rol `operativo_serig`: Flameado / Impresión / Empaque |
| `comandas.html` | Registro de producción diaria por operario (vista admin) |
| `registro-tapas.html` | Formulario móvil rol `operativo`: comanda concluida, correlativo CMD-### vía trigger DB |
| `dashboard.html` | KPIs ejecutivos globales |
| `inventario.html` | Gestión de SKUs, existencias, importación Excel |
| `ventas.html` | Ventas y Financiero: Resumen · Productos · Clientes · Rotación · Importar facturación (Excel/CSV cols A-R) · toggle IVA |
| `produccion.html` | Sopladoras: Ingreso PDF/manual (pdf.js) · Reporte Semanal (pivote máquina×SKU) · Mensual |

Bodega bloqueado via `<a class="nav-locked">` en toda la navegación.

---

## Design System v1.0
Ver paleta CSS, componentes y patrones completos: `.claude/docs/design-system.md`
Regla: cargar `shared/styles.css` ANTES del `<style>` propio en todo HTML.

---

## tapas.html — Arquitectura de vistas

```
switchTab(tab) controla qué view se muestra.
'rechazos' es ALIAS → switchTab('movimientos') + setMovVista('rechazos')

view-inicio      HUB default: 4 KPIs + 5 sub-cards (Pedidos/Procesos/Personal/Rechazos/Dashboard)
view-tapas       Solicitudes — split pane: lista + detalle
view-movimientos Segmented control de 3:
  [📤 Salidas de Bodega] [📦 Ingresos PT] [⛔ Rechazos]
  Comparten: movDesde/movHasta, movBuscar, kpi-strip (mkpi-v1..v4), movTabla
  setMovVista('salida'|'ingreso'|'rechazos') actualiza todo
  movRegistrar() delega a abrirModalMov() o abrirModalRechazo()
view-personal    Grid de operadores
```

## serigrafia.html — Arquitectura de vistas

```
Tabs: Inicio · Movimientos · Productividad · Personal · Dashboard (link)
view-productividad: si la fecha está vacía, buildUltimasLecturasHint() muestra las últimas
  10 lecturas clicables para saltar a su fecha — distingue "base vacía" de "fecha equivocada"
```

### Estados de ficha — SOLO 4 (`ESTADOS_SERIG`)
`nueva` ⚪ → `proceso` 🔵 → `parcial` 🟡 → `lista` 🟢
**`lista` = ENTREGADO / COMPLETADO** — estado final, pinta la ficha de verde con badge
COMPLETADO. NO existen `programada` ni `entregada` (eliminados 2026-08-19; constraints
en `sql/solicitudes_parcial_constraint.sql`).

⚠️ El estado vive en DOS tablas y la tarjeta lee `l.estado || s.estado` — la LÍNEA gana.
Escribir solo en `solicitudes` guarda el cambio pero **no se ve**. Usar siempre
`syncEstado(s, estado)`, que actualiza `solicitudes` + todas sus `solicitud_lineas`.

Transiciones automáticas en `boardDrop()`:
- Entra a línea de producción → `proceso`
- Vuelve a Sin Asignar → `estadoPorEntregas(s)`: 0 entregas=`nueva` · parcial=`parcial` · completa=`lista`
- Una ficha ya en `lista` nunca se degrada al moverla

**Entregas**: la única fuente son las requis manuales vinculadas a la ficha
(`getEntregasManuales()`). El estado NO cuenta como entrega — sumarlo duplicaba unidades.

Tier de color: `lista`=2 verde · `parcial`=1 amarillo · resto=0 rojo.
Orden dentro de cada desplegable: rojo → amarillo → verde.

## registro-serigrafia.html — Flujos
Ver flujos completos y componentes en `.claude/docs/design-system.md` § Flujos.
Pantallas: `scrTarea(0)` → Impresión / Flameado / Empaque → `scrOk*`.
`mostrarPantalla()` · `buildOpCardGen()` · apoyo externo: `operador_codigo=null + area_origen`.

---

## Tablas Supabase (schema v2.0)
Ver descripciones completas: `.claude/docs/schema-tablas.md`

Notas críticas:
- `produccion_diaria`: llave única incluye `documento` — un turno puede tener varias requis con cantidades que se SUMAN
- `inventario`: +3 cols producción: `meta_12hrs`, `maquina_default`, `precio_ponderado_manual`
- `personal`: fuente única de supervisores — registro-tapas.html NO los hardcodea
- `ventas`: fecha→DATE, RLS master-only escritura; importador reemplaza por rango de fechas (sin duplicar)
- `bot_estado`: 1 fila por número (`whatsapp_from` UNIQUE)
- `rechazos`: existe, RLS pendiente (sql/rechazos_rls_fix.sql)

### RPCs atómicas
- `descontar_inventario(p_sku, p_cantidad)` — usar en lugar de select+update manual
- `aumentar_inventario(p_sku, p_cantidad)` — ídem

---

## SQL pendiente de correr en Supabase (dashboard → SQL Editor)
1. `sql/rechazos_rls_fix.sql` — activa RLS en tabla rechazos
2. `sql/operativo_tapas_v1.sql` — rol `operativo` + usuario tapas@tetrapp.app + políticas INSERT + trigger CMD-###
3. `sql/registro_procesos_serig_v1.sql` — crea registro_flameado_serig + registro_empaque_serig con RLS
4. `sql/ventas_financiero_v1.sql` — prepara tabla `ventas`: familia/codigo_cliente, fecha→DATE, RLS master
5. `sql/produccion_v1.sql` — crea `produccion_diaria` + cols meta_12hrs/maquina_default/precio_ponderado_manual
6. `sql/produccion_seed_historico.sql` — histórico Sheets (831 líneas, 5-may→6-jun, documento='SHEETS').
   Correr DESPUÉS del 5. ⚠️ Si luego subes PDF de un turno ya sembrado, borra primero sus líneas con documento='SHEETS'
7. `sql/sku_especificaciones_v1.sql` — tabla `sku_especificaciones` (ficha técnica extensible por
   SKU+área: Fase 2 del Recetario unificado — peso/material/colorante en Producción, tiros/colores/
   fórmula de tinta en Serigrafía, familia/accesorios en Tapas). RLS igual a `sku_recetas` (master).
8. `sql/operativo_produccion_v1.sql` — rol `operativo_prod` + usuario produccion@tetrapp.app +
   políticas insert/update/delete en produccion_diaria. Correr DESPUÉS del 5 (necesita la tabla).

### SQL ya corridos (solo si necesitas re-correr)
- `sql/seguridad_v1.sql` ⚠️ Su sección C borra TODAS las políticas y recrea solo las genéricas — después hay que re-correr los fix específicos (insert_operativo_serig etc.)
- `sql/fix_rls_serig_v2.sql` — reparó registro_tiros_serig RLS + columna hora + CHECK velada
- `sql/solicitudes_parcial_constraint.sql` (19-ago-2026) — CHECK de estado en `solicitudes`
  y `solicitud_lineas` limitado a los 4 oficiales; habilita `parcial`, elimina `programada`/`entregada`
- `sql/sku_recetario_fotos_v1.sql` (24-ago-2026) — columna `foto_url` en `sku_recetas` + bucket Storage `envases`

---

## Seguridad — estado
Sólido: sin secretos hardcodeados; CSP + HSTS + X-Frame-Options en vercel.json; auth.js centralizado; anon sin privilegios; api/whatsapp.js valida firma Twilio (fail-closed).
⚠️ Pendiente: `api/parse-doc.js` CORS `*` sin auth → tokens expuestos. `TWILIO_AUTH_TOKEN` debe existir en Vercel env vars.

## Roles de acceso (shared/auth.js)
- `master` → todo · `visor` → solo lectura (banner Modo Visual)
- `operativo` → enjaulado en registro-tapas.html; INSERT solo en comandas/comanda_tareas
- `operativo_serig` → enjaulado en registro-serigrafia.html; INSERT en registro_tiros_serig, paros_serig, registro_flameado_serig, registro_empaque_serig
- `operativo_prod` → NO enjaulado: ve TODOS los módulos en lectura (como visor), pero solo escribe en produccion_diaria (registrar turnos). auth.js bloquea escrituras a otras tablas (flag TETRA.esProdEditor + TETRA_PROD_TABLA); RLS lo respalda. Exento de logout por inactividad. NO edita recetas/fichas (solo-master)
- La jaula vive en TETRA_PAGINAS_OPERATIVO (auth.js): rol → página permitida
- Sesiones expiran a 60 min de inactividad, EXCEPTO roles operativos (pantallas de planta)

---

## Metas de productividad — CUATRO tablas, sincronizadas jul/2026
Valores oficiales (und/hora):
- Armado, Liner, Banda (manual): **1500** · Encajado: **3000**
- Flameado, Impresión: **1500** · Armado, Liner (máquina — Press Top 28/33): **2500**
- Resto (Revisado, Limpiar pestaña, Apoyo Serig, Apoyo Prod, Otra tarea, sin meta): **1200**

Las 4 copias (misma lógica, autónomas por arquitectura):
1. `CAPACIDADES` en registro-tapas.html — rol operativo
2. `CAPACIDADES` en comandas.html — vista admin
3. `METAS` + `META_DEFAULT` en tapas.html — estima tiempo de entrega de solicitudes
4. `METAS` + `META_DEFAULT` en dashboard.html — calcula eficiencia real en KPIs ejecutivos

⚠️ Al agregar una tarea nueva: actualizarla en las 4 tablas (o confirmar que cae en default 1200).

---

## Reglas de trabajo OBLIGATORIAS
1. **Diagnóstico primero**: antes de modificar cualquier archivo, mostrar diagnóstico y esperar aprobación explícita.
2. **Sin template literals anidados**: usar funciones helper separadas (ej: `buildRechazoRow(r)`).
3. **No duplicar lógica de DB** entre módulos.
4. **Confirmar archivo base** antes de editar (especialmente tapas.html — es el más largo).
5. **Git siempre a ambas ramas**: `git push origin master && git push origin master:main`
6. **Verificar referencias eliminadas**: tras borrar IDs o funciones, grep para confirmar que no quedan usos huérfanos.
7. **var sobre const/let** en funciones globales de tapas.html (evitar errores de redeclaración entre módulos cargados múltiples veces).
8. **Fecha "hoy" SIEMPRE con `fechaHoy()`** — NUNCA `new Date().toISOString().slice(0,10)`: devuelve fecha UTC y Guatemala es UTC-6, después de las 18:00 marca el día siguiente. `toISOString()` solo válido sobre fechas ancladas a mediodía o para timestamps completos.

---

## Personal
⚠️ Supervisora actual real tapas: **Yenifer** (tabla `personal` aún dice Heidy — pendiente Álvaro).
registro-tapas.html lee supervisor en vivo → se corregirá solo al actualizar el registro.
Serigrafía: S0 Luis Cordova (supervisor), S1-S7 operadores.
