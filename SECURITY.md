# TETRAPP — Guía de Seguridad

**Empresa:** Tetraplastic · Guatemala  
**Sistema:** Control Digital de Producción y Procesos  
**Responsable:** Álvaro Mendoza (Administrador)  
**Última revisión:** 2026-10-09 (auditoría: endpoints de IA con sesión obligatoria + XSS feriados)

---

## 1. Arquitectura de seguridad activa

| Capa | Mecanismo | Estado |
|---|---|---|
| Autenticación | Supabase Auth (email + contraseña) · login.html obligatorio | ✅ |
| Autorización | RLS por rol: anónimo=nada · visor=solo lectura · master=todo | ✅ (tras correr `sql/seguridad_v1.sql`) |
| Roles | Tabla `perfiles` (master / visor) · helpers `rol_actual()` / `es_master()` | ✅ |
| Guardián frontend | `shared/auth.js` en todos los HTML — redirige a login sin sesión | ✅ |
| Anti-XSS | `escHtml()` global (auth.js) aplicado a datos dinámicos en todos los módulos | ✅ |
| Transporte | HSTS · HTTPS forzado 2 años | ✅ |
| CSP | Content-Security-Policy en `vercel.json` (solo self + Supabase + CDNs) | ✅ |
| Protección de interfaz | X-Frame-Options DENY · frame-ancestors 'none' · nosniff | ✅ |
| Permisos de browser | Permissions-Policy: cámara/mic/geo/pago bloqueados | ✅ |
| Endpoints de IA (`api/parse-*`) | Sesión obligatoria + rol vía `api/_auth.js` (no se gastan tokens de Claude sin login) | ✅ (oct/2026) |
| Bot WhatsApp (`api/whatsapp.js`) | Firma `X-Twilio-Signature` HMAC-SHA1, fail-closed · allowlist `TETRA_WA_ALLOW` | ✅ (requiere `TWILIO_AUTH_TOKEN` en Vercel) |

---

## 2. Modelo de acceso

```
Sin sesión        →  redirigido a login.html · la API no responde nada (RLS)
visor@tetrapp.app →  ve todo, no puede editar NADA (RLS + bloqueo de fetch en cliente)
master@tetrapp.app→  acceso total (Álvaro Mendoza)
operativo / supervisor_tapas → encerrados en registro-tapas.html · solo INSERT de comandas
operativo_serig   →  encerrado en registro-serigrafia.html · solo INSERT de sus registros
operativo_prod    →  ve todo en lectura · escribe solo produccion_diaria y el Recetario
```
Detalle y tablas exactas por rol: CLAUDE.md § "Roles de acceso". Los roles de planta
están exentos del cierre de sesión por inactividad (pantallas compartidas en planta).

- La protección REAL vive en las políticas RLS de Supabase. El bloqueo del
  frontend (banner "Modo Visual" + intercepción de fetch) es solo experiencia
  de usuario: aunque se salte, el servidor rechaza la escritura.
- Un usuario autenticado SIN fila en `perfiles` no puede leer nada y el
  guardián le cierra la sesión (`login.html?e=noperfil`).
- El registro público de usuarios debe estar DESACTIVADO:
  Dashboard → Authentication → Sign In / Up → "Allow new users to sign up" = OFF.

### Crear un usuario nuevo
1. Dashboard → Authentication → Users → Add user (email + contraseña, Auto Confirm ✓)
2. SQL Editor: `insert into perfiles (user_id, rol, nombre) select id, 'visor', 'Nombre' from auth.users where email = 'nuevo@tetrapp.app';`

---

## 3. Claves y credenciales

```
anon/public key  →  frontend HTML (seguro exponerla: sin sesión no da acceso a nada)
service_role key →  NUNCA en código frontend · solo backend/scripts internos
```

