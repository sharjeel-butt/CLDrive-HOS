
## 9. `readme/zh-Hans.md` — Simplified Chinese README

```markdown
---
layout: default
title: CLDrive Manager — 简体中文
lang: zh-Hans
permalink: /readme/zh-Hans/
---

# CLDrive Manager

**HarmonyOS 统一的云文件管理器。**

CLDrive Manager 将 OneDrive、Google Drive 和 Dropbox 整合到一个一致的
文件浏览器中。用一个原生 HarmonyOS 应用管理您拥有的所有云账户——
支持跨提供商操作、安全的 PKCE 身份验证，以及可扩展的架构，让添加
新提供商只需编写一个类。

**当前版本：** 1.2.1

---

**🌐 语言：** [English](/index.md) · [Русский](/readme/ru/) · 简体中文 · [العربية](/readme/ar/) · [Español](/readme/es/)

**📄 [隐私政策](/privacy/zh-Hans/)** · [源代码](https://github.com/sharjeel-butt/CLDrive Manager-HOS)

---

## ✨ 功能

### 多账户、多提供商
- 使用无限数量的 OneDrive、Google Drive 和 Dropbox 账户登录
- 侧边栏树按提供商分组账户
- 单次点击即可切换账户
- 每个账户的头像、显示名称和电子邮件

### 统一文件浏览器
- 跨所有提供商的一致列表视图
- 带面包屑导航的文件夹导航
- 文件元数据：名称、大小、修改日期、类型特定图标
- 下拉刷新、加载状态和错误处理
- 在活动账户中搜索
- 基于 MIME 类型自动生成文件扩展名

### 文件操作

| 操作 | OneDrive | Google Drive | Dropbox |
|---|:---:|:---:|:---:|
| 浏览文件夹 | ✅ | ✅ | ✅ |
| 创建文件夹 | ✅ | ✅ | ✅ |
| 重命名 | ✅ | ✅ | ✅ |
| 移动 | ✅ | ✅ | ✅ |
| 复制 | ✅ | ✅ | ✅ |
| 删除 | ✅ | ✅ | ✅ |
| 下载 | ✅ | ✅ | ✅ |
| 上传 | ✅ | ✅ | ✅ |
| 可续传上传 | ✅ | ✅ | ✅ |
| 搜索 | ✅ | ✅ | ✅ |

### 多选和批量操作
- 长按任意项目进入选择模式
- 全选 / 取消全选
- 批量删除、移动、复制和下载
- 冲突解决：全部跳过 / 保留两者 / 全部替换
- 选择操作栏顺序：**复制 · 移动 · 下载 · 删除**

### 任务面板
- 上传、下载、移动、复制和删除的实时进度
- 四个标签：**全部 · 等待中 · 已完成 · 失败**
- 等待中在执行开始前显示整个队列
- 操作按日期分组（今天 / 昨天 / 具体日期）
- 历史记录在应用重启后保留（最近 500 个任务）
- 每个传输的进度条
- 失败任务的**重试**支持（每行 ↻ 和全部重试）
- 顶栏活动图标反映状态：
    - **蓝色** — 任务正在运行
    - **灰色** — 空闲，无历史记录
    - **绿色** — 所有任务成功
    - **黄色** — 成功和失败混合
    - **红色** — 所有任务失败

### 离线访问
- 将任意文件标记为**可离线使用**
- 文件存储在应用的私有沙盒中
- 使用系统默认查看器打开离线文件
- 设置中的存储使用情况摘要和缓存清除

### 外观
- 浅色、深色和使用系统设置
- 持久化的用户偏好
- 每个屏幕的完整主题支持，包括 OAuth WebView

### 安全设计
- OAuth 2.0 授权码流程与 PKCE (S256)
- 应用中未嵌入客户端密钥（OneDrive 和 Dropbox 使用纯 PKCE）
- 令牌存储在 HarmonyOS Asset Store 中（分块绕过 1024 字节限制）
- 过期时自动刷新令牌
- State 参数验证以防止 CSRF
- 多文件选择器在上传前将文件复制到沙盒暂存，因此重试可跨应用重启工作

---

## 🏗️ 架构

CLDrive Manager 围绕提供商抽象构建。UI 层从不接触特定于提供商的 API——
它与接口对话，工厂在运行时提供正确的实现。


关键契约：

- **`ICloudProvider`** — 每个提供商实现的统一接口
- **`IAuthProvider`** — OAuth 契约
- **`CloudItem`** — 统一的文件/文件夹模型（从不暴露提供商 DTO）
- **`DownloadInfo`** — 下载认证的 URL + 标头

每个提供商位于自己的文件夹中，包含 **Provider**、**AuthProvider**、
**ApiClient**、**Mapper** 和 **Config**。

---

## 🔐 身份验证和安全

- 对所有三个提供商使用 **OAuth 2.0 授权码流程与 PKCE (S256)**
- OneDrive 和 Dropbox 二进制文件中**无客户端密钥**
- 由于 Web 应用 OAuth 客户端类型，Google 需要客户端密钥
- 令牌存储在 **HarmonyOS Asset Store** 中，分块为 900 字节以绕过 1024 字节的每值限制
- `TokenRefresher` 通过自动刷新透明处理 401
- State 参数验证防止 CSRF
- 仅 HTTPS 通信

---

## 📦 入门

### 先决条件
- DevEco Studio 26.0.0 或更高版本
- HarmonyOS API 26 SDK
- Microsoft、Google 或 Dropbox 开发者账户

### 注册自己的 OAuth 应用

CLDrive Manager 是公共 OAuth 客户端，每个用户在三个提供商控制台中注册
自己的应用。这使用户完全控制自己的凭据。

**Azure (OneDrive)**
1. Azure Portal → 应用注册 → 新注册
2. 支持的账户类型：多租户 + 个人 Microsoft 账户
3. 重定向 URI：移动和桌面平台 → `https://cl.drive/oauth`
4. 高级设置 → 允许公共客户端流：**是**
5. 委派权限：`Files.ReadWrite`、`User.Read`、`offline_access`

**Google Cloud (Google Drive)**
1. Google Cloud Console → API 和服务 → 凭据 → 创建 OAuth 客户端
2. 应用类型：**Web 应用**
3. 授权重定向 URI：`http://127.0.0.1:8080/oauth2redirect`
4. 启用 Google Drive API

**Dropbox**
1. Dropbox App Console → 创建应用
2. 作用域访问 → 完整 Dropbox
3. OAuth 2.0 → 重定向 URI → `https://cl.drive/dropbox-oauth`
4. 权限：`account_info.read`、`files.metadata.read`、
   `files.metadata.write`、`files.content.read`、`files.content.write`

### 构建

```bash
git clone https://github.com/sharjeel-butt/CLDrive Manager-HOS
cd CLDrive Manager-HOS
# 在 DevEco Studio 中打开，然后在设备或模拟器上运行

🗺️ 路线图
☑ OneDrive 支持
☑ Google Drive 支持
☑ Dropbox 支持
☑ 多账户侧边栏
☑ 浅色 / 深色 / 系统主题
☑ 带持久化的任务面板
☑ 离线文件
☑ 重试机制
☑ 22 种语言 UI
□ WebDAV 提供商
□ S3 提供商
□ Box 提供商
📄 许可和隐私
隐私政策 — 简体中文

源代码 — github.com/sharjeel-butt/CLDrive Manager-HOS

问题 — github.com/sharjeel-butt/CLDrive Manager-HOS/issues