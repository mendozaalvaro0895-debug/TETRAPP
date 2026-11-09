# TETRAPP — Design System v1.0

> Leer este archivo cuando se trabaje en UI: nuevos componentes, estilos, layouts.
> El archivo compartido es `shared/styles.css`; cargarlo ANTES del `<style>` propio.

## Paleta CSS (variables en :root)
```css
--teal: #1A6B5B      --teal-l: #2A8B75    --teal-xl: #E8F5F2   --teal-dark: #134F43
--amber: #D97706
--red: #EF4444       --red-l (light)
--green: #16A34A
--prod: #B07D2A      --prod-xl: #FFFBEB
--ventas: #1D4ED8    --ventas-xl: #EFF6FF
--bodega: #0E7490    --bodega-xl: #ECFEFF
--ink: #0C0C0B       --bg: #F7F6F2        --bg2: #F0EDEA       --card: #FFFFFF
--display: Playfair Display   --sans: DM Sans   --mono: DM Mono
```

## Componentes y patrones establecidos
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

## registro-serigrafia.html — Flujos completos (rol operativo_serig)

```
scrTarea (pantalla 0, default) → 3 tarjetas: flameado / impresion / empaque

Impresión: scrSel → scrForm (contador, momentos, paros, foto) → scrOk (gráfico)
Flameado:  scrSelFlam → scrFormFlam → scrOkFlam   (tabla registro_flameado_serig)
           "otra bolsa" conserva flameador/envase/línea
Empaque:   scrSelEmp (+tarjeta "Apoyo de otra área" → ovApoyo) → scrFormEmp
           → scrOkEmp                              (tabla registro_empaque_serig)

mostrarPantalla() alterna sobre el array PANTALLAS.
buildOpCardGen(op, fn) genera tarjetas de operario para los 3 flujos.
skuDescDe(inputId) extrae {sku, descripcion} de un input con acGen.
Apoyo externo: operador_codigo=null + area_origen (tapas/produccion/bodega/otra)
— NO se agrega a la tabla personal.
Errores de guardado se muestran en recuadro rojo persistente.
```

## tapas.html — Botones de acción rápida (tabs-r)
- `+ Nueva Solicitud` → `abrirForm()`
- `📋 Comandas` → link a comandas.html
- `⬆⬇ Movimiento ▾` → dropdown con: 📤 Salida / 📦 Ingreso PT / ⛔ Registrar Rechazo
