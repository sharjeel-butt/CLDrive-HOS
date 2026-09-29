# CLDrive

**A unified cloud file manager for HarmonyOS.**

CLDrive brings OneDrive, Google Drive, and Dropbox into a single, consistent file browser. Manage every cloud account you own from one native HarmonyOS app — with cross-provider operations, secure PKCE authentication, and an extensible architecture that makes adding new providers a matter of writing one class.

**Current version:** 1.1.0

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

CLDrive is built around a provider abstraction. The UI layer never touches a provider-specific API — it talks to interfaces, and the factory supplies the right implementation at runtime.
