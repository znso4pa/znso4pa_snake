# 🐍 znso4pa_snake

一个基于 Flutter 开发的贪吃蛇游戏

![Logo](assets/icon/icon.png)

---

## 🛠️ 安装与运行指引 (Installation Guide)

确保你已安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)，并在终端依次执行以下操作：

### 1. 基础环境配置 (必做)

```bash
# 克隆项目并进入目录
git clone https://github.com/znso4pa/znso4pa_snake.git
cd znso4pa_snake

# 初始化项目依赖 (包含音频插件等)
flutter pub get

# 注入 znso4pa 专属图标 (自动生成各平台资源)
dart run flutter_launcher_icons
```

### 2. 移动端打包与分发 (Android / iOS)

#### 📦 Android (生成 APK)

```bash
# 生成正式版安装包
flutter build apk --release

# APK 路径: build/app/outputs/flutter-apk/app-release.apk
```

#### 📦 iOS (生成 IPA)

注意：需在 macOS 环境下使用 Xcode，且通常需要配置开发者签名。

```bash
# 安装 iOS 相关依赖
cd ios && pod install && cd ..

# 构建 iOS 离线安装包 (IPA)
flutter build ipa --release

# IPA 路径: build/ios/ipa/znso4pa_snake.ipa
```

### 3. 桌面端编译与运行 (macOS / Linux)

```bash
# 开启桌面端支持 (只需执行一次)
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop

# 启动桌面版游戏
flutter run -d macos  # macOS 模式
flutter run -d linux  # Linux 模式

# 构建 macOS 独立应用包 (.app)
flutter build macos --release
# 成品路径: build/macos/Build/Products/Release/znso4pa_snake.app
```