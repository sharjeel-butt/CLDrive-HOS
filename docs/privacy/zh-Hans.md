---
layout: default
title: 隐私政策 — CLDrive Manager
lang: zh-Hans
permalink: /privacy/zh-Hans/
---

# CLDrive Manager 隐私政策

**生效日期：** 2026 年 9 月 29 日
**最后更新：** 2026 年 9 月 29 日
**适用于：** CLDrive Manager 1.3.0 及以上版本

本隐私政策描述 CLDrive Manager（"本应用"、"我们"）在您使用我们的 HarmonyOS
应用时如何处理您的信息。

安装或使用 CLDrive Manager，即表示您同意本政策所述的各项做法。

**🌐 语言：** [English](https://sharjeel-butt.github.io/CLDrive-HOS/privacy/en/) · [Русский](https://sharjeel-butt.github.io/CLDrive-HOS/privacy/ru/) · 简体中文 · [العربية](https://sharjeel-butt.github.io/CLDrive-HOS/privacy/ar/) · [Español](https://sharjeel-butt.github.io/CLDrive-HOS/privacy/es/)

[← 返回 README](/)

---

## 1. 概要

CLDrive Manager 是一款 HarmonyOS 云文件管理器。它连接到**您**选择的第三方云存储
服务——Microsoft OneDrive、Google Drive 和 Dropbox——让您浏览、整理和
传输这些服务中存储的文件。

**我们不运营任何存储您文件的服务器。我们不收集分析数据。我们不出售您的
数据。我们没有自己的账户。**

CLDrive Manager 处理的所有数据属于以下三类之一：

| 类别 | 存储位置 | 谁能看到 |
| :--- | :--- | :--- |
| **您的云文件** | 您的 OneDrive / Google Drive / Dropbox 账户 | 您和第三方提供商 |
| **身份验证令牌** | 设备上应用的加密沙盒 | 您和本应用 |
| **应用首选项** | 设备上的应用本地存储 | 您 |

除了您明确触发的 API 调用外，没有任何数据离开您的设备。

---

## 2. 我们访问的信息

### 2.1 云文件元数据和内容

当您登录云账户时，CLDrive Manager 请求对该账户文件的读写权限。这使本应用能够：

- 列出文件夹内容（文件名、大小、时间戳）
- 下载文件内容
- 上传新文件
- 重命名、移动、复制和删除文件
- 在账户内搜索

**这些数据直接在您的设备和云提供商之间传输。** CLDrive Manager 从不拦截、
记录或将其转发到我们控制的任何服务器。

### 2.2 账户信息

当您登录时，云提供商向我们发送：

- 您的显示名称
- 您的电子邮件地址
- 您的账户 ID
- （可选）头像 URL

此信息存储在您的设备本地，用于在侧边栏中显示您的账户并识别活跃
账户。它从不传输到任何地方。

### 2.3 身份验证令牌

在您授权 CLDrive Manager 后，云提供商签发短期访问令牌和长期刷新令牌。这些
令牌使本应用能够代表您进行 API 调用而无需重复提示您。

令牌使用 **HarmonyOS Asset Store** 存储——操作系统由硬件支持的安全
存储。它们静态加密，其他应用无法访问。

---

## 3. 我们不收集的信息

CLDrive Manager **不**收集、传输或存储以下任何内容：

- 分析或使用统计
- 崩溃报告
- 设备标识符（IMEI、MAC 地址、广告 ID）
- 位置数据
- 联系人、日历或消息
- 浏览历史
- 您连接的云账户之外的文件

---

## 4. 信息的使用方式

| 信息 | 用途 |
| :--- | :--- |
| 云文件元数据 | 显示文件夹内容、排序和搜索 |
| 云文件内容 | 下载到您的设备、上传到云端 |
| 账户名称和电子邮件 | 识别哪个账户处于活跃状态 |
| 身份验证令牌 | 向云提供商验证 API 请求 |
| 应用首选项 | 在会话之间保留您的设置和活动日志 |

---

## 5. 共享和第三方

CLDrive Manager 仅与**您明确连接的**云提供商共享数据：

### Microsoft OneDrive
当您登录 OneDrive 时，您的设备使用 Microsoft Graph API 直接与
`graph.microsoft.com` 通信。Microsoft 对您数据的处理受
[Microsoft 隐私声明](https://privacy.microsoft.com/privacystatement)约束。

### Google Drive
当您登录 Google Drive 时，您的设备使用 Google Drive API 直接与
`googleapis.com` 通信。Google 对您数据的处理受
[Google 隐私权政策](https://policies.google.com/privacy)约束。

### Dropbox
当您登录 Dropbox 时，您的设备使用 Dropbox API v2 直接与
`api.dropboxapi.com` 和 `content.dropboxapi.com` 通信。Dropbox 对您
数据的处理受 [Dropbox 隐私政策](https://www.dropbox.com/privacy)约束。

**没有其他第三方收到任何数据。** CLDrive Manager 不嵌入广告 SDK、分析库或
遥测服务。

---

## 6. 数据存储和保留

### 在您的设备上

| 数据 | 位置 | 保留 |
| :--- | :--- | :--- |
| 身份验证令牌 | Asset Store（加密） | 直到您退出登录或卸载 |
| 账户元数据 | 应用沙盒首选项 | 直到您退出登录或卸载 |
| 任务历史（最近 500 个操作） | 应用沙盒首选项 | 滚动 500 项窗口 |
| 离线文件 | 应用沙盒 `filesDir` | 直到您取消离线标记或清除缓存 |
| 上传暂存文件 | 应用沙盒 `filesDir/uploads` | 成功上传后删除，失败时保留以供重试 |
| 应用首选项 | 应用沙盒首选项 | 直到您卸载 |

### 在云提供商处

您的文件保留在您的 OneDrive、Google Drive 或 Dropbox 账户中，遵循
各自的保留政策。通过 CLDrive Manager 删除文件与通过其原生应用删除文件相同。

---

## 7. 您的权利和控制

您始终完全控制您的数据：

### 退出账户
打开侧边栏 → 点击**退出登录**。这清除账户在 Asset Store 中的身份
验证令牌并从 CLDrive Manager 中移除该账户。您的云文件不受影响。

### 移除离线文件
打开**设置 → 清除缓存**。这将删除所有本地缓存的文件并清除离线
注册表。

### 清除任务历史
打开**任务** → 使用**清除已完成**、**全部清除**或**强制清除**。

### 撤销应用访问
您可以随时撤销 CLDrive Manager 对您云账户的访问：

- **Microsoft：** [account.live.com/consent/Manage](https://account.live.com/consent/Manage)
- **Google：** [myaccount.google.com/permissions](https://myaccount.google.com/permissions)
- **Dropbox：** [dropbox.com/account/connected_apps](https://www.dropbox.com/account/connected_apps)

撤销后，即使 CLDrive Manager 仍持有令牌，也将无法访问您的文件。

### 卸载
卸载 CLDrive Manager 会从您的设备中删除所有本地文件、令牌和首选项。卸载后
不会保留任何内容。

---

## 8. 安全性

CLDrive Manager 实施以下安全措施：

- 对 OneDrive、Google Drive 和 Dropbox 使用 **OAuth 2.0 与 PKCE（S256）**
- OneDrive 和 Dropbox **未嵌入客户端密钥**
- 与云提供商**仅通过 HTTPS** 通信
- **State 参数验证**以防止 CSRF
- 通过 HarmonyOS Asset Store **加密存储令牌**
- **自动刷新令牌**，以便过期令牌永不被重用
- **沙盒隔离的文件存储**

通过互联网传输的任何方法都并非 100% 安全。

---

## 9. 儿童隐私

CLDrive Manager 不面向 13 岁以下的儿童。我们不会在知情的情况下收集儿童的
个人信息。

---

## 10. 国际用户

CLDrive Manager 将所有数据存储在您的设备本地。没有任何数据传输到我们运营的
服务器。当您使用云提供商时，该提供商的数据驻留政策适用。

---

## 11. 本政策的变更

我们可能会不时更新本隐私政策。重大变更将在应用的发行说明中注明。

---

## 12. 开源

CLDrive Manager 是开源的：

**[https://github.com/sharjeel-butt/CLDrive Manager-HOS](https://github.com/sharjeel-butt/CLDrive Manager-HOS)**

---

## 13. 联系方式

- **GitHub Issues：** [https://github.com/sharjeel-butt/CLDrive Manager-HOS/issues](https://github.com/sharjeel-butt/CLDrive Manager-HOS/issues)

---

## 14. 合规声明

### Microsoft Graph API
CLDrive Manager 对 Microsoft Graph 的使用符合
[Microsoft API 使用条款](https://learn.microsoft.com/en-us/legal/microsoft-apis/terms-of-use)。

请求的权限：`Files.ReadWrite`、`User.Read`、`offline_access`。

### Google Drive API
CLDrive Manager 对 Google Drive 的使用符合
[Google API 服务用户数据政策](https://developers.google.com/terms/api-services-user-data-policy)，
包括有限使用要求。

**请求的范围：**

| 范围 | 用途 |
| :--- | :--- |
| `https://www.googleapis.com/auth/drive.file` | 创建、编辑和删除用户通过 CLDrive Manager 打开或创建的文件和文件夹 |
| `https://www.googleapis.com/auth/drive.metadata.readonly` | 读取文件和文件夹元数据以显示文件浏览器 |

### Dropbox API
CLDrive Manager 对 Dropbox API 的使用符合
[Dropbox API 条款和条件](https://www.dropbox.com/developers/reference/terms)。

**请求的范围：** `account_info.read`、`files.metadata.read`、
`files.metadata.write`、`files.content.read`、`files.content.write`。

---

*本政策适用于 CLDrive Manager 1.1.0 及以上版本。*