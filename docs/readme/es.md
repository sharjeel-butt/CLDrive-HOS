# CLDrive

**Un gestor unificado de archivos en la nube para HarmonyOS.**

CLDrive reúne OneDrive, Google Drive y Dropbox en un único explorador de archivos coherente. Gestiona todas tus cuentas en la nube desde una sola aplicación nativa de HarmonyOS — con operaciones entre proveedores, autenticación PKCE segura y una arquitectura extensible que hace que añadir nuevos proveedores sea cuestión de escribir una sola clase.

**Versión actual:** 1.4.0

---

**🌐 Idiomas:** Inglés · [Ruso](/CLDrive-HOS/readme/ru/) · [Chino simplificado](/CLDrive-HOS/readme/zh-Hans/) · [Árabe](/CLDrive-HOS/readme/ar/) · [Español](/CLDrive-HOS/readme/es/)

**📄 [Política de privacidad](/CLDrive-HOS/privacy/en/)** · [Código fuente](https://github.com/sharjeel-butt/CLDrive-HOS)

---

## ✨ Características

### Multicuenta, multiproveedor
- Inicia sesión con un número ilimitado de cuentas de OneDrive, Google Drive y Dropbox
- El árbol de la barra lateral agrupa las cuentas por proveedor
- Cambia entre cuentas con un solo toque
- Avatar, nombre visible y correo electrónico por cuenta
- Cierra sesión directamente desde la fila de la cuenta activa

### Explorador de archivos unificado
- Experiencia coherente en todos los proveedores
- **Diseños de lista y cuadrícula** con alternancia de un toque en la barra superior
- Navegación de carpetas con ruta de navegación en la que se puede hacer clic
- **Chips de filtro**: Todo · Imágenes · Vídeos · Documentos · Audio · Otros
- **Menú de ordenación**: Nombre (A–Z / Z–A), Más recientes, Más antiguos, Más grandes
- Metadatos del archivo: nombre, tamaño, marca de tiempo relativa, icono específico del tipo
- Miniaturas reales cuando el proveedor las proporciona; en caso contrario, insignias FileIcon
- La insignia **Compartido** marca archivos y carpetas que no te pertenecen
- Deslizar para actualizar, estados de carga y manejo de errores
- Búsqueda en la cuenta activa con consultas con retardo (debounce)
- Extensiones de archivo rellenadas automáticamente a partir del tipo MIME

### Operaciones con archivos

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
- Mantén pulsado cualquier elemento para entrar en el modo de selección
- Seleccionar todo / Deseleccionar todo
- Eliminar, mover, copiar y descargar por lotes
- Resolución de conflictos: Omitir todo / Conservar ambos / Reemplazar todo
- Barra de acciones de selección ordenada: **Copiar · Mover · Descargar · Eliminar**

### Panel de tareas
- Progreso en vivo para subidas, descargas, movimientos, copias y eliminaciones
- Cuatro pestañas: **Todas · Pendientes · Completadas · Fallidas**
- Pendientes muestra todo el lote en cola antes de que comience la ejecución
- Operaciones agrupadas por fecha (Hoy / Ayer / fechas específicas)
- El registro histórico persiste tras reiniciar la aplicación (hasta 500 tareas recientes)
- Indicadores de progreso circulares por elemento para las transferencias
- Compatibilidad con **reintentos** para tareas fallidas (↻ en cada fila y Reintentar todo)
- El icono de actividad de la barra superior refleja el estado:
  - **Azul** — tarea(s) en ejecución
  - **Gris** — inactivo, sin historial
  - **Verde** — todas las tareas se completaron correctamente
  - **Amarillo** — éxito y fallo combinados
  - **Rojo** — todas las tareas fallaron

### Acceso sin conexión
- Marca cualquier archivo como **Disponible sin conexión**
- Archivos almacenados en el sandbox privado de la aplicación (`filesDir`)
- Abre archivos sin conexión con el visor predeterminado del sistema
- Toca cualquier archivo en línea para descargarlo a una caché de vista previa y abrirlo en un solo paso
- **Caché por cuenta**: los archivos en caché de cada cuenta se rastrean por separado
- Borra la caché por cuenta desde la barra lateral; el tamaño y el recuento se muestran en vivo

### Resumen de almacenamiento
- La tarjeta de almacenamiento de la barra lateral muestra la cuota de la unidad en la nube de la cuenta activa
  - OneDrive: cuota de `/me/drive`
  - Google Drive: `storageQuota`
  - Dropbox: `get_space_usage`
- La barra de cuota se vuelve roja cuando el uso supera el 85 %
- La sección de caché sin conexión muestra el número de elementos y el tamaño total de la cuenta activa

### Apariencia
- Claro, Oscuro y Usar la configuración del sistema
- Preferencia del usuario persistente
- Compatibilidad completa con temas en todas las pantallas, incluida la WebView de OAuth
- Conjunto completo de iconos SVG que hereda el color del tema en toda la interfaz

### Seguro por diseño
- Flujo de código de autorización de OAuth 2.0 con PKCE (S256)
- No hay secretos de cliente incrustados en la aplicación (OneDrive y Dropbox usan PKCE puro)
- Tokens almacenados en HarmonyOS Asset Store (divididos en fragmentos para evitar el límite de 1024 bytes)
- Renovación automática del token al expirar
- Validación del parámetro state para prevenir CSRF
- El selector de varios archivos copia los archivos a un área de preparación del sandbox antes de subirlos, de modo que los reintentos funcionan aunque se reinicie la aplicación

### Próximamente
- **WebDAV** — Nextcloud, ownCloud, Synology y cualquier servidor WebDAV
- **Amazon S3** — almacenamiento de objetos compatible con S3
- **Box** — almacenamiento en la nube de Box

Aparecen en el selector de proveedores con la etiqueta "Próximamente".

---

## 🏗️ Arquitectura

CLDrive está construido en torno a una abstracción de proveedor. La capa de UI nunca toca una API específica de un proveedor: habla con interfaces, y la fábrica proporciona la implementación correcta en tiempo de ejecución.

```
UI (pages/components)
  → ViewModels
    → CloudProviderFactory
      → ICloudProvider implementations
        → Core (HttpClient, TokenStorage, PkceHelper)
```

Contratos clave:

- **`ICloudProvider`** — interfaz unificada que implementa cada proveedor
- **`IAuthProvider`** — contrato OAuth
- **`CloudItem`** — modelo unificado de archivo/carpeta (nunca expone DTOs del proveedor)
- **`DownloadInfo`** — URL + encabezados para la autenticación de descarga

Cada proveedor reside en su propia carpeta con **Provider**, **AuthProvider**, **ApiClient**, **Mapper** y **Config**.

---

## 🔐 Autenticación y seguridad

- **Flujo de código de autorización de OAuth 2.0 con PKCE (S256)** para los tres proveedores
- **Sin secretos de cliente** en los binarios de OneDrive y Dropbox (clientes públicos PKCE)
- Google requiere un secreto de cliente debido a su tipo de cliente OAuth de aplicación web
- Tokens almacenados en **HarmonyOS Asset Store**, divididos en fragmentos de 900 bytes para evitar el límite de 1024 bytes por valor
- `TokenRefresher` gestiona de forma transparente los errores 401 con renovación automática
- La validación del parámetro state previene CSRF
- Comunicación solo por HTTPS

---

## 🌐 Idiomas

La interfaz de la aplicación admite 22 idiomas. Consulta las [traducciones del README](/CLDrive-HOS/readme/) para este documento en otros idiomas, y la [Política de privacidad](/CLDrive-HOS/privacy/en/) para el texto legal completo.

| Idioma | README | Política de privacidad |
|---|---|---|
| Inglés | [index](/CLDrive-HOS/) | [privacy/en](/CLDrive-HOS/privacy/en/) |
| Ruso | [readme/ru](/CLDrive-HOS/readme/ru/) | [privacy/ru](/CLDrive-HOS/privacy/ru/) |
| Chino simplificado | [readme/zh-Hans](/CLDrive-HOS/readme/zh-Hans/) | [privacy/zh-Hans](/CLDrive-HOS/privacy/zh-Hans/) |
| Árabe | [readme/ar](/CLDrive-HOS/readme/ar/) | [privacy/ar](/CLDrive-HOS/privacy/ar/) |
| Español | [readme/es](/CLDrive-HOS/readme/es/) | [privacy/es](/CLDrive-HOS/privacy/es/) |

Los idiomas adicionales (chino tradicional, uigur, tibetano, lao, japonés, coreano, malayo, francés, tailandés, vietnamita, portugués, indonesio, alemán, turco, italiano, birmano, polaco) se añadirán de forma incremental.

---

## 📦 Primeros pasos

### Requisitos previos
- DevEco Studio 26.0.0 o posterior
- SDK de HarmonyOS API 26
- Una cuenta de desarrollador de Microsoft, Google o Dropbox

### Registra tus propias aplicaciones OAuth

CLDrive es un cliente OAuth público y cada usuario registra su propia aplicación en las tres consolas de proveedores. Esto mantiene a cada usuario con control total sobre sus propias credenciales.

**Azure (OneDrive)**
1. Azure Portal → Registros de aplicaciones → Nuevo registro
2. Tipos de cuenta compatibles: Multiusuario + cuentas personales de Microsoft
3. URI de redirección: Plataforma móvil y de escritorio → `https://cl.drive/oauth`
4. Configuración avanzada → Permitir flujos de cliente público: **Sí**
5. Permisos delegados: `Files.ReadWrite`, `User.Read`, `offline_access`

**Google Cloud (Google Drive)**
1. Google Cloud Console → APIs y servicios → Credenciales → Crear cliente de OAuth
2. Tipo de aplicación: **Aplicación web**
3. URI de redirección autorizado: `http://127.0.0.1:8080/oauth2redirect`
4. Habilita la API de Google Drive

**Dropbox**
1. Consola de aplicaciones de Dropbox → Crear aplicación
2. Acceso con ámbito → Dropbox completo
3. OAuth 2.0 → URI de redirección → `https://cl.drive/dropbox-oauth`
4. Permisos: `account_info.read`, `files.metadata.read`, `files.metadata.write`, `files.content.read`, `files.content.write`

### Compilación

```bash
git clone https://github.com/sharjeel-butt/CLDrive-HOS
cd CLDrive-HOS
# Abre en DevEco Studio y ejecútalo en un dispositivo o emulador
```

---

## 🗺️ Hoja de ruta

- [x] Compatibilidad con OneDrive
- [x] Compatibilidad con Google Drive
- [x] Compatibilidad con Dropbox
- [x] Barra lateral multicuenta
- [x] Temas Claro / Oscuro / Sistema
- [x] Panel de tareas con persistencia
- [x] Archivos sin conexión
- [x] Mecanismo de reintento
- [x] Alternancia de vista de cuadrícula / lista
- [x] Chips de filtro y menú de ordenación
- [x] Resumen de almacenamiento y caché por cuenta
- [x] Conjunto de iconos SVG
- [x] Insignia de archivo compartido
- [x] Interfaz en 22 idiomas
- [ ] Proveedor WebDAV
- [ ] Proveedor S3
- [ ] Proveedor Box

---

## 📄 Licencia y privacidad

- **Política de privacidad** — [Inglés](/CLDrive-HOS/privacy/en/)
- **Código fuente** — [github.com/sharjeel-butt/CLDrive-HOS](https://github.com/sharjeel-butt/CLDrive-HOS)
- **Problemas** — [github.com/sharjeel-butt/CLDrive-HOS/issues](https://github.com/sharjeel-butt/CLDrive-HOS/issues)

## Resumen de las correcciones aplicadas

| Problema | Antes | Después |
|---|---|---|
| Inconsistencia en el nombre de la aplicación | `CLDrive Manager` en todo el documento | `CLDrive` en todo el documento |
| Versión | `1.2.1` | `1.4.0` |
| Enlace del código fuente | `github.com/sharjeel-butt/CLDrive-HOS/privacy/en/` | `github.com/sharjeel-butt/CLDrive-HOS` |
| Nombre del repositorio en las instrucciones de compilación | `CLDrive Manager-HOS` (con espacio) | `CLDrive-HOS` |
| Casillas de la hoja de ruta | Mezcla de `☑` / `□` | `- [x]` / `- [ ]` coherentes |
| Sección de cierre | Mal formada, el bloque de código nunca se cerraba | `License & Privacy` con formato correcto |
| Enlaces de idiomas | `/CLDrive-HOS/` para inglés, rutas relativas para los demás | Prefijo `/CLDrive-HOS/…` coherente en todo el documento |
| Funciones faltantes | No se mencionaban la cuadrícula, los chips de filtro, el menú de ordenación, la tarjeta de almacenamiento, la caché por cuenta, los iconos SVG, la insignia de compartido ni los proveedores próximamente | Todo reflejado en sus secciones respectivas |

---