# 🐍 znso4pa_snake

一个基于 Flutter 开发的贪吃蛇游戏

![Logo](assets/icon/icon.png)

---

## 🛠️ 安装指引 (Installation Guide)

如果你是第一次接触 Flutter 的开发者，请确保已安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)，然后依次执行以下命令：

# 1. 克隆项目并进入目录
git clone [https://github.com/znso4pa/znso4pa_snake.git](https://github.com/znso4pa/znso4pa_snake.git)
cd znso4pa_snake

# 2. 初始化项目依赖 (同步 audioplayers 等插件)
flutter pub get

# 3. 注入 znso4pa 专属图标 (自动配置 Android/iOS 图标资源)
dart run flutter_launcher_icons

# 4. 部署与打包 (二选一)

# 方案 A: 如果你有真机/平板，直接连接并运行
flutter run

# 方案 B: 如果没有真机，直接生成正式版 APK 安装包
flutter build apk --release

# APK 成品路径：build/app/outputs/flutter-apk/app-release.apk