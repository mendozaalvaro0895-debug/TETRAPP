# TETRAPP — Guía de Seguridad

**Empresa:** Tetraplastic · Guatemala  
**Sistema:** Control Digital de Producción y Procesos  
**Responsable:** Álvaro Mendoza (Administrador)  
**Última revisión:** 2026-06-25

---

## 1. Arquitectura de seguridad activa

| Capa | Mecanismo | Estado |
|---|---|---|
| Transporte | HSTS · HTTPS forzado 2 años | ✅ |
| Autenticación de API | Supabase anon key (requerida en toda petición) | ✅ |
| Autorización de datos | RLS habilitado en 14 tablas | ✅ |
| Protección de interfaz | X-Frame-Options DENY · CSP estricto | ✅ |
| Filtro de orígenes | Content-Security-Policy → solo Supabase + cdnjs | ✅ |
| Rate limiting | Supabase 500 req/s · Vercel DDoS protection | ✅ |
| Permisos de browser | Permissions-Policy: cámara/mic/geo/pago bloqueados | ✅ |

---

## 2. Claves y credenciales

### Regla absoluta: dos keys, dos roles

```
anon/public key  →  frontend HTML (seguro exponerla, protegida por RLS)
service_role key →  NUNCA en código frontend · solo backend/scripts internos
```

### Dónde están las claves
- **anon key**: visible en cada archivo HTML (es intencional y seguro)
- **service_role key**: solo en Supabase Dashboard → Project Settings → API Keys

### Rotación de claves
- Rotar la anon key si se sospecha compromiso: Supabase Dashboard → API Keys → Regenerate
- Actualizar en todos los archivos HTML después de rotar
- Frecuencia recomendada: cada 6 meses o ante incidente

---

## 3. Reglas para desarrollo

### Al crear una nueva página HTML

```
✅ HACER:
  - Copiar el cliente Supabase desde una página existente (mismo patrón)
  - Usar escHtml() o equivalente en TODO texto dinámico del usuario
  - Habilitar RLS en cualquier tabla nueva antes de exponer al frontend
  - Validar inputs en el cliente Y en la política RLS

❌ NO HACER:
  - Poner la service_role key en ningún archivo HTML
  - Usar innerHTML con datos sin sanitizar (riesgo XSS)
  - Hacer .limit() en queries de inventario (bug conocido: oculta SKUs)
  - Crear tablas sin RLS (quedan expuestas públicamente)
  - Usar eval() o new Function() con datos externos
```

### Al crear una nueva tabla en Supabase

```sql
-- Siempre incluir estas dos líneas después de CREATE TABLE:
ALTER TABLE nueva_tabla ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tetra_anon_all" ON nueva_tabla
  FOR ALL TO anon USING (true) WITH CHECK (true);
```

### Inputs del usuario

Siempre escapar antes de insertar en el DOM:
```javascript
function escHtml(str) {
  return String(str || '').replace(/&/g,'&amp;').replace(/</g,'&lt;')
                          .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
```

---

## 4. Vulnerabilidades conocidas y estado

| # | Descripción | Impacto | Estado |
|---|---|---|---|
| 1 | `movimientos_materiales`: columnas `sku`/`usuario` incorrectas | Trazabilidad rota | 🔴 Pendiente |
| 2 | `cargarInventario()` con `.limit(200)` en tapas + serigrafía | 92% SKUs invisibles | 🔴 Pendiente |
| 3 | RPCs `descontar_inventario()` nunca llamadas | Existencia no se ajusta | 🟡 Pendiente |
| 4 | Sin autenticación de usuarios | Cualquiera con URL accede | 🟡 Fase 2 |
| 5 | `shared/` tiene 5 archivos huérfanos | Confusión de código | 🟢 Menor |

---

## 5. Configuración de infraestructura

### Supabase (rohdxjuuvpgrhevfsrye)
- **RLS**: habilitado en todas las tablas ✅
- **Data API**: activa, auto-expose nuevas tablas = OFF ✅
- **Plan**: Free (suficiente hasta ~50 usuarios simultáneos)

### Vercel (tetrapp.vercel.app)
- **Deploy**: auto desde rama `main` en GitHub
- **Headers**: configurados en `vercel.json`
- **HTTPS**: forzado por HSTS
- **Plan**: Free (suficiente para fase actual)

### GitHub (mendozaalvaro0895-debug/TETRAPP)
- **Rama producción**: `main`
- **Rama desarrollo**: `master` → merge a `main` en cada feature
- Nunca subir archivos `.env` ni credenciales al repo

---

## 6. Respuesta ante incidentes

### Si sospechas que la API key fue comprometida
1. Supabase Dashboard → API Keys → **Regenerate anon key**
2. Actualizar la key en todos los archivos HTML
3. Push a GitHub → Vercel auto-despliega
4. Revisar logs en Supabase → Logs → API

### Si detectas acceso no autorizado a datos
1. Supabase Dashboard → Logs → revisar IPs y patrones
2. Si es necesario: pausar proyecto (Settings → Pause project)
3. Documentar el incidente con fecha, tabla afectada, y datos expuestos

### Contacto de seguridad
Reportar incidentes a: **mendozaalvaro0895@gmail.com**

---

## 7. Roadmap de seguridad

| Fase | Mejora | Prioridad |
|---|---|---|
| Fase 1 (actual) | Migrar toda data crítica de localStorage a Supabase | 🔴 Alta |
| Fase 1 (actual) | Corregir bugs de trazabilidad (#1 y #2) | 🔴 Alta |
| Fase 2 | Autenticación con magic link (Supabase Auth) | 🟡 Media |
| Fase 2 | RLS por usuario: cada operador solo ve su data | 🟡 Media |
| Fase 2 | Cloudflare delante de Vercel (rate limiting por IP) | 🟡 Media |
| Fase 3 | Log de auditoría: quién cambió qué y cuándo | 🟢 Futura |
| Fase 3 | Roles: admin / supervisor / operador | 🟢 Futura |
