# SF6 招式笔记 - 构建指南

## 前置条件

1. 已安装 Flutter SDK（当前路径 `D:\Env\flutter\flutter`）
2. Windows 开发者模式已开启
3. 安卓构建需要安装 Android SDK

---

## 一、构建 Windows 可执行文件

打开终端，依次执行：

```bash
# 进入项目目录
cd "D:\Learn\sf6 note\sf6_note"

# 安装依赖（首次或依赖变更后）
flutter pub get

# 构建 Release 版本
flutter build windows
```

构建完成后，可执行文件位于：

```
D:\Learn\sf6 note\sf6_note\build\windows\x64\runner\Release\sf6_note.exe
```

### 直接运行调试版本

```bash
cd "D:\Learn\sf6 note\sf6_note"
flutter run -d windows
```

### 分发给其他人

`build\windows\x64\runner\Release\` 文件夹下的所有文件是一个整体，
需要整个文件夹一起拷贝，不能只复制 exe 单文件。

---

## 二、构建安卓 APK

### 方式 A：连接手机直接运行（调试）

1. 手机上开启 **USB 调试**：
   - 设置 → 关于手机 → 连续点击「版本号」7 次
   - 返回 → 开发者选项 → 打开 USB 调试

2. USB 数据线连接手机到电脑

3. 终端执行：
```bash
cd "D:\Learn\sf6 note\sf6_note"

# 查看已连接设备
flutter devices

# 安装并运行
flutter run -d android
```

### 方式 B：构建 APK 安装包

```bash
cd "D:\Learn\sf6 note\sf6_note"

# 构建 Release APK
flutter build apk --release
```

生成的 APK 文件位于：

```
D:\Learn\sf6 note\sf6_note\build\app\outputs\flutter-apk\app-release.apk
```

将 APK 传到手机上，打开安装即可。

---

## 三、常见问题

### Windows 构建失败：需要符号链接

```
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```

解决：打开 Windows 设置 → 隐私和安全性 → 开发者选项 → 开启「开发人员模式」

### 安卓构建失败：找不到 SDK

```
No Android SDK found.
```

解决：
1. 安装 Android Studio：https://developer.android.com/studio
2. 安装后打开 Android Studio → SDK Manager → 安装 SDK
3. 确保 Flutter 能找到 SDK：
```bash
flutter doctor
```

### flutter 命令找不到

确保 Flutter SDK 路径已加入系统环境变量 PATH：
```
D:\Env\flutter\flutter\bin
```

或者在终端中临时添加：
```bash
export PATH="/d/Env/flutter/flutter/bin:$PATH"
```

### 检查环境是否正常

```bash
flutter doctor -v
```

这会列出所有工具的安装状态，逐一修复标红的项目即可。
