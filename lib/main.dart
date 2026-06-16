import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/hive_service.dart';

/// 应用入口
///
/// 启动流程：
/// 1. 初始化 Flutter 绑定
/// 2. 加载 intl 中文 locale 数据（用于日期中文格式化）
/// 3. 初始化 Hive：注册自定义 TypeAdapter、打开所有数据 Box
/// 4. 启动 Riverpod 作用域并加载根 App
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  await HiveService.init();
  runApp(const ProviderScope(child: TodoApp()));
}
