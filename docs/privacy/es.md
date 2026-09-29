---
layout: default
title: Política de Privacidad — CLDrive
lang: es
permalink: /privacy/es/
---

# Política de Privacidad de CLDrive

**Fecha de entrada en vigor:** 29 de septiembre de 2026
**Última actualización:** 29 de septiembre de 2026
**Aplica a:** CLDrive versión 1.1.0 y posteriores

Esta Política de Privacidad describe cómo CLDrive ("la Aplicación",
"nosotros", "nuestro") maneja tu información cuando usas nuestra aplicación
para HarmonyOS.

Al instalar o usar CLDrive, aceptas las prácticas descritas en esta
política.

**🌐 Idiomas:** [English](/privacy/en/) · [Русский](/privacy/ru/) · [简体中文](/privacy/zh-Hans/) · [العربية](/privacy/ar/) · Español

[← Volver al README](/)

---

## 1. Resumen

CLDrive es un gestor de archivos en la nube para HarmonyOS. Se conecta a
servicios de almacenamiento en la nube de terceros que **tú** eliges —
Microsoft OneDrive, Google Drive y Dropbox — y te permite navegar,
organizar y transferir archivos almacenados en esos servicios.

**No operamos ningún servidor que almacene tus archivos. No recopilamos
análisis. No vendemos tus datos. No tenemos cuentas propias.**

Todos los datos manejados por CLDrive pertenecen a una de tres categorías:

| Categoría | Dónde reside | Quién puede verlo |
| :--- | :--- | :--- |
| **Tus archivos en la nube** | Tu cuenta de OneDrive / Google Drive / Dropbox | Tú y el proveedor externo |
| **Tokens de autenticación** | El sandbox cifrado de la App en tu dispositivo | Tú y la App |
| **Preferencias de la App** | El almacenamiento local de la App en tu dispositivo | Tú |

Nada sale de tu dispositivo excepto las llamadas a la API que activas
explícitamente.

---

## 2. Información a la que accedemos

### 2.1 Metadatos y contenido de archivos en la nube

Cuando inicias sesión en una cuenta en la nube, CLDrive solicita acceso de
lectura y escritura a los archivos de esa cuenta. Esto permite a la App:

- Listar el contenido de carpetas (nombres, tamaños, marcas de tiempo)
- Descargar contenido de archivos
- Subir archivos nuevos
- Renombrar, mover, copiar y eliminar archivos
- Buscar dentro de la cuenta

**Estos datos se transmiten directamente entre tu dispositivo y el
proveedor de la nube.** CLDrive nunca los intercepta, registra ni
reenvía a ningún servidor que controlemos.

### 2.2 Información de la cuenta

Al iniciar sesión, el proveedor de la nube nos envía:

- Tu nombre para mostrar
- Tu dirección de correo electrónico
- El ID de tu cuenta
- (Opcional) Una URL de foto de perfil

Esta información se almacena localmente en tu dispositivo para mostrar tu
cuenta en la barra lateral e identificar qué cuenta está activa. Nunca se
transmite a ningún lugar.

### 2.3 Tokens de autenticación

Los proveedores de la nube emiten tokens de acceso de corta duración y
tokens de actualización de larga duración después de que autorizas a
CLDrive. Estos tokens permiten a la App realizar llamadas a la API en tu
nombre sin volver a preguntarte.

Los tokens se almacenan mediante **HarmonyOS Asset Store** — el
almacenamiento seguro respaldado por hardware del sistema operativo. Están
cifrados en reposo e inaccesibles para otras aplicaciones.

---

## 3. Información que NO recopilamos

CLDrive **no** recopila, transmite ni almacena nada de lo siguiente:

- Análisis o estadísticas de uso
- Informes de fallos
- Identificadores de dispositivo (IMEI, dirección MAC, ID de publicidad)
- Datos de ubicación
- Contactos, calendario o mensajes
- Historial de navegación
- Archivos fuera de las cuentas en la nube que conectas

---

## 4. Cómo se utiliza la información

| Información | Propósito |
| :--- | :--- |
| Metadatos de archivos en la nube | Mostrar contenido de carpetas, ordenar y buscar |
| Contenido de archivos en la nube | Descargar a tu dispositivo, subir a la nube |
| Nombre y correo de la cuenta | Identificar qué cuenta está activa |
| Tokens de autenticación | Autenticar llamadas a la API del proveedor |
| Preferencias de la App | Conservar tu configuración y registro de actividad entre sesiones |

---

## 5. Uso compartido y terceros

CLDrive comparte datos solo con los proveedores de la nube que **conectas
explícitamente**:

