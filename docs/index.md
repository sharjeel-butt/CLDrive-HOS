---
layout: default
title: CLDrive
lang: en
permalink: /
---

# CLDrive

**A unified cloud file manager for HarmonyOS.**

CLDrive brings OneDrive, Google Drive, and Dropbox into a single, consistent
file browser. Manage every cloud account you own from one native HarmonyOS
app — with cross-provider operations, secure PKCE authentication, and an
extensible architecture that makes adding new providers a matter of writing
one class.

**Current version:** 1.2.1

---

**🌐 Languages:** [English](/CLDrive-HOS/) · [Русский](readme/ru/) · [简体中文](readme/zh-Hans/) · [العربية](readme/ar/) · [Español](readme/es/)

**📄 [Privacy Policy](privacy/en/)** · [Source code](https://github.com/sharjeel-butt/CLDrive-HOS)

---

## ✨ Features

### Multi-account, multi-provider
- Sign in with unlimited OneDrive, Google Drive, and Dropbox accounts
- Sidebar tree groups accounts by provider
- Switch between accounts with a single tap
- Per-account avatar, display name, and email

### Unified file browser
- Consistent list view across every provider
- Folder navigation with breadcrumb trail
- File metadata: name, size, modified date, type-specific icon
- Pull-to-refresh, loading states, and error handling
- Search across the active account
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
- Per-item progress bars for transfers
- **Retry** support for failed tasks (per-row ↻ and Retry All)
- Top-bar activity icon reflects state:
    - **Blue** — task(s) running
    - **Grey** — idle, no history
    - **Green** — all tasks succeeded
    - **Yellow** — mixed success and failure
    - **Red** — all tasks failed

### Offline access
- Mark any file as **Available offline**
- Files stored in the app's private sandbox
- Open offline files with the system's default viewer
- Storage usage summary and cache clearing in Settings

### Appearance
- Light, Dark, and Use system settings
- Persisted user preference
- Full theme support across every screen, including the OAuth WebView

### Secure by design
- OAuth 2.0 Authorization Code flow with PKCE (S256)
- No client secrets embedded in the app (OneDrive, Dropbox use pure PKCE)
- Tokens stored in HarmonyOS Asset Store (chunked to bypass the 1024-byte limit)
- Automatic token refresh on expiry
- State parameter validation to prevent CSRF
- Multi-file picker copies files to a sandbox stage before upload, so retries work across app restarts

---

## 🏗️ Architecture

CLDrive is built around a provider abstraction. The UI layer never touches a
provider-specific API — it talks to interfaces, and the factory supplies the
right implementation at runtime.


Key contracts:

- **`ICloudProvider`** — unified interface every provider implements
- **`IAuthProvider`** — OAuth contract
- **`CloudItem`** — unified file/folder model (never exposes provider DTOs)
- **`DownloadInfo`** — URL + headers for download auth

Each provider lives in its own folder with a **Provider**, **AuthProvider**,
**ApiClient**, **Mapper**, and **Config**.

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

The app UI supports 22 languages. See [README translations](readme/) for this
document in other languages, and the [Privacy Policy](privacy/en/) for the
full legal text.

| Language | README | Privacy Policy |
|---|---|---|
| English | [index](/) | [privacy/en](privacy/en/) |
| Русский (Russian) | [readme/ru](readme/ru/) | [privacy/ru](privacy/ru/) |
| 简体中文 (Simplified Chinese) | [readme/zh-Hans](readme/zh-Hans/) | [privacy/zh-Hans](privacy/zh-Hans/) |
| العربية (Arabic) | [readme/ar](readme/ar/) | [privacy/ar](privacy/ar/) |
| Español (Spanish) | [readme/es](readme/es/) | [privacy/es](privacy/es/) |

Additional languages (Traditional Chinese, Uyghur, Tibetan, Lao, Japanese,
Korean, Malay, French, Thai, Vietnamese, Portuguese, Indonesian, German,
Turkish, Italian, Burmese, Polish) will be added incrementally.

---

## 📦 Getting Started

### Prerequisites
- DevEco Studio 26.0.0 or later
- HarmonyOS API 26 SDK
- A Microsoft, Google, or Dropbox developer account

### Register your own OAuth apps

CLDrive is a public OAuth client and each user registers their own app in the
three provider consoles. This keeps every user in full control of their own
credentials.

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
4. Permissions: `account_info.read`, `files.metadata.read`,
   `files.metadata.write`, `files.content.read`, `files.content.write`

### Build

```bash
git clone https://github.com/sharjeel-butt/CLDrive-HOS
cd CLDrive-HOS
# Open in DevEco Studio, then Run on a device or emulator

🗺️ Roadmap
☑ OneDrive support
☑ Google Drive support
☑ Dropbox support
☑ Multi-account sidebar
☑ Light / Dark / System themes
☑ Tasks panel with persistence
☑ Offline files
☑ Retry mechanism
☑ 22-language UI
□ WebDAV provider
□ S3 provider
□ Box provider

📄 License & Privacy
Privacy Policy — English

Source code — github.com/sharjeel-butt/CLDrive-HOS

Issues — github.com/sharjeel-butt/CLDrive-HOS/issues