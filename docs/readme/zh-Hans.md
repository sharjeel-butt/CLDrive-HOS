# CLDrive

**HarmonyOS 的统一云文件管理器。**

CLDrive 将 OneDrive、Google Drive 和 Dropbox 整合到一个统一、一致的文件浏览器中。用一个原生 HarmonyOS 应用管理你拥有的所有云账户——支持跨提供商操作、安全的 PKCE 认证，以及可扩展架构，让添加新提供商只需编写一个类。

**当前版本：** 1.4.0

---

**🌐 语言：** 英语 · [俄语](/CLDrive-HOS/readme/ru/) · [简体中文](/CLDrive-HOS/readme/zh-Hans/) · [阿拉伯语](/CLDrive-HOS/readme/ar/) · [西班牙语](/CLDrive-HOS/readme/es/)

**📄 [隐私政策](/CLDrive-HOS/privacy/en/)** · [源代码](https://github.com/sharjeel-butt/CLDrive-HOS)

---

## ✨ 功能

### 多账户、多提供商
- 登录无限数量的 OneDrive、Google Drive 和 Dropbox 账户
- 侧边栏树按提供商对账户分组
- 轻点一下即可在账户间切换
- 每个账户的头像、显示名称和电子邮件
- 可直接从当前账户所在行退出登录

### 统一文件浏览器
- 每个提供商都有一致体验
- **列表和网格布局**，顶栏一键切换
- 文件夹导航，带可点击的面包屑路径
- **筛选标签**：全部 · 图片 · 视频 · 文档 · 音频 · 其他
- **排序菜单**：名称（A–Z / Z–A）、最新、最旧、最大
- 文件元数据：名称、大小、相对时间戳、按类型区分的图标
- 提供商提供时显示真实缩略图；否则显示 FileIcon 徽标
- **共享徽标** 标记你不拥有的文件和文件夹
- 下拉刷新、加载状态和错误处理
- 在当前账户中搜索，支持防抖查询
- 根据 MIME 类型自动填充文件扩展名

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
- 冲突解决：全部跳过 / 两者保留 / 全部替换
- 选择操作栏顺序：**复制 · 移动 · 下载 · 删除**

### 任务面板
- 上传、下载、移动、复制和删除的实时进度
- 四个标签页：**全部 · 待处理 · 已完成 · 失败**
- 待处理显示执行开始前整个排队批次
- 操作按日期分组（今天 / 昨天 / 具体日期）
- 历史日志在应用重启后保留（最多 500 个最近任务）
- 传输项显示环形进度指示器
- 对失败任务支持**重试**（每行 ↻ 和全部重试）
- 顶栏活动图标反映状态：
  - **蓝色** — 有任务正在运行
  - **灰色** — 空闲，无历史
  - **绿色** — 所有任务成功
  - **黄色** — 部分成功、部分失败
  - **红色** — 所有任务失败

### 离线访问
- 将任意文件标记为**可离线使用**
- 文件存储在应用私有沙箱（`filesDir`）中
- 使用系统默认查看器打开离线文件
- 点击任意在线文件即可下载到预览缓存并一步打开
- **按账户缓存**：每个账户的缓存文件单独跟踪
- 从侧边栏按账户清除缓存；实时显示大小和数量

### 存储概览
- 侧边栏存储卡片显示当前账户的云盘配额
  - OneDrive：`/me/drive` 配额
  - Google Drive：`storageQuota`
  - Dropbox：`get_space_usage`
- 使用率超过 85% 时配额条变红
- 离线缓存部分显示当前账户的项目数和总大小

### 外观
- 浅色、深色和使用系统设置
- 持久化用户偏好
- 所有屏幕均支持完整主题，包括 OAuth WebView
- 完整 SVG 图标集，在整个界面继承主题颜色

### 安全设计
- 使用 PKCE（S256）的 OAuth 2.0 授权码流程
- 应用中不嵌入客户端密钥（OneDrive 和 Dropbox 使用纯 PKCE）
- 令牌存储在 HarmonyOS Asset Store 中（分块以绕过 1024 字节限制）
- 过期时自动刷新令牌
- State 参数验证以防止 CSRF
- 多文件选择器在上传前将文件复制到沙箱暂存区，因此重试可在应用重启后继续工作

### 即将推出
- **WebDAV** — Nextcloud、ownCloud、Synology 以及任何 WebDAV 服务器
- **Amazon S3** — 兼容 S3 的对象存储
- **Box** — Box 云存储

这些会出现在提供商选择器中，并带有“即将推出”标签。

---

## 🏗️ 架构

CLDrive 围绕提供商抽象构建。UI 层从不接触特定提供商的 API——它面向接口通信，工厂在运行时提供正确的实现。

```
UI（页面/组件）
  → ViewModels
    → CloudProviderFactory
      → ICloudProvider 实现
        → Core（HttpClient、TokenStorage、PkceHelper）
```

关键契约：

- **`ICloudProvider`** — 每个提供商实现的统一接口
- **`IAuthProvider`** — OAuth 契约
- **`CloudItem`** — 统一的文件/文件夹模型（从不暴露提供商 DTO）
- **`DownloadInfo`** — 用于下载认证的 URL + 请求头

每个提供商位于自己的文件夹中，包含 **Provider**、**AuthProvider**、**ApiClient**、**Mapper** 和 **Config**。

---

## 🔐 认证与安全

- 所有三个提供商均使用 **OAuth 2.0 授权码流程与 PKCE（S256）**
- OneDrive 和 Dropbox 二进制文件中**无客户端密钥**（PKCE 公共客户端）
- 由于 Google 的 Web 应用 OAuth 客户端类型，Google 需要客户端密钥
- 令牌存储在 **HarmonyOS Asset Store** 中，以 900 字节分块，绕过每个值 1024 字节的限制
- `TokenRefresher` 透明处理 401，并自动刷新
- State 参数验证防止 CSRF
- 仅使用 HTTPS 通信

---

## 🌐 语言

应用 UI 支持 22 种语言。其他语言版本的本文档见 [README 翻译](/CLDrive-HOS/readme/)，完整法律文本见[隐私政策](/CLDrive-HOS/privacy/en/)。

| 语言 | README | 隐私政策 |
|---|---|---|
| 英语 | [index](/CLDrive-HOS/) | [privacy/en](/CLDrive-HOS/privacy/en/) |
| 俄语 | [readme/ru](/CLDrive-HOS/readme/ru/) | [privacy/ru](/CLDrive-HOS/privacy/ru/) |
| 简体中文 | [readme/zh-Hans](/CLDrive-HOS/readme/zh-Hans/) | [privacy/zh-Hans](/CLDrive-HOS/privacy/zh-Hans/) |
| 阿拉伯语 | [readme/ar](/CLDrive-HOS/readme/ar/) | [privacy/ar](/CLDrive-HOS/privacy/ar/) |
| 西班牙语 | [readme/es](/CLDrive-HOS/readme/es/) | [privacy/es](/CLDrive-HOS/privacy/es/) |

其他语言（繁体中文、维吾尔语、藏语、老挝语、日语、韩语、马来语、法语、泰语、越南语、葡萄牙语、印度尼西亚语、德语、土耳其语、意大利语、缅甸语、波兰语）将逐步添加。

---

## 📦 入门

### 先决条件
- DevEco Studio 26.0.0 或更高版本
- HarmonyOS API 26 SDK
- Microsoft、Google 或 Dropbox 开发者账户

### 注册你自己的 OAuth 应用

CLDrive 是公共 OAuth 客户端，每个用户在三个提供商控制台中注册自己的应用。这使用户完全掌控自己的凭据。

**Azure（OneDrive）**
1. Azure Portal → 应用注册 → 新注册
2. 支持的账户类型：多租户 + 个人 Microsoft 账户
3. 重定向 URI：移动和桌面平台 → `https://cl.drive/oauth`
4. 高级设置 → 允许公共客户端流：**是**
5. 委派权限：`Files.ReadWrite`、`User.Read`、`offline_access`

**Google Cloud（Google Drive）**
1. Google Cloud Console → API 和服务 → 凭据 → 创建 OAuth 客户端
2. 应用类型：**Web 应用**
3. 已授权重定向 URI：`http://127.0.0.1:8080/oauth2redirect`
4. 启用 Google Drive API

**Dropbox**
1. Dropbox App Console → 创建应用
2. 作用域访问 → 完整 Dropbox
3. OAuth 2.0 → 重定向 URI → `https://cl.drive/dropbox-oauth`
4. 权限：`account_info.read`、`files.metadata.read`、`files.metadata.write`、`files.content.read`、`files.content.write`

### 构建

```bash
git clone https://github.com/sharjeel-butt/CLDrive-HOS
cd CLDrive-HOS
# 在 DevEco Studio 中打开，然后在设备或模拟器上运行
```

---

## 🗺️ 路线图

- [x] OneDrive 支持
- [x] Google Drive 支持
- [x] Dropbox 支持
- [x] 多账户侧边栏
- [x] 浅色 / 深色 / 系统主题
- [x] 持久化任务面板
- [x] 离线文件
- [x] 重试机制
- [x] 网格 / 列表视图切换
- [x] 筛选标签和排序菜单
- [x] 按账户的存储和缓存概览
- [x] SVG 图标集
- [x] 共享文件徽标
- [x] 22 种语言 UI
- [ ] WebDAV 提供商
- [ ] S3 提供商
- [ ] Box 提供商

---

## 📄 许可证与隐私

- **隐私政策** — [英语](/CLDrive-HOS/privacy/en/)
- **源代码** — [github.com/sharjeel-butt/CLDrive-HOS](https://github.com/sharjeel-butt/CLDrive-HOS)
- **问题反馈** — [github.com/sharjeel-butt/CLDrive-HOS/issues](https://github.com/sharjeel-butt/CLDrive-HOS/issues)

## 已应用修复摘要

| 问题 | 之前 | 之后 |
|---|---|---|
| 应用名称不一致 | 全文均为 `CLDrive Manager` | 全文均为 `CLDrive` |
| 版本 | `1.2.1` | `1.4.0` |
| 源代码链接 | `github.com/sharjeel-butt/CLDrive-HOS/privacy/en/` | `github.com/sharjeel-butt/CLDrive-HOS` |
| 构建说明中的仓库名 | `CLDrive Manager-HOS`（带空格） | `CLDrive-HOS` |
| 路线图复选框 | 混用 `☑` / `□` | 统一为 `- [x]` / `- [ ]` |
| 结尾部分 | 格式错误，代码块从未关闭 | 正确格式化的 `License & Privacy` |
| 语言链接 | 英语用 `/CLDrive-HOS/`，其他用相对路径 | 全文统一使用 `/CLDrive-HOS/…` 前缀 |
| 缺失功能 | 未提及网格、筛选标签、排序菜单、存储卡片、按账户缓存、SVG 图标、共享徽标、即将推出的提供商 | 均反映在各自章节下 |