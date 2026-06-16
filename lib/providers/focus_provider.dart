import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/focus_session.dart';
import '../services/hive_service.dart';
import '../services/webdav_sync_service.dart';

/// 计时器模式
enum FocusMode { focus, shortBreak, longBreak }

/// 计时器状态
class FocusState {
  final FocusMode mode;
  final int remainingSeconds;
  final bool isRunning;
  final int totalSecondsForCurrentCycle;

  // ===== 用户设置 =====
  final bool autoStart;        // 自动开始下一轮
  final bool whiteNoise;       // 白噪音开关
  final bool dndMode;          // 勿扰模式
  final int focusSeconds;      // 自定义专注时长
  final int shortBreakSeconds; // 自定义短休息时长
  final int longBreakSeconds;  // 自定义长休息时长

  // ===== 当前专注任务 =====
  // 为 null 时显示默认"专注"，从待办进入时会填入任务标题，用户可双击修改
  final String? taskName;

  // ===== 持久化数据（让 UI 通过 watch state 自动更新）=====
  // 所有专注记录（按时间倒序）。删除/新增会更新这个列表，UI 自动刷新。
  final List<FocusSession> sessions;

  const FocusState({
    required this.mode,
    required this.remainingSeconds,
    required this.isRunning,
    required this.totalSecondsForCurrentCycle,
    this.autoStart = false,
    this.whiteNoise = false,
    this.dndMode = false,
    this.focusSeconds = 25 * 60,
    this.shortBreakSeconds = 5 * 60,
    this.longBreakSeconds = 15 * 60,
    this.taskName,
    this.sessions = const <FocusSession>[],
  });

  double get progress =>
      totalSecondsForCurrentCycle == 0 ? 0 : 1 - remainingSeconds / totalSecondsForCurrentCycle;

  /// 显示用的任务名：null 或空都显示"专注"
  String get displayTaskName => (taskName == null || taskName!.isEmpty) ? '专注' : taskName!;

  FocusState copyWith({
    FocusMode? mode,
    int? remainingSeconds,
    bool? isRunning,
    int? totalSecondsForCurrentCycle,
    bool? autoStart,
    bool? whiteNoise,
    bool? dndMode,
    int? focusSeconds,
    int? shortBreakSeconds,
    int? longBreakSeconds,
    String? taskName,
    bool clearTaskName = false,
    List<FocusSession>? sessions,
  }) {
    return FocusState(
      mode: mode ?? this.mode,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      totalSecondsForCurrentCycle: totalSecondsForCurrentCycle ?? this.totalSecondsForCurrentCycle,
      autoStart: autoStart ?? this.autoStart,
      whiteNoise: whiteNoise ?? this.whiteNoise,
      dndMode: dndMode ?? this.dndMode,
      focusSeconds: focusSeconds ?? this.focusSeconds,
      shortBreakSeconds: shortBreakSeconds ?? this.shortBreakSeconds,
      longBreakSeconds: longBreakSeconds ?? this.longBreakSeconds,
      taskName: clearTaskName ? null : (taskName ?? this.taskName),
      sessions: sessions ?? this.sessions,
    );
  }
}

class FocusNotifier extends StateNotifier<FocusState> {
  FocusNotifier()
      : super(const FocusState(
          mode: FocusMode.focus,
          remainingSeconds: 25 * 60,
          isRunning: false,
          totalSecondsForCurrentCycle: 25 * 60,
        )) {
    _loadSessions();
  }

  // 默认时长（秒）
  static const int defaultFocusSec = 25 * 60;
  static const int defaultShortBreakSec = 5 * 60;
  static const int defaultLongBreakSec = 15 * 60;

  Timer? _timer;
  static const _uuid = Uuid();

  // 当前正在进行的 focus 会话起始时间（用于记录部分时长）
  DateTime? _sessionStart;

  void _loadSessions() {
    final list = HiveService.focusBox.values.toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    // ★ 通过更新 state 触发 UI 重建
    state = state.copyWith(sessions: list);
  }

  /// Called after sync download to refresh UI
  void reload() {
    _loadSessions();
  }