- La anon key vive en `shared/auth.js` y `login.html` (y como respaldo en `api/_auth.js`).
- Rotación: Supabase Dashboard → API Keys → Regenerate → actualizar esos archivos.
- Secretos del servidor SOLO como variables de entorno de Vercel (nunca en el repo):
  `ANTHROPIC_API_KEY`, `SUPA_SERVICE_KEY` (solo la usa el bot), `TWILIO_AUTH_TOKEN`,
  `TETRA_WA_ALLOW`, `TWILIO_WEBHOOK_URL`.

---

## 4. Reglas para desarrollo

```
✅ HACER:
  - Incluir <script src="shared/auth.js"></script> en TODA página nueva
    (después del CDN de supabase-js, antes del script propio)
  - Usar escHtml() en TODO texto dinámico insertado con innerHTML
  - Toda tabla nueva queda protegida por el patrón de políticas de
    sql/seguridad_v1.sql — correr la sección D para la tabla nueva
  - Los fetch crudos a la API deben usar HEADERS (auth.js lo mantiene con el token)
  - Todo endpoint nuevo en api/ que gaste tokens o lea datos: validar sesión con
    rolDeSesion() de api/_auth.js y enviar Authorization: HEADERS.Authorization desde el front
  - escHtml() también en atributos (title="", value="") — no solo en el contenido

❌ NO HACER:
  - Declarar SUPA_URL/SUPA_KEY/db/HEADERS en las páginas (vienen de auth.js)
  - Poner la service_role key en ningún archivo HTML
  - innerHTML con datos sin escHtml() (riesgo XSS)
  - Crear políticas RLS con `TO anon` — el rol anónimo no debe tener acceso
  - Usar eval() o new Function() con datos externos
```

---

## 5. Configuración de infraestructura

### Supabase (rohdxjuuvpgrhevfsrye)
- **RLS**: por rol en todas las tablas (`sql/seguridad_v1.sql`)
- **anon**: sin privilegios sobre tablas, vistas, secuencias ni funciones
- **RPCs** `descontar_inventario`/`aumentar_inventario`: security invoker, solo authenticated
  (descontar recorta en 0; aumentar crea el SKU si no existe — ver CLAUDE.md § RPCs atómicas)
- **Signups públicos**: OFF

### Vercel (tetrapp.vercel.app)
- Headers de seguridad + CSP en `vercel.json` (incluye `worker-src` para pdf.js)
- Funciones serverless en `api/` (ver CLAUDE.md § Funciones serverless); secretos por env vars
- Deploy auto desde rama `main` — cada push a main sale directo a producción

---

## 6. Respuesta ante incidentes

### Bloquear un usuario de inmediato
Dashboard → Authentication → Users → (usuario) → Ban user.
Su fila en `perfiles` puede borrarse para revocar lectura aunque conserve sesión.

### Si sospechas que una contraseña fue comprometida
1. Dashboard → Authentication → Users → Reset password
2. Revisar Logs → API por actividad anómala

### Si detectas acceso no autorizado a datos
1. Supabase Dashboard → Logs → revisar IPs y patrones
2. Si es necesario: pausar proyecto (Settings → Pause project)
3. Documentar el incidente con fecha, tabla afectada y datos expuestos

### Contacto de seguridad
Reportar incidentes a: **mendozaalvaro0895@gmail.com**

---

## 7. Roadmap de seguridad

| Fase | Mejora | Prioridad |
|---|---|---|
| Siguiente | Confirmar `TWILIO_AUTH_TOKEN` en Vercel env vars | 🔴 Alta |
| Siguiente | Ajuste de inventario de la Central de Ingreso: RPC atómica que permita negativos | 🟡 Media |
| Fase 3 | Log de auditoría: quién cambió qué y cuándo | 🟡 Media |
| Fase 3 | Límite de uso (rate limiting) en `api/parse-*` vía Vercel Firewall | 🟢 Futura |
| ✅ Hecho | `ajustarExistencia()` de tapas/serigrafía usa RPCs atómicas · roles operativos con permisos parciales · endpoints de IA con sesión · RLS activo en TODAS las tablas públicas (verificado 2026-10-09, incluida `rechazos`) | — |
