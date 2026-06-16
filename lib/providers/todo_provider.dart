import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/todo.dart';
import '../services/hive_service.dart';
import '../services/webdav_sync_service.dart';

/// 待办列表状态
///
/// 直接从 Hive Box 中同步读取/写入，避免状态与持久化"双份真相"问题。
/// 每次改动后立刻持久化到磁盘，下次启动时 HiveService.init 时 box 已开，
/// _load() 会自动从 box 拉回数据。
class TodoNotifier extends StateNotifier<List<Todo>> {
  TodoNotifier() : super(<Todo>[]) {
    _load();
  }

  static const _uuid = Uuid();

  void _load() {
    final box = HiveService.todoBox;
    final list = box.values.toList();
    // 按创建时间倒序（新任务在前）
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = list;
  }

  /// Called after sync download to refresh UI
  void reload() {
    _load();
  }

  /// 新增任务（支持子任务）
  Future<void> add({
    required String title,
    DateTime? dueDate,
    String? tag,
    int colorIndex = 0,
    List<String> subtaskTitles = const [],
  }) async {
    if (title.trim().isEmpty) return;
    final todo = Todo(
      id: _uuid.v4(),
      title: title.trim(),
      dueDate: dueDate,
      tag: tag,
      colorIndex: colorIndex,
      subtasks: subtaskTitles
          .where((s) => s.trim().isNotEmpty)
          .map((s) => Todo(id: _uuid.v4(), title: s.trim()))
          .toList(),
    );
    await HiveService.todoBox.put(todo.id, todo);
    _load();
  }

  /// 给现有任务添加子任务
  Future<void> addSubtask(String parentId, String title) async {
    if (title.trim().isEmpty) return;
    final parent = HiveService.todoBox.get(parentId);
    if (parent == null) return;
    parent.subtasks.add(Todo(id: _uuid.v4(), title: title.trim()));
    await parent.save();
    _load();
  }

  /// 切换主任务/子任务完成状态
  Future<void> toggle(String id, {String? parentId}) async {
    if (parentId != null) {
      final parent = HiveService.todoBox.get(parentId);
      if (parent == null) return;
      final sub = parent.subtasks.firstWhere(
        (t) => t.id == id,
        orElse: () => Todo(id: '', title: ''),
      );
      if (sub.id.isEmpty) return;
      sub.isDone = !sub.isDone;
      sub.updatedAt = DateTime.now();
      await parent.save();
    } else {
      final t = HiveService.todoBox.get(id);
      if (t == null) return;
      t.isDone = !t.isDone;
      t.updatedAt = DateTime.now();
      await t.save();
    }
    _load();
  }

  /// 设置/修改任务的截止日期
  /// 传 null 表示清除日期（移回收集箱）
  Future<void> setDate(String id, DateTime? date) async {
    final t = HiveService.todoBox.get(id);
    if (t == null) return;
    t.dueDate = date;
    await t.save();
    _load();
  }

  /// 切换主任务的展开/折叠
  Future<void> toggleExpand(String id) async {
    final t = HiveService.todoBox.get(id);
    if (t == null) return;
    t.isExpanded = !t.isExpanded;
    await t.save();
    _load();
  }

  /// 编辑任务标题 / 截止日期 / 标签
  Future<void> update({
    required String id,
    String? title,
    DateTime? dueDate,
    String? tag,
  }) async {
    final t = HiveService.todoBox.get(id);
    if (t == null) return;
    if (title != null && title.trim().isNotEmpty) t.title = title.trim();
    if (dueDate != null) t.dueDate = dueDate;
    if (tag != null) t.tag = tag;
    t.updatedAt = DateTime.now();
    await t.save();
    _load();
  }

  /// 删除任务（连同子任务）
  Future<void> remove(String id) async {
    await WebDavSyncService.writeTombstone('todos', id);
    await HiveService.todoBox.delete(id);
    _load();
  }

  /// 删除子任务
  Future<void> removeSubtask(String parentId, String subId) async {
    final parent = HiveService.todoBox.get(parentId);
    if (parent == null) return;
    parent.subtasks.removeWhere((t) => t.id == subId);
    await parent.save();
    _load();
  }
}

final todoProvider = StateNotifierProvider<TodoNotifier, List<Todo>>((ref) {
  return TodoNotifier();
});

/// 派生：完成率
final todoCompletionProvider = Provider<double>((ref) {
  final list = ref.watch(todoProvider);
  if (list.isEmpty) return 0;
  // 包括子任务
  int total = 0, done = 0;
  for (final t in list) {
    total += 1 + t.subtasks.length;
    done += (t.isDone ? 1 : 0) + t.doneSubtaskCount;
  }
  if (total == 0) return 0;
  return done / total;
});

/// 派生：今日完成的任务数（含子任务）
final todayDoneCountProvider = Provider<int>((ref) {
  final list = ref.watch(todoProvider);
  final now = DateTime.now();
  int count = 0;
  for (final t in list) {
    final tu = t.updatedAt;
    if (t.isDone && tu != null && tu.year == now.year &&
        tu.month == now.month && tu.day == now.day) {
      count++;
    }
    for (final s in t.subtasks) {
      final su = s.updatedAt;
      if (s.isDone && su != null && su.year == now.year &&
          su.month == now.month && su.day == now.day) {
        count++;
      }
    }
  }
  return count;
});

/// 派生：最近 7 天每日完成任务数（从远到近）
final last7DaysDoneProvider = Provider<List<int>>((ref) {
  final list = ref.watch(todoProvider);
  final result = List<int>.filled(7, 0);
  final today = DateTime.now();
  for (final t in list) {
    _countByDate(t, today, result);
    for (final s in t.subtasks) {
      _countByDate(s, today, result);
    }
  }
  return result;
});

void _countByDate(Todo item, DateTime today, List<int> result) {
  if (!item.isDone) return;
  final d = item.updatedAt ?? DateTime.now();
  final daysAgo = DateTime(today.year, today.month, today.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (daysAgo >= 0 && daysAgo < 7) {
    result[6 - daysAgo]++;
  }
}
