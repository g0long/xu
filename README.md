# 序 · Xu

> 万物有序，从容生长

Flutter 打造的极简个人效能工具，集待办、习惯、日记、专注于一身，支持 WebDAV 跨设备云同步。

## 功能模块

| 模块 | 说明 |
|------|------|
| **待办** | 支持子任务、日期标签、颜色标记，滑动操作 |
| **习惯** | 每日打卡、周频模式，连续天数统计 |
| **日记** | 日期 + 心情 + 金句，写过的日子不会辜负你 |
| **专注** | 番茄钟计时器，快速选时 / 滑块调节，专注任务关联 |
| **统计** | 累计专注、完成任务、7 日趋势、习惯排行 |

## 技术栈

- **框架**: Flutter 3.10+
- **状态管理**: Riverpod
- **本地存储**: Hive（手写 TypeAdapter，无 build_runner）
- **云同步**: WebDAV 协议（坚果云等），支持合并上传/下载
- **其他**: fl_chart 图表、audioplayers 音效、intl 日期格式化

## 构建

```bash
# 安装依赖
flutter pub get

# 运行
flutter run

# 打包 APK
flutter build apk --release
```

APK 输出路径：`build/app/outputs/flutter-apk/app-release.apk`

## 云同步配置

1. 注册坚果云（或其他 WebDAV 服务）
2. 在坚果云「账户信息 → 安全选项」生成**应用专用密码**
3. 打开 App → 设置 → 填写：
   - 服务器地址：`dav.jianguoyun.com/dav`
   - 用户名：你的坚果云账号
   - 密码：应用专用密码
   - 备份子目录：`xu_backups`
4. 先点「上传」创建云端备份，之后在其他设备点「下载」即可同步

## 项目结构

```
lib/
├── main.dart              # 入口
├── app.dart               # MaterialApp 配置
├── models/                # 数据模型 + Hive Adapter
│   ├── todo.dart
│   ├── habit.dart
│   ├── diary.dart
│   ├── focus_session.dart
│   └── app_settings.dart
├── providers/             # Riverpod 状态管理
│   ├── todo_provider.dart
│   ├── habit_provider.dart
│   ├── diary_provider.dart
│   ├── focus_provider.dart
│   ├── app_settings_provider.dart
│   └── nav_provider.dart
├── screens/               # 页面
│   ├── home_screen.dart
│   ├── todo_screen.dart
│   ├── habit_screen.dart
│   ├── diary_screen.dart
│   ├── focus_screen.dart
│   ├── statistics_screen.dart
│   └── settings_screen.dart
├── widgets/               # 通用组件
│   ├── todo_item_widget.dart
│   ├── habit_item_widget.dart
│   └── focus_timer_widget.dart
└── services/              # 服务层
    ├── hive_service.dart
    ├── webdav_sync_service.dart
    ├── update_service.dart
    └── theme.dart
```

## 许可证

[Apache License 2.0](LICENSE)
