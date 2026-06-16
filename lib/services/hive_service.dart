import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/todo.dart';
import '../models/habit.dart';
import '../models/focus_session.dart';
import '../models/diary.dart';
import '../models/app_settings.dart';

/// Hive 本地存储封装
class HiveService {
  HiveService._();

  // ===== Box 名称 =====
  static const String boxTodo = 'todos';
  static const String boxHabit = 'habits';
  static const String boxFocus = 'focus_sessions';
  static const String boxDiary = 'diaries';
  static const String boxSettings = 'settings';
  static const String boxTombstones = 'tombstones';

  // ===== 初始化 =====
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);

    // 注册 adapter
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TodoAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HabitAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(FocusSessionAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(HabitFrequencyAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(DiaryAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(AppSettingsAdapter());

    // 逐个打开 box，单个失败不阻塞其他
    await _safeOpen<Todo>(boxTodo);
    await _safeOpen<Habit>(boxHabit);
    await _safeOpen<FocusSession>(boxFocus);
    await _safeOpen<Diary>(boxDiary);
    await _safeOpen<AppSettings>(boxSettings);
    await _safeOpen<String>(boxTombstones);
  }

  /// 安全打开 Box：失败时清空旧数据再重试
  static Future<void> _safeOpen<T>(String name) async {
    try {
      await Hive.openBox<T>(name);
    } catch (e) {
      // 老数据与新 Adapter 不兼容 → 清掉重建
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
      await Hive.openBox<T>(name);
    }
  }

  // ===== Box 访问器 =====
  static Box<Todo> get todoBox => Hive.box<Todo>(boxTodo);
  static Box<Habit> get habitBox => Hive.box<Habit>(boxHabit);
  static Box<FocusSession> get focusBox => Hive.box<FocusSession>(boxFocus);
  static Box<Diary> get diaryBox => Hive.box<Diary>(boxDiary);
  static Box<AppSettings> get settingsBox => Hive.box<AppSettings>(boxSettings);
  static Box<String> get tombstonesBox => Hive.box<String>(boxTombstones);
}