### Microsoft OneDrive
Cuando inicias sesión en OneDrive, tu dispositivo se comunica directamente
con `graph.microsoft.com` mediante Microsoft Graph API. El tratamiento de
tus datos por parte de Microsoft se rige por la
[Declaración de privacidad de Microsoft](https://privacy.microsoft.com/privacystatement).

### Google Drive
Cuando inicias sesión en Google Drive, tu dispositivo se comunica
directamente con `googleapis.com` mediante Google Drive API. El
tratamiento de tus datos por parte de Google se rige por la
[Política de Privacidad de Google](https://policies.google.com/privacy).

### Dropbox
Cuando inicias sesión en Dropbox, tu dispositivo se comunica directamente
con `api.dropboxapi.com` y `content.dropboxapi.com` mediante Dropbox API
v2. El tratamiento de tus datos por parte de Dropbox se rige por la
[Política de Privacidad de Dropbox](https://www.dropbox.com/privacy).

**Ningún otro tercero recibe dato alguno.** CLDrive no incorpora SDK de
publicidad, bibliotecas de análisis ni servicios de telemetría.

---

## 6. Almacenamiento y retención de datos

### En tu dispositivo

| Datos | Ubicación | Retención |
| :--- | :--- | :--- |
| Tokens de autenticación | Asset Store (cifrado) | Hasta que cierres sesión o desinstales |
| Metadatos de la cuenta | Preferencias del sandbox | Hasta que cierres sesión o desinstales |
| Historial de tareas (últimas 500 operaciones) | Preferencias del sandbox | Ventana rotativa de 500 elementos |
| Archivos sin conexión | `filesDir` del sandbox | Hasta que quites sin conexión o borres la caché |
| Archivos de carga temporales | `filesDir/uploads` del sandbox | Se eliminan tras una carga exitosa, se conservan tras un fallo para reintentar |
| Preferencias de la App | Preferencias del sandbox | Hasta que desinstales |

### En proveedores de la nube

Tus archivos permanecen en tu cuenta de OneDrive, Google Drive o Dropbox
bajo sus respectivas políticas de retención.

---

## 7. Tus derechos y controles

Siempre tienes el control total de tus datos:

### Cerrar sesión en una cuenta
Abre la barra lateral → toca **Cerrar sesión**. Esto borra los tokens de
autenticación de la cuenta de Asset Store y elimina la cuenta de CLDrive.
Tus archivos en la nube no se tocan.

### Eliminar archivos sin conexión
Abre **Ajustes → Borrar caché**.

### Borrar el historial de tareas
Abre **Tareas** → usa **Borrar completadas**, **Borrar todo** o
**Borrado forzado**.

### Revocar el acceso de la App
Puedes revocar el acceso de CLDrive a tu cuenta en la nube en cualquier
momento:

- **Microsoft:** [account.live.com/consent/Manage](https://account.live.com/consent/Manage)
- **Google:** [myaccount.google.com/permissions](https://myaccount.google.com/permissions)
- **Dropbox:** [dropbox.com/account/connected_apps](https://www.dropbox.com/account/connected_apps)

### Desinstalar
Desinstalar CLDrive elimina todos los archivos, tokens y preferencias
locales de tu dispositivo.

---

## 8. Seguridad

CLDrive implementa las siguientes medidas de seguridad:

- **OAuth 2.0 con PKCE (S256)** para OneDrive, Google Drive y Dropbox
- **Sin secretos de cliente embebidos** para OneDrive y Dropbox
- **Solo HTTPS** en la comunicación con proveedores de la nube
- **Validación del parámetro state** para prevenir CSRF
- **Almacenamiento cifrado de tokens** mediante HarmonyOS Asset Store
- **Refresco automático de tokens**
- **Almacenamiento de archivos aislado en sandbox**

---

## 9. Privacidad de menores

CLDrive no está dirigido a menores de 13 años. No recopilamos
deliberadamente información personal de menores.

---

## 10. Usuarios internacionales

CLDrive almacena todos los datos localmente en tu dispositivo. Ningún dato
se transfiere a servidores operados por nosotros.

---

## 11. Cambios en esta Política

Podemos actualizar esta Política de Privacidad ocasionalmente. Los cambios
importantes se anotarán en las notas de la versión de la App.

---

## 12. Código abierto

CLDrive es de código abierto:

**[https://github.com/sharjeel-butt/CLDrive-HOS](https://github.com/sharjeel-butt/CLDrive-HOS)**

---

## 13. Contacto

- **GitHub Issues:** [https://github.com/sharjeel-butt/CLDrive-HOS/issues](https://github.com/sharjeel-butt/CLDrive-HOS/issues)

---

## 14. Declaraciones de cumplimiento

### Microsoft Graph API
El uso de Microsoft Graph por parte de CLDrive cumple con los
[Términos de uso de las API de Microsoft](https://learn.microsoft.com/en-us/legal/microsoft-apis/terms-of-use).

Permisos solicitados: `Files.ReadWrite`, `User.Read`, `offline_access`.

### Google Drive API
El uso de Google Drive por parte de CLDrive cumple con la
[Política de datos de usuario de los servicios de API de Google](https://developers.google.com/terms/api-services-user-data-policy).

**Ámbitos solicitados:** `https://www.googleapis.com/auth/drive.file`,
`https://www.googleapis.com/auth/drive.metadata.readonly`.

### Dropbox API
El uso de la API de Dropbox por parte de CLDrive cumple con los
[Términos y condiciones de la API de Dropbox](https://www.dropbox.com/developers/reference/terms).

**Ámbitos solicitados:** `account_info.read`, `files.metadata.read`,
`files.metadata.write`, `files.content.read`, `files.content.write`.

---

*Esta política se aplica a CLDrive versión 1.1.0 y posteriores.*