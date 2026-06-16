import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/habit.dart';
import '../services/hive_service.dart';
import '../services/webdav_sync_service.dart';

class HabitNotifier extends StateNotifier<List<Habit>> {
  HabitNotifier() : super(<Habit>[]) {
    _load();
  }

  static const _uuid = Uuid();

  void _load() {
    final list = HiveService.habitBox.values.toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = list;
  }

  /// Called after sync download to refresh UI
  void reload() {
    _load();
  }

  Future<void> add({
    required String name,
    String emoji = '💧',
    int colorIndex = 0,
    HabitFrequency frequency = HabitFrequency.daily,
    int weeklyTarget = 7,
  }) async {
    if (name.trim().isEmpty) return;
    final h = Habit(
      id: _uuid.v4(),
      name: name.trim(),
      emoji: emoji,
      colorIndex: colorIndex,
      frequency: frequency,
      weeklyTarget: weeklyTarget,
    );
    await HiveService.habitBox.put(h.id, h);
    _load();
  }

  /// 切换某天打卡
  Future<void> toggleCheckIn(String id, DateTime date) async {
    final h = HiveService.habitBox.get(id);
    if (h == null) return;
    h.toggleCheckIn(date);
    await h.save();
    _load();
  }

  /// 一键打卡今天
  Future<void> checkInToday(String id) async {
    await toggleCheckIn(id, DateTime.now());
  }

  Future<void> update({
    required String id,
    String? name,
    String? emoji,
    int? colorIndex,
    HabitFrequency? frequency,
    int? weeklyTarget,
  }) async {
    final h = HiveService.habitBox.get(id);
    if (h == null) return;
    if (name != null && name.trim().isNotEmpty) h.name = name.trim();
    if (emoji != null) h.emoji = emoji;
    if (colorIndex != null) h.colorIndex = colorIndex;
    if (frequency != null) h.frequency = frequency;
    if (weeklyTarget != null) h.weeklyTarget = weeklyTarget;
    await h.save();
    _load();
  }

  Future<void> remove(String id) async {
    await WebDavSyncService.writeTombstone('habits', id);
    await HiveService.habitBox.delete(id);
    _load();
  }
}

final habitProvider = StateNotifierProvider<HabitNotifier, List<Habit>>((ref) {
  return HabitNotifier();
});

/// 派生：所有习惯的整体完成率
final habitOverallCompletionProvider = Provider<double>((ref) {
  final list = ref.watch(habitProvider);
  if (list.isEmpty) return 0;
  final rates = list.map((h) => h.completionRate).toList();
  return rates.reduce((a, b) => a + b) / rates.length;
});

/// 派生：最长连续打卡记录
final habitLongestStreakProvider = Provider<int>((ref) {
  final list = ref.watch(habitProvider);
  if (list.isEmpty) return 0;
  return list.map((h) => h.longestStreak).reduce((a, b) => a > b ? a : b);
});

/// 派生：每个习惯的当前连续天数（用于排行榜）
final habitStreakListProvider = Provider<List<({String name, String emoji, int streak, int longest})>>((ref) {
  final list = ref.watch(habitProvider);
  return list
      .map((h) => (name: h.name, emoji: h.emoji, streak: h.currentStreak, longest: h.longestStreak))
      .toList()
    ..sort((a, b) => b.streak.compareTo(a.streak));
});

/// 派生：本周习惯打卡总数
final thisWeekHabitChecksProvider = Provider<int>((ref) {
  final list = ref.watch(habitProvider);
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  int count = 0;
  for (final h in list) {
    for (final entry in h.checkIns.entries) {
      if (!entry.value) continue;
      final d = DateTime.tryParse(entry.key);
      if (d != null && !d.isBefore(weekStart)) count++;
    }
  }
  return count;
});
