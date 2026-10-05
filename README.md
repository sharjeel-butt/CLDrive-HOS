# CLDrive Manager

**A unified cloud file manager for HarmonyOS.**

CLDrive brings OneDrive, Google Drive, and Dropbox into a single, consistent file browser. Manage every cloud account you own from one native HarmonyOS app — with cross-provider operations, secure PKCE authentication, and an extensible architecture that makes adding new providers a matter of writing one class.

**Current version:** 1.4.0

---

**🌐 Languages:** English · [Русский](/CLDrive-HOS/readme/ru/) · [简体中文](/CLDrive-HOS/readme/zh-Hans/) · [العربية](/CLDrive-HOS/readme/ar/) · [Español](/CLDrive-HOS/readme/es/)

**📄 [Privacy Policy](/CLDrive-HOS/privacy/en/)** · [Source code](https://github.com/sharjeel-butt/CLDrive-HOS)

---

## ✨ Features

### Multi-account, multi-provider
- Sign in with unlimited OneDrive, Google Drive, and Dropbox accounts
- Sidebar tree groups accounts by provider
- Switch between accounts with a single tap
- Per-account avatar, display name, and email
- Sign out directly from the active account's row

### Unified file browser
- Consistent experience across every provider
- **List and grid layouts** with a one-tap toggle in the top bar
- Folder navigation with clickable breadcrumb trail
- **Filter chips**: All · Images · Videos · Docs · Audio · Other
- **Sort menu**: Name (A–Z / Z–A), Newest, Oldest, Largest
- File metadata: name, size, relative timestamp, type-specific icon
- Real thumbnails when the provider supplies them; FileIcon badges otherwise
- **Shared badge** marks files and folders you don't own
- Pull-to-refresh, loading states, and error handling
- Search across the active account with debounced queries
- Auto-populated file extensions derived from MIME type

### File operations

| Operation | OneDrive | Google Drive | Dropbox |
|---|:---:|:---:|:---:|
| Browse folders | ✅ | ✅ | ✅ |
| Create folder | ✅ | ✅ | ✅ |
| Rename | ✅ | ✅ | ✅ |
| Move | ✅ | ✅ | ✅ |
| Copy | ✅ | ✅ | ✅ |
| Delete | ✅ | ✅ | ✅ |
| Download | ✅ | ✅ | ✅ |
| Upload | ✅ | ✅ | ✅ |
| Resumable upload | ✅ | ✅ | ✅ |
| Search | ✅ | ✅ | ✅ |

### Multi-select and batch operations
- Long-press any item to enter selection mode
- Select all / Deselect all
- Batch Delete, Move, Copy, and Download
- Conflict resolution: Skip All / Keep Both / Replace All
- Selection action bar ordered: **Copy · Move · Download · Delete**

### Tasks panel
- Live progress for uploads, downloads, moves, copies, and deletes
- Four tabs: **All · Pending · Done · Failed**
- Pending shows the entire queued batch before execution begins
- Operations grouped by date (Today / Yesterday / specific dates)
- Historical log persists across app restarts (up to 500 recent tasks)
- Per-item ring progress indicators for transfers
- **Retry** support for failed tasks (per-row ↻ and Retry All)
- Top-bar activity icon reflects state:
  - **Blue** — task(s) running
  - **Grey** — idle, no history
  - **Green** — all tasks succeeded
  - **Yellow** — mixed success and failure
  - **Red** — all tasks failed

### Offline access
- Mark any file as **Available offline**
- Files stored in the app's private sandbox (`filesDir`)
- Open offline files with the system's default viewer
- Tap any online file to download to a preview cache and open it in one step
- **Per-account cache**: each account's cached files are tracked separately
- Clear cache per account from the sidebar; size and count shown live

### Storage overview
- Sidebar storage card shows cloud drive quota for the active account
  - OneDrive: `/me/drive` quota
  - Google Drive: `storageQuota`
  - Dropbox: `get_space_usage`
- Quota bar turns red above 85% usage
- Offline cache section shows item count and total size for the active account

### Appearance
- Light, Dark, and Use system settings
- Persisted user preference
- Full theme support across every screen, including the OAuth WebView
- Complete SVG icon set that inherits the theme color throughout

### Secure by design
- OAuth 2.0 Authorization Code flow with PKCE (S256)
- No client secrets embedded in the app (OneDrive and Dropbox use pure PKCE)
- Tokens stored in HarmonyOS Asset Store (chunked to bypass the 1024-byte limit)
- Automatic token refresh on expiry
- State parameter validation to prevent CSRF
- Multi-file picker copies files to a sandbox stage before upload, so retries work across app restarts

### Coming soon
- **WebDAV** — Nextcloud, ownCloud, Synology, and any WebDAV server
- **Amazon S3** — S3-compatible object storage
- **Box** — Box cloud storage

These appear in the provider picker with a "Coming soon" label.

---

## 🏗️ Architecture

CLDrive is built around a provider abstraction. The UI layer never touches a provider-specific API — it talks to interfaces, and the factory supplies the right implementation at runtime.

```
UI (pages/components)
  → ViewModels
    → CloudProviderFactory
      → ICloudProvider implementations
        → Core (HttpClient, TokenStorage, PkceHelper)
```

Key contracts:

- **`ICloudProvider`** — unified interface every provider implements
- **`IAuthProvider`** — OAuth contract
- **`CloudItem`** — unified file/folder model (never exposes provider DTOs)
- **`DownloadInfo`** — URL + headers for download auth

Each provider lives in its own folder with a **Provider**, **AuthProvider**, **ApiClient**, **Mapper**, and **Config**.

---

## 🔐 Authentication & Security

- **OAuth 2.0 Authorization Code flow with PKCE (S256)** for all three providers
- **No client secrets** in OneDrive and Dropbox binaries (PKCE public clients)
- Google requires a client secret due to its Web application OAuth client type
- Tokens stored in **HarmonyOS Asset Store**, chunked at 900 bytes to bypass the 1024-byte per-value limit
- `TokenRefresher` transparently handles 401s with auto-refresh
- State parameter validation prevents CSRF
- HTTPS-only communication

---

## 🌐 Languages

The app UI supports 22 languages. See [README translations](/CLDrive-HOS/readme/) for this document in other languages, and the [Privacy Policy](/CLDrive-HOS/privacy/en/) for the full legal text.

| Language | README | Privacy Policy |
|---|---|---|
| English | [index](/CLDrive-HOS/) | [privacy/en](/CLDrive-HOS/privacy/en/) |
| Русский (Russian) | [readme/ru](/CLDrive-HOS/readme/ru/) | [privacy/ru](/CLDrive-HOS/privacy/ru/) |
| 简体中文 (Simplified Chinese) | [readme/zh-Hans](/CLDrive-HOS/readme/zh-Hans/) | [privacy/zh-Hans](/CLDrive-HOS/privacy/zh-Hans/) |
| العربية (Arabic) | [readme/ar](/CLDrive-HOS/readme/ar/) | [privacy/ar](/CLDrive-HOS/privacy/ar/) |
| Español (Spanish) | [readme/es](/CLDrive-HOS/readme/es/) | [privacy/es](/CLDrive-HOS/privacy/es/) |

Additional languages (Traditional Chinese, Uyghur, Tibetan, Lao, Japanese, Korean, Malay, French, Thai, Vietnamese, Portuguese, Indonesian, German, Turkish, Italian, Burmese, Polish) will be added incrementally.

---

## 📦 Getting Started

### Prerequisites
- DevEco Studio 26.0.0 or later
- HarmonyOS API 26 SDK
- A Microsoft, Google, or Dropbox developer account

### Register your own OAuth apps

CLDrive is a public OAuth client and each user registers their own app in the three provider consoles. This keeps every user in full control of their own credentials.

**Azure (OneDrive)**
1. Azure Portal → App registrations → New registration
2. Supported account types: Multitenant + personal Microsoft accounts
3. Redirect URI: Mobile and desktop platform → `https://cl.drive/oauth`
4. Advanced settings → Allow public client flows: **Yes**
5. Delegated permissions: `Files.ReadWrite`, `User.Read`, `offline_access`

**Google Cloud (Google Drive)**
1. Google Cloud Console → APIs & Services → Credentials → Create OAuth client
2. Application type: **Web application**
3. Authorized redirect URI: `http://127.0.0.1:8080/oauth2redirect`
4. Enable the Google Drive API

**Dropbox**
1. Dropbox App Console → Create app
2. Scoped access → Full Dropbox
3. OAuth 2.0 → Redirect URIs → `https://cl.drive/dropbox-oauth`
4. Permissions: `account_info.read`, `files.metadata.read`, `files.metadata.write`, `files.content.read`, `files.content.write`

### Build

```bash
git clone https://github.com/sharjeel-butt/CLDrive-HOS
cd CLDrive-HOS
# Open in DevEco Studio, then Run on a device or emulator
```

---

## 🗺️ Roadmap

- [x] OneDrive support
- [x] Google Drive support
- [x] Dropbox support
- [x] Multi-account sidebar
- [x] Light / Dark / System themes
- [x] Tasks panel with persistence
- [x] Offline files
- [x] Retry mechanism
- [x] Grid / list view toggle
- [x] Filter chips and sort menu
- [x] Per-account storage and cache overview
- [x] SVG icon set
- [x] Shared file badge
- [x] 22-language UI
- [ ] WebDAV provider
- [ ] S3 provider
- [ ] Box provider

---

## 📄 License & Privacy

- **Privacy Policy** — [English](/CLDrive-HOS/privacy/en/)
- **Source code** — [github.com/sharjeel-butt/CLDrive-HOS](https://github.com/sharjeel-butt/CLDrive-HOS)
- **Issues** — [github.com/sharjeel-butt/CLDrive-HOS/issues](https://github.com/sharjeel-butt/CLDrive-HOS/issues)

## Summary of fixes applied

| Issue | Before | After |
|---|---|---|
| App name inconsistency | `CLDrive Manager` throughout | `CLDrive` throughout |
| Version | `1.2.1` | `1.4.0` |
| Source code link | `github.com/sharjeel-butt/CLDrive-HOS/privacy/en/` | `github.com/sharjeel-butt/CLDrive-HOS` |
| Repo name in build instructions | `CLDrive Manager-HOS` (with space) | `CLDrive-HOS` |
| Roadmap checkboxes | Mixed `☑` / `□` | Consistent `- [x]` / `- [ ]` |
| Closing section | Malformed, code block never closed | Properly formatted `License & Privacy` |
| Language links | `/CLDrive-HOS/` for English, relative paths for others | Consistent `/CLDrive-HOS/…` prefix throughout |
| Missing features | No mention of grid, filter chips, sort menu, storage card, per-account cache, SVG icons, shared badge, coming-soon providers | All reflected under their respective sections |

---