  void start() {
    if (state.isRunning) return;
    // 进入 focus 模式时记下会话起点（仅一次）
    if (state.mode == FocusMode.focus && _sessionStart == null) {
      _sessionStart = DateTime.now();
    }
    state = state.copyWith(isRunning: true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    _timer?.cancel();
    if (!state.isRunning) return;
    // 暂停时记录已专注的时长（即使是部分）
    _recordCurrentSession(completed: false);
    state = state.copyWith(isRunning: false);
  }

  void reset() {
    _timer?.cancel();
    // 重置时也记录已专注的时长
    _recordCurrentSession(completed: false);
    state = state.copyWith(
      remainingSeconds: _secondsOf(state.mode),
      isRunning: false,
      totalSecondsForCurrentCycle: _secondsOf(state.mode),
    );
  }

  /// 切换模式（不自动开始）
  void switchMode(FocusMode mode) {
    _timer?.cancel();
    // 切换模式时记录之前的会话
    _recordCurrentSession(completed: false);
    state = state.copyWith(
      mode: mode,
      remainingSeconds: _secondsOf(mode),
      isRunning: false,
      totalSecondsForCurrentCycle: _secondsOf(mode),
    );
  }

  void _tick() {
    final next = state.remainingSeconds - 1;
    if (next <= 0) {
      _timer?.cancel();
      // 发出"剩余 0"的状态
      state = state.copyWith(remainingSeconds: 0, isRunning: false);
      // 完整跑完一轮：记录为 completed
      _recordCurrentSession(completed: true);
      // 重置为当前模式的时长，不自动切换模式
      final total = _secondsOf(state.mode);
      state = state.copyWith(
        remainingSeconds: total,
        totalSecondsForCurrentCycle: total,
      );
    } else {
      state = state.copyWith(remainingSeconds: next);
    }
  }

  /// 记录当前会话：部分时长或完整时长都会记录
  Future<void> _recordCurrentSession({required bool completed}) async {
    // 只记录 focus 模式
    if (_sessionStart == null) return;
    final start = _sessionStart!;
    final elapsed = DateTime.now().difference(start).inSeconds;
    _sessionStart = null;
    if (elapsed <= 0) return;
    final s = FocusSession(
      id: _uuid.v4(),
      startTime: start,
      durationSeconds: elapsed,
      completed: completed,
      mode: 'focus',
      taskName: state.taskName, // ★ 记录当时的任务名
    );
    await HiveService.focusBox.put(s.id, s);
    _loadSessions();
  }

  int _secondsOf(FocusMode m) {
    switch (m) {
      case FocusMode.focus:
        return state.focusSeconds;
      case FocusMode.shortBreak:
        return state.shortBreakSeconds;
      case FocusMode.longBreak:
        return state.longBreakSeconds;
    }
  }

  // ===== 用户设置 =====
  void toggleAutoStart() => state = state.copyWith(autoStart: !state.autoStart);
  void toggleWhiteNoise() => state = state.copyWith(whiteNoise: !state.whiteNoise);
  void toggleDnd() => state = state.copyWith(dndMode: !state.dndMode);

  /// 设置当前专注的任务名（从待办进入时调用）
  /// 传 null 或空字符串则清除，恢复默认"专注"
  void setTaskName(String? name) {
    if (name == null || name.trim().isEmpty) {
      state = state.copyWith(clearTaskName: true);
    } else {
      state = state.copyWith(taskName: name.trim());
    }
  }

  /// 应用自定义时长（分钟）
  void setCustomDurations({int? focusMin, int? shortMin, int? longMin}) {
    _timer?.cancel();
    final newFocus = (focusMin ?? state.focusSeconds ~/ 60) * 60;
    final newShort = (shortMin ?? state.shortBreakSeconds ~/ 60) * 60;
    final newLong = (longMin ?? state.longBreakSeconds ~/ 60) * 60;
    final newRemaining = state.mode == FocusMode.focus
        ? newFocus
        : state.mode == FocusMode.shortBreak
            ? newShort
            : newLong;
    state = state.copyWith(
      focusSeconds: newFocus,
      shortBreakSeconds: newShort,
      longBreakSeconds: newLong,
      remainingSeconds: newRemaining,
      isRunning: false,
      totalSecondsForCurrentCycle: newRemaining,
    );
  }

  /// 微调当前会话的剩余时长（delta 单位：秒，正数=增加，负数=减少）
  ///
  /// 仅在计时器未运行时可用。调整后同步更新对应模式的默认时长。
  void adjustCurrentDuration(int deltaSec) {
    if (state.isRunning) return;
    final newRemaining = (state.remainingSeconds + deltaSec).clamp(60, 7200);
    state = state.copyWith(
      remainingSeconds: newRemaining,
      totalSecondsForCurrentCycle: newRemaining,
      focusSeconds: state.mode == FocusMode.focus ? newRemaining : state.focusSeconds,
      shortBreakSeconds: state.mode == FocusMode.shortBreak ? newRemaining : state.shortBreakSeconds,
      longBreakSeconds: state.mode == FocusMode.longBreak ? newRemaining : state.longBreakSeconds,
    );
  }

  // ===== 统计用 =====
  // ★ sessions 来自 state，可被 watch
  List<FocusSession> get sessions => List.unmodifiable(state.sessions);

  /// 删除单条专注记录
  Future<void> removeSession(String id) async {
    await WebDavSyncService.writeTombstone('focus_sessions', id);
    await HiveService.focusBox.delete(id);
    _loadSessions();
  }

  /// 删除某个任务名下的所有专注记录
  /// 未命名（null/空）的会话以"专注"为分组名
  Future<void> removeSessionsByName(String groupName) async {
    final ids = <String>[];
    for (final s in state.sessions) {
      final name = (s.taskName == null || s.taskName!.isEmpty) ? '专注' : s.taskName!;
      if (name == groupName) ids.add(s.id);
    }
    for (final id in ids) {
      await WebDavSyncService.writeTombstone('focus_sessions', id);
      await HiveService.focusBox.delete(id);
    }
    _loadSessions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final focusProvider = StateNotifierProvider<FocusNotifier, FocusState>((ref) {
  return FocusNotifier();
});

/// 派生：今日总专注分钟数
final todayFocusMinutesProvider = Provider<int>((ref) {
  // ★ watch state 而非 notifier，这样删除/新增会触发重算
  final state = ref.watch(focusProvider);
  final now = DateTime.now();
  final sec = state.sessions
      .where((s) =>
          s.startTime.year == now.year &&
          s.startTime.month == now.month &&
          s.startTime.day == now.day)
      .fold<int>(0, (sum, s) => sum + s.durationSeconds);
  return (sec / 60).round();
});

/// 派生：累计专注总分钟
final totalFocusMinutesProvider = Provider<int>((ref) {
  final state = ref.watch(focusProvider);
  final sec = state.sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  return (sec / 60).round();
});

/// 派生：今日专注次数
final todayFocusCountProvider = Provider<int>((ref) {
  final state = ref.watch(focusProvider);
  final now = DateTime.now();
  return state.sessions
      .where((s) =>
          s.completed &&
          s.startTime.year == now.year &&
          s.startTime.month == now.month &&
          s.startTime.day == now.day)
      .length;
});

/// 派生：最近 7 天每天的专注秒数（按从远到近顺序：7天前 ... 今天）
/// ★ 监听 state，删除/新增后自动重算
final last7DaysFocusProvider = Provider<List<int>>((ref) {
  final state = ref.watch(focusProvider);
  final result = List<int>.filled(7, 0);
  final today = DateTime.now();
  for (final s in state.sessions) {
    final daysAgo = DateTime(today.year, today.month, today.day)
        .difference(DateTime(s.startTime.year, s.startTime.month, s.startTime.day))
        .inDays;
    if (daysAgo >= 0 && daysAgo < 7) {
      result[6 - daysAgo] += s.durationSeconds;
    }
  }
  return result;
});

/// 派生：专注时长按任务名分布（用于饼图）
final focusDistributionProvider = Provider<Map<String, int>>((ref) {
  final state = ref.watch(focusProvider);
  final map = <String, int>{};
  for (final s in state.sessions) {
    final key = (s.taskName == null || s.taskName!.isEmpty) ? '专注' : s.taskName!;
    map[key] = (map[key] ?? 0) + s.durationSeconds;
  }
  return map;
});

/// 派生：本周累计专注分钟
final thisWeekFocusMinutesProvider = Provider<int>((ref) {
  final state = ref.watch(focusProvider);
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final sec = state.sessions
      .where((s) => !s.startTime.isBefore(weekStart))
      .fold<int>(0, (sum, s) => sum + s.durationSeconds);
  return (sec / 60).round();
});

/// 派生：上周累计专注分钟
final lastWeekFocusMinutesProvider = Provider<int>((ref) {
  final state = ref.watch(focusProvider);
  final now = DateTime.now();
  final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
  final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
  final sec = state.sessions
      .where((s) => !s.startTime.isBefore(lastWeekStart) && s.startTime.isBefore(thisWeekStart))
      .fold<int>(0, (sum, s) => sum + s.durationSeconds);
  return (sec / 60).round();
});

/// 派生：日均专注分钟数（基于有数据的日期）
final avgDailyFocusMinutesProvider = Provider<double>((ref) {
  final state = ref.watch(focusProvider);
  if (state.sessions.isEmpty) return 0;
  final days = <String>{};
  int total = 0;
  for (final s in state.sessions) {
    final key = '${s.startTime.year}-${s.startTime.month}-${s.startTime.day}';
    days.add(key);
    total += s.durationSeconds;
  }
  if (days.isEmpty) return 0;
  return (total / 60) / days.length;
});

/// 派生：总完成会话数
final totalCompletedSessionsProvider = Provider<int>((ref) {
  final state = ref.watch(focusProvider);
  return state.sessions.where((s) => s.completed).length;
});

/// 派生：今日完成的会话详情列表
final todaySessionsProvider = Provider<List<FocusSession>>((ref) {
  final state = ref.watch(focusProvider);
  final now = DateTime.now();
  return state.sessions
      .where((s) =>
          s.startTime.year == now.year &&
          s.startTime.month == now.month &&
          s.startTime.day == now.day)
      .toList();
});
