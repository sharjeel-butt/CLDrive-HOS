
---

### `PRIVACY_POLICY.md`

```markdown
# Privacy Policy for CLDrive

**Effective date:** September 29, 2026
**Last updated:** September 29, 2026
**Applies to:** CLDrive version 1.1.0 and later

This Privacy Policy describes how CLDrive ("the App", "we", "us", "our") handles your information when you use our HarmonyOS application.

By installing or using CLDrive, you agree to the practices described in this policy.

---

## 1. Summary

CLDrive is a cloud file manager for HarmonyOS. It connects to third-party cloud storage services that **you** choose — Microsoft OneDrive, Google Drive, and Dropbox — and lets you browse, organize, and transfer files stored in those services.

**We do not operate any servers that store your files. We do not collect analytics. We do not sell your data. We do not have accounts of our own.**

All data handled by CLDrive falls into one of three categories:

| Category | Where it lives | Who can see it |
| :--- | :--- | :--- |
| **Your cloud files** | Your OneDrive / Google Drive / Dropbox account | You, and the third-party provider |
| **Authentication tokens** | The App's encrypted sandbox on your device | You, and the App |
| **App preferences** | The App's local storage on your device | You |

Nothing leaves your device except the API calls you explicitly trigger.

---

## 2. Information We Access

### 2.1 Cloud file metadata and content

When you sign in to a cloud account, CLDrive requests read and write access to that account's files. This lets the App:

- List folder contents (file names, sizes, timestamps)
- Download file content
- Upload new files
- Rename, move, copy, and delete files
- Search within the account

**This data is transmitted directly between your device and the cloud provider.** CLDrive never intercepts, logs, or forwards it to any server we control.

### 2.2 Account information

When you sign in, the cloud provider sends us:

- Your display name
- Your email address
- Your account ID
- (Optional) A profile picture URL

This information is stored locally on your device to display your account in the sidebar and identify which account is active. It is never transmitted anywhere.

### 2.3 Authentication tokens

The cloud providers issue short-lived access tokens and long-lived refresh tokens after you authorize CLDrive. These tokens allow the App to make API calls on your behalf without re-prompting you.

Tokens are stored using **HarmonyOS Asset Store** — the operating system's hardware-backed secure storage. They are encrypted at rest and inaccessible to other applications.

---

## 3. Information We Do NOT Collect

CLDrive does **not** collect, transmit, or store any of the following:

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
| App preferences (theme, offline list, task history) | Preserve your settings and activity log across sessions |

---

## 5. Sharing and Third Parties

CLDrive shares data only with the cloud providers **you explicitly connect**:

### Microsoft OneDrive
When you sign in to OneDrive, your device communicates directly with `graph.microsoft.com` using the Microsoft Graph API. Microsoft's handling of your data is governed by the [Microsoft Privacy Statement](https://privacy.microsoft.com/privacystatement).

### Google Drive
When you sign in to Google Drive, your device communicates directly with `googleapis.com` using the Google Drive API. Google's handling of your data is governed by the [Google Privacy Policy](https://policies.google.com/privacy).

### Dropbox
When you sign in to Dropbox, your device communicates directly with `api.dropboxapi.com` and `content.dropboxapi.com` using the Dropbox API v2. Dropbox's handling of your data is governed by the [Dropbox Privacy Policy](https://www.dropbox.com/privacy).

**No other third parties receive any data.** CLDrive does not embed advertising SDKs, analytics libraries, or telemetry services.

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
| App preferences (theme, etc.) | App sandbox preferences | Until you uninstall |

### On cloud providers

Your files remain in your OneDrive, Google Drive, or Dropbox account under their respective retention policies. Deleting a file through CLDrive removes it from the cloud provider the same way as deleting it through their native apps.

---

## 7. Your Rights and Controls

You are always in full control of your data:

### Sign out of an account
Open the sidebar → tap **Sign out**. This clears the account's authentication tokens from Asset Store and removes the account from CLDrive. Your cloud files are untouched.

### Remove offline files
Open **Settings → Clear cache**. This deletes every locally cached file and clears the offline registry.

### Clear task history
Open **Tasks** → use **Clear completed**, **Clear all**, or **Force clear**.

### Revoke app access
You can revoke CLDrive's access to your cloud account at any time:

- **Microsoft:** [account.live.com/consent/Manage](https://account.live.com/consent/Manage)
- **Google:** [myaccount.google.com/permissions](https://myaccount.google.com/permissions)
- **Dropbox:** [dropbox.com/account/connected_apps](https://www.dropbox.com/account/connected_apps)

After revoking, CLDrive will no longer be able to access your files even if it still holds tokens.

### Uninstall
Uninstalling CLDrive removes every local file, token, and preference from your device. Nothing persists after uninstall.

---

## 8. Security

CLDrive implements the following security measures:

- **OAuth 2.0 with PKCE (S256)** for OneDrive, Google Drive, and Dropbox
- **No client secrets embedded** for OneDrive and Dropbox (PKCE replaces the secret)
- **HTTPS-only** communication with cloud providers
- **State parameter validation** to prevent cross-site request forgery
- **Encrypted token storage** via HarmonyOS Asset Store, with chunked writes to stay under the 1024-byte per-value limit
- **Automatic token refresh** so expired tokens are never reused
- **Sandbox-isolated file storage** — offline files and upload staging cannot be read by other apps

No method of transmission over the internet is 100% secure. While we use industry-standard protocols, we cannot guarantee absolute security of data in transit.

---

## 9. Children's Privacy

CLDrive is not directed at children under 13. We do not knowingly collect personal information from children. If you believe a child has provided information through the App, please contact us so we can remove it.

---

## 10. International Users

CLDrive stores all data locally on your device. No data is transferred to servers operated by us, so there is no cross-border data transfer from CLDrive itself. When you use a cloud provider, that provider's data residency policy applies.

---

## 11. Changes to This Policy

We may update this Privacy Policy from time to time. The "Last updated" date at the top of this document reflects the most recent revision. Significant changes will be noted in the App's release notes.

Continued use of CLDrive after changes are posted constitutes acceptance of the updated policy.

---

## 12. Open Source

CLDrive is open source. You can inspect the full source code, including every network request the App makes, at:

**[https://github.com/sharjeel-butt/CLDrive-HOS](https://github.com/sharjeel-butt/CLDrive-HOS)**

We encourage users to audit the code and verify the practices described in this policy.

---

## 13. Contact

Questions about this policy or CLDrive's data handling practices?

- **GitHub Issues:** [https://github.com/sharjeel-butt/CLDrive-HOS/issues](https://github.com/sharjeel-butt/CLDrive-HOS/issues)

---

## 14. Compliance Statements

### Microsoft Graph API
CLDrive's use of Microsoft Graph complies with the [Microsoft APIs Terms of Use](https://learn.microsoft.com/en-us/legal/microsoft-apis/terms-of-use). When you sign in with a Microsoft account, the App requests only the permissions it needs to function:

- `Files.ReadWrite` — to browse, upload, download, and modify your OneDrive files
- `User.Read` — to display your name and email in the account switcher
- `offline_access` — to keep you signed in without repeated prompts

CLDrive does not sell or share Microsoft account data with third parties.

### Google Drive API
CLDrive's use of Google Drive complies with the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

Specifically:

- **Limited Use:** Data accessed from Google APIs is used only to provide or improve the App's user-facing features. We do not transfer this data to third parties.
- **No advertising:** We do not use Google user data for advertising purposes.
- **No human review:** We do not allow humans to read your Google Drive data, except when:
  - You explicitly request support and provide your consent
  - It is necessary for security purposes (e.g. investigating abuse)
  - It is required by law
- **Data deletion:** Uninstalling CLDrive removes all locally stored Google user data. Revoking access at [myaccount.google.com/permissions](https://myaccount.google.com/permissions) removes CLDrive's authorization entirely.

**Google API scopes requested by CLDrive:**

| Scope | Purpose |
| :--- | :--- |
| `https://www.googleapis.com/auth/drive.file` | Create, edit, and delete files and folders the user opens or creates through CLDrive |
| `https://www.googleapis.com/auth/drive.metadata.readonly` | Read file and folder metadata to display the file browser |

No other Google data is accessed.

### Dropbox API
CLDrive's use of the Dropbox API complies with the [Dropbox API Terms and Conditions](https://www.dropbox.com/developers/reference/terms) and the [Dropbox Platform Developer Guide](https://www.dropbox.com/developers/reference/developer-guide).

**Dropbox scopes requested by CLDrive:**

| Scope | Purpose |
| :--- | :--- |
| `account_info.read` | Read the user's display name and email for the account switcher |
| `files.metadata.read` | List files and folders and read their metadata |
| `files.metadata.write` | Create, rename, move, copy, and delete files and folders |
| `files.content.read` | Download file content |
| `files.content.write` | Upload file content |

CLDrive does not sell or share Dropbox account data with third parties. Files remain in the user's Dropbox account and are never routed through CLDrive's infrastructure.

---

*This policy applies to CLDrive version 1.1.0 and later.*