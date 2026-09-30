---
layout: default
title: CLDrive Manager — Español
lang: es
permalink: /readme/es/
---

# CLDrive Manager

**Un gestor de archivos en la nube unificado para HarmonyOS.**

CLDrive Manager reúne OneDrive, Google Drive y Dropbox en un único navegador de
archivos coherente. Gestiona todas tus cuentas en la nube desde una sola
aplicación nativa de HarmonyOS — con operaciones entre proveedores,
autenticación segura PKCE y una arquitectura extensible que hace que
añadir un nuevo proveedor sea cuestión de escribir una clase.

**Versión actual:** 1.2.1

---

**🌐 Idiomas:** [English](https://sharjeel-butt.github.io/CLDrive-HOS/readme/en/) · [Русский](https://sharjeel-butt.github.io/CLDrive-HOS/readme/ru/) · 简体中文 · [العربية](https://sharjeel-butt.github.io/CLDrive-HOS/readme/ar/) · [Español](https://sharjeel-butt.github.io/CLDrive-HOS/readme/es/)

**📄 [Política de Privacidad](/privacy/es/)** · [Código fuente](https://sharjeel-butt.github.io/CLDrive-HOS/privacy/es/)

---

## ✨ Características

### Multi-cuenta, multi-proveedor
- Inicia sesión con cuentas ilimitadas de OneDrive, Google Drive y Dropbox
- Árbol lateral que agrupa las cuentas por proveedor
- Cambia entre cuentas con un solo toque
- Avatar, nombre para mostrar y correo electrónico por cuenta

### Navegador de archivos unificado
- Vista de lista coherente en todos los proveedores
- Navegación de carpetas con ruta de navegación
- Metadatos de archivo: nombre, tamaño, fecha de modificación, icono por tipo
- Actualización por deslizamiento, estados de carga y manejo de errores
- Búsqueda en la cuenta activa
- Extensiones de archivo autogeneradas según el tipo MIME

### Operaciones de archivos

| Operación | OneDrive | Google Drive | Dropbox |
|---|:---:|:---:|:---:|
| Explorar carpetas | ✅ | ✅ | ✅ |
| Crear carpeta | ✅ | ✅ | ✅ |
| Renombrar | ✅ | ✅ | ✅ |
| Mover | ✅ | ✅ | ✅ |
| Copiar | ✅ | ✅ | ✅ |
| Eliminar | ✅ | ✅ | ✅ |
| Descargar | ✅ | ✅ | ✅ |
| Subir | ✅ | ✅ | ✅ |
| Subida reanudable | ✅ | ✅ | ✅ |
| Buscar | ✅ | ✅ | ✅ |

### Selección múltiple y operaciones por lotes
- Mantén pulsado cualquier elemento para entrar en modo de selección
- Seleccionar todo / Deseleccionar todo
- Eliminar, mover, copiar y descargar por lotes
- Resolución de conflictos: Omitir todo / Mantener ambos / Reemplazar todo
- Barra de acciones de selección en orden: **Copiar · Mover · Descargar · Eliminar**

### Panel de tareas
- Progreso en vivo para subidas, descargas, movimientos, copias y eliminaciones
- Cuatro pestañas: **Todas · Pendientes · Hechas · Fallidas**
- Pendientes muestra todo el lote en cola antes de que comience la ejecución
- Operaciones agrupadas por fecha (Hoy / Ayer / fechas específicas)
- El historial persiste entre reinicios (hasta 500 tareas recientes)
- Barras de progreso por elemento para transferencias
- **Reintento** para tareas fallidas (↻ por fila y Reintentar todo)
- El icono de actividad de la barra superior refleja el estado:
    - **Azul** — tarea(s) en ejecución
    - **Gris** — inactivo, sin historial
    - **Verde** — todas las tareas tuvieron éxito
    - **Amarillo** — éxito y fallo mezclados
    - **Rojo** — todas las tareas fallaron

### Acceso sin conexión
- Marca cualquier archivo como **Disponible sin conexión**
- Archivos almacenados en el sandbox privado de la app
- Abre archivos sin conexión con el visor predeterminado del sistema
- Resumen de uso de almacenamiento y borrado de caché en Ajustes

### Apariencia
- Claro, Oscuro y Usar ajustes del sistema
- Preferencia de usuario persistente
- Soporte completo de tema en cada pantalla, incluido el WebView de OAuth

### Seguro por diseño
- Flujo de código de autorización OAuth 2.0 con PKCE (S256)
- Sin secretos de cliente incrustados (OneDrive y Dropbox usan PKCE puro)
- Tokens en HarmonyOS Asset Store (divididos en fragmentos para eludir el límite de 1024 bytes)
- Refresco automático de tokens al caducar
- Validación del parámetro state para prevenir CSRF
- El selector multiarchivo copia archivos a un sandbox temporal antes de subir, de modo que los reintentos funcionan entre reinicios

---

## 🏗️ Arquitectura

CLDrive Manager se construye alrededor de una abstracción de proveedor. La capa
de UI nunca toca una API específica de proveedor — habla con interfaces,
y la fábrica proporciona la implementación correcta en tiempo de ejecución.


Contratos clave:

- **`ICloudProvider`** — interfaz unificada que implementa cada proveedor
- **`IAuthProvider`** — contrato OAuth
- **`CloudItem`** — modelo unificado de archivo/carpeta (nunca expone DTOs del proveedor)
- **`DownloadInfo`** — URL + cabeceras para la autenticación de descarga

Cada proveedor vive en su propia carpeta con **Provider**, **AuthProvider**,
**ApiClient**, **Mapper** y **Config**.

---

## 🔐 Autenticación y seguridad

- **Flujo de código de autorización OAuth 2.0 con PKCE (S256)** para los tres proveedores
- **Sin secretos de cliente** en los binarios de OneDrive y Dropbox
- Google requiere un secreto de cliente por su tipo de cliente OAuth "Web application"
- Tokens en **HarmonyOS Asset Store**, divididos a 900 bytes para eludir el límite de 1024 bytes
- `TokenRefresher` maneja 401 de forma transparente con auto-refresco
- La validación del parámetro state previene CSRF
- Comunicación solo por HTTPS

---

## 📦 Primeros pasos

### Requisitos previos
- DevEco Studio 26.0.0 o posterior
- HarmonyOS API 26 SDK
- Una cuenta de desarrollador de Microsoft, Google o Dropbox

### Registra tus propias apps OAuth

CLDrive Manager es un cliente OAuth público y cada usuario registra su propia app
en las tres consolas de proveedores. Esto mantiene a cada usuario en
control total de sus propias credenciales.

**Azure (OneDrive)**
1. Azure Portal → Registros de aplicaciones → Nuevo registro
2. Tipos de cuenta compatibles: Multiinquilino + cuentas personales de Microsoft
3. URI de redirección: plataforma Móvil y escritorio → `https://cl.drive/oauth`
4. Configuración avanzada → Permitir flujos de cliente público: **Sí**
5. Permisos delegados: `Files.ReadWrite`, `User.Read`, `offline_access`

**Google Cloud (Google Drive)**
1. Google Cloud Console → APIs y servicios → Credenciales → Crear cliente OAuth
2. Tipo de aplicación: **Aplicación web**
3. URI de redirección autorizado: `http://127.0.0.1:8080/oauth2redirect`
4. Habilita la Google Drive API

**Dropbox**
1. Dropbox App Console → Crear app
2. Scoped access → Full Dropbox
3. OAuth 2.0 → URIs de redirección → `https://cl.drive/dropbox-oauth`
4. Permisos: `account_info.read`, `files.metadata.read`,
   `files.metadata.write`, `files.content.read`, `files.content.write`

### Compilar

```bash
git clone https://github.com/sharjeel-butt/CLDrive Manager-HOS
cd CLDrive Manager-HOS
# Abre en DevEco Studio, luego ejecuta en un dispositivo o emulador

🗺️ Hoja de ruta
☑ Soporte de OneDrive
☑ Soporte de Google Drive
☑ Soporte de Dropbox
☑ Barra lateral multi-cuenta
☑ Temas Claro / Oscuro / Sistema
☑ Panel de tareas con persistencia
☑ Archivos sin conexión
☑ Mecanismo de reintento
☑ UI en 22 idiomas
□ Proveedor WebDAV
□ Proveedor S3
□ Proveedor Box
📄 Licencia y privacidad
Política de Privacidad — Español

Código fuente — github.com/sharjeel-butt/CLDrive Manager-HOS

Issues — github.com/sharjeel-butt/CLDrive Manager-HOS/issues