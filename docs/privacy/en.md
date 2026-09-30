--
layout: default
title: Privacy Policy — CLDrive Manager
lang: en
permalink: /privacy/en/
---

# Privacy Policy for CLDrive Manager

**Effective date:** September 29, 2026
**Last updated:** September 29, 2026
**Applies to:** CLDrive Manager version 1.3.0 and later

This Privacy Policy describes how CLDrive Manager ("the App", "we", "us", "our")
handles your information when you use our HarmonyOS application.

By installing or using CLDrive Manager, you agree to the practices described in this
policy.

**🌐 Languages:** [English](https://sharjeel-butt.github.io/CLDrive-HOS/privacy/en/) · [Русский](https://sharjeel-butt.github.io/CLDrive-HOS/privacy/ru/) · 简体中文 · [العربية](https://sharjeel-butt.github.io/CLDrive-HOS/privacy/ar/) · [Español](https://sharjeel-butt.github.io/CLDrive-HOS/privacy/es/)

[← Back to README](/)

---

## 1. Summary

CLDrive Manager is a cloud file manager for HarmonyOS. It connects to third-party
cloud storage services that **you** choose — Microsoft OneDrive, Google
Drive, and Dropbox — and lets you browse, organize, and transfer files stored
in those services.

**We do not operate any servers that store your files. We do not collect
analytics. We do not sell your data. We do not have accounts of our own.**

All data handled by CLDrive Manager falls into one of three categories:

| Category | Where it lives | Who can see it |
| :--- | :--- | :--- |
| **Your cloud files** | Your OneDrive / Google Drive / Dropbox account | You, and the third-party provider |
| **Authentication tokens** | The App's encrypted sandbox on your device | You, and the App |
| **App preferences** | The App's local storage on your device | You |

Nothing leaves your device except the API calls you explicitly trigger.

---

## 2. Information We Access

### 2.1 Cloud file metadata and content

When you sign in to a cloud account, CLDrive Manager requests read and write access
to that account's files. This lets the App:

- List folder contents (file names, sizes, timestamps)
- Download file content
- Upload new files
- Rename, move, copy, and delete files
- Search within the account

**This data is transmitted directly between your device and the cloud
provider.** CLDrive Manager never intercepts, logs, or forwards it to any server we
control.

### 2.2 Account information

When you sign in, the cloud provider sends us:

- Your display name
- Your email address
- Your account ID
- (Optional) A profile picture URL

This information is stored locally on your device to display your account in
the sidebar and identify which account is active. It is never transmitted
anywhere.

### 2.3 Authentication tokens

The cloud providers issue short-lived access tokens and long-lived refresh
tokens after you authorize CLDrive Manager. These tokens allow the App to make API
calls on your behalf without re-prompting you.

Tokens are stored using **HarmonyOS Asset Store** — the operating system's
hardware-backed secure storage. They are encrypted at rest and inaccessible
to other applications.

---

## 3. Information We Do NOT Collect

CLDrive Manager does **not** collect, transmit, or store any of the following:

- Analytics or usage statistics
- Crash reports
- Device identifiers (IMEI, MAC address, advertising ID)
- Location data
- Contacts, calendar, or messages
- Browsing history
- Files from outside the cloud accounts you connect

---

## 4. How Information Is Used

| Information | Purpose |
| :--- | :--- |
| Cloud file metadata | Display folder contents, sort, and search |
| Cloud file content | Download to your device, upload to the cloud |
| Account name and email | Identify which account is active |
| Authentication tokens | Authenticate API requests to the cloud provider |
| App preferences | Preserve your settings and activity log across sessions |

---

## 5. Sharing and Third Parties

CLDrive Manager shares data only with the cloud providers **you explicitly connect**:

### Microsoft OneDrive
When you sign in to OneDrive, your device communicates directly with
`graph.microsoft.com` using the Microsoft Graph API. Microsoft's handling of
your data is governed by the
[Microsoft Privacy Statement](https://privacy.microsoft.com/privacystatement).

### Google Drive
When you sign in to Google Drive, your device communicates directly with
`googleapis.com` using the Google Drive API. Google's handling of your data
is governed by the [Google Privacy Policy](https://policies.google.com/privacy).

### Dropbox
When you sign in to Dropbox, your device communicates directly with
`api.dropboxapi.com` and `content.dropboxapi.com` using the Dropbox API v2.
Dropbox's handling of your data is governed by the
[Dropbox Privacy Policy](https://www.dropbox.com/privacy).

**No other third parties receive any data.** CLDrive Manager does not embed
advertising SDKs, analytics libraries, or telemetry services.

---

## 6. Data Storage and Retention

### On your device

| Data | Location | Retention |
| :--- | :--- | :--- |
| Authentication tokens | Asset Store (encrypted) | Until you sign out or uninstall |
| Account metadata | App sandbox preferences | Until you sign out or uninstall |
| Task history (last 500 operations) | App sandbox preferences | Rolling 500-item window |
| Offline files | App sandbox `filesDir` | Until you unmark offline or clear cache |
| Upload staging files | App sandbox `filesDir/uploads` | Deleted on successful upload, retained on failure for retry |
| App preferences | App sandbox preferences | Until you uninstall |

### On cloud providers

Your files remain in your OneDrive, Google Drive, or Dropbox account under
their respective retention policies. Deleting a file through CLDrive Manager removes
it from the cloud provider the same way as deleting it through their native
apps.

---

## 7. Your Rights and Controls

You are always in full control of your data:

### Sign out of an account
Open the sidebar → tap **Sign out**. This clears the account's authentication
tokens from Asset Store and removes the account from CLDrive Manager. Your cloud
files are untouched.

### Remove offline files
Open **Settings → Clear cache**. This deletes every locally cached file and
clears the offline registry.

### Clear task history
Open **Tasks** → use **Clear completed**, **Clear all**, or **Force clear**.

### Revoke app access
You can revoke CLDrive Manager's access to your cloud account at any time:

- **Microsoft:** [account.live.com/consent/Manage](https://account.live.com/consent/Manage)
- **Google:** [myaccount.google.com/permissions](https://myaccount.google.com/permissions)
- **Dropbox:** [dropbox.com/account/connected_apps](https://www.dropbox.com/account/connected_apps)

After revoking, CLDrive Manager will no longer be able to access your files even if
it still holds tokens.

### Uninstall
Uninstalling CLDrive Manager removes every local file, token, and preference from
your device. Nothing persists after uninstall.

---

## 8. Security

CLDrive Manager implements the following security measures:

- **OAuth 2.0 with PKCE (S256)** for OneDrive, Google Drive, and Dropbox
- **No client secrets embedded** for OneDrive and Dropbox
- **HTTPS-only** communication with cloud providers
- **State parameter validation** to prevent cross-site request forgery
- **Encrypted token storage** via HarmonyOS Asset Store
- **Automatic token refresh** so expired tokens are never reused
- **Sandbox-isolated file storage**

No method of transmission over the internet is 100% secure.

---

## 9. Children's Privacy

CLDrive Manager is not directed at children under 13. We do not knowingly collect
personal information from children.

---

## 10. International Users

CLDrive Manager stores all data locally on your device. No data is transferred to
servers operated by us. When you use a cloud provider, that provider's data
residency policy applies.

---

## 11. Changes to This Policy

We may update this Privacy Policy from time to time. Significant changes will
be noted in the App's release notes.

---

## 12. Open Source

CLDrive Manager is open source:

**[https://github.com/sharjeel-butt/CLDrive Manager-HOS](https://github.com/sharjeel-butt/CLDrive Manager-HOS)**

---

## 13. Contact

- **GitHub Issues:** [https://github.com/sharjeel-butt/CLDrive Manager-HOS/issues](https://github.com/sharjeel-butt/CLDrive Manager-HOS/issues)

---

## 14. Compliance Statements

### Microsoft Graph API
CLDrive Manager's use of Microsoft Graph complies with the
[Microsoft APIs Terms of Use](https://learn.microsoft.com/en-us/legal/microsoft-apis/terms-of-use).

Permissions requested: `Files.ReadWrite`, `User.Read`, `offline_access`.

### Google Drive API
CLDrive Manager's use of Google Drive complies with the
[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
including the Limited Use requirements.

**Scopes requested:**

| Scope | Purpose |
| :--- | :--- |
| `https://www.googleapis.com/auth/drive.file` | Create, edit, and delete files and folders the user opens or creates through CLDrive Manager |
| `https://www.googleapis.com/auth/drive.metadata.readonly` | Read file and folder metadata to display the file browser |

### Dropbox API
CLDrive Manager's use of the Dropbox API complies with the
[Dropbox API Terms and Conditions](https://www.dropbox.com/developers/reference/terms).

**Scopes requested:** `account_info.read`, `files.metadata.read`,
`files.metadata.write`, `files.content.read`, `files.content.write`.

---

*This policy applies to CLDrive Manager version 1.1.0 and later.*