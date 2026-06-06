# NeoAnt 客户端安装指南

## 获取安装包

从 GitHub Actions 产物下载：

```
https://github.com/zhaocaimao008/neo-ant/actions/runs/27050859968
```

| 文件 | 大小 |
|------|------|
| NeoAnt-Android-v1.0.0.zip → 解压得 app-release.apk | 27MB |
| NeoAnt-Windows-v1.0.0.zip → 解压运行 neo_ant.exe | 13MB |
| NeoAnt-iOS-v1.0.0.zip → 解压得 .ipa 文件 | 7.4MB |

---

## Android

1. 解压 ZIP，得到 `app-release.apk`
2. 复制到手机上，打开文件管理器安装
3. 如果提示"未知来源"，在设置中允许安装未知应用
4. 打开应用，自动连接 `https://dipsin.com`

> 注：这是 release 签名 APK，无需 root

---

## Windows

1. 解压 ZIP 到任意目录（如 `C:\NeoAnt\`）
2. 双击运行 `neo_ant.exe`
3. 防火墙弹窗时允许网络访问
4. 应用启动后自动连接 `https://dipsin.com`

> 注：绿色便携版，无需安装，删除目录即卸载

---

## iOS（未签名 IPA）

CI 打包的 IPA **未经过 Apple 签名**，无法直接在未越狱设备上通过普通方式安装。以下是三种推荐方案：

### 方案 A：爱思助手（推荐，无需越狱）

1. 电脑安装 **爱思助手**（https://www.i4.cn）
2. 数据线连接 iPhone
3. 爱思助手 → 工具箱 → IPA 签名
4. 导入 `neo-ant.ipa`
5. 登录你的 Apple ID（仅签名用，建议使用备用 ID）
6. 签名成功后 → 打开爱思助手"我的设备" → 应用游戏 → 导入安装
7. 安装后去 设置 → 通用 → VPN与设备管理 → 信任证书
8. 七天有效，到期重复以上步骤

### 方案 B：TrollStore 巨魔商店（推荐，永久有效）

**前提：** 设备需支持 TrollStore（iOS 14.0 - 16.6.1，部分 17.0）
1. 已安装 TrollStore 的设备，直接分享 `.ipa` 文件到 TrollStore
2. TrollStore 会自动安装并永久签名

### 方案 C：AltStore

1. 电脑安装 AltServer（https://altstore.io）
2. iPhone 安装 AltStore
3. AltStore 中导入 IPA
4. 签名安装（7天有效）

---

## 验证连接

安装后打开应用，确认能正常登录、收发消息。服务器地址已硬编码为 `https://dipsin.com`，无需手动配置。
