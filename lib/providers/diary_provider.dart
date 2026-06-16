import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/diary.dart';
import '../services/hive_service.dart';
import '../services/webdav_sync_service.dart';

class DiaryNotifier extends StateNotifier<List<Diary>> {
  DiaryNotifier() : super(<Diary>[]) {
    _load();
  }

  static const _uuid = Uuid();

  void _load() {
    final list = HiveService.diaryBox.values.toList();
    // 按日期倒序（最新在前）
    list.sort((a, b) {
      final d = b.date.compareTo(a.date);
      if (d != 0) return d;
      return b.createdAt.compareTo(a.createdAt);
    });
    state = list;
  }

  /// Called after sync download to refresh UI
  void reload() {
    _load();
  }

  Future<void> add({
    required DateTime date,
    String title = '',
    String content = '',
    String mood = '📝',
    String saying = '',
  }) async {
    if (title.trim().isEmpty && content.trim().isEmpty) return;
    final diary = Diary(
      id: _uuid.v4(),
      date: date,
      title: title.trim(),
      content: content.trim(),
      mood: mood,
      saying: saying.trim(),
    );
    await HiveService.diaryBox.put(diary.id, diary);
    _load();
  }

  Future<void> update({
    required String id,
    DateTime? date,
    String? title,
    String? content,
    String? mood,
    String? saying,
  }) async {
    final d = HiveService.diaryBox.get(id);
    if (d == null) return;
    if (date != null) d.date = date;
    if (title != null) d.title = title;
    if (content != null) d.content = content;
    if (mood != null) d.mood = mood;
    if (saying != null) d.saying = saying;
    d.updatedAt = DateTime.now();
    await d.save();
    _load();
  }

  Future<void> remove(String id) async {
    await WebDavSyncService.writeTombstone('diaries', id);
    await HiveService.diaryBox.delete(id);
    _load();
  }
}

final diaryProvider = StateNotifierProvider<DiaryNotifier, List<Diary>>((ref) {
  return DiaryNotifier();
});

/// 派生：日记总数
final diaryCountProvider = Provider<int>((ref) {
  return ref.watch(diaryProvider).length;
});

/// 派生：所有非空 saying 列表（按更新时间倒序）
final sayingsProvider = Provider<List<Diary>>((ref) {
  return ref
      .watch(diaryProvider)
      .where((d) => d.saying.isNotEmpty)
      .toList();
});

/// 派生：昨天日记的 saying
///
/// 逻辑：找 date == 昨天 且 saying 非空的日记。
/// 如果没有，默认显示"有序，即自由"。
const String kDefaultSaying = '有序，即自由';

final yesterdaySayingProvider = Provider<String>((ref) {
  final entries = ref.watch(diaryProvider);
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
  for (final d in entries) {
    if (d.saying.isNotEmpty &&
        d.date.year == yesterday.year &&
        d.date.month == yesterday.month &&
        d.date.day == yesterday.day) {
      return d.saying;
    }
  }
  return kDefaultSaying;
});
