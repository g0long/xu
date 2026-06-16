import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../models/todo.dart';
import '../providers/diary_provider.dart';
import '../providers/focus_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/todo_provider.dart';
import '../services/theme.dart';
import '../widgets/todo_item_widget.dart';

/// 待办页面
///
/// 4 个 Tab：收集箱（默认） / 今日 / 计划（按月分组） / 已完成（可删除）
class TodoScreen extends ConsumerStatefulWidget {
  const TodoScreen({super.key});

  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
  int _filterIndex = 0; // 0=收集箱 1=今日 2=计划 3=已完成

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(todoProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSayingBanner(ref),
            _buildFilterChips(),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(all)),
          ],
        ),
      ),
      floatingActionButton: _filterIndex == 3
          ? null // 已完成页面不需要 FAB
          : FloatingActionButton(
              onPressed: _openAddDialog,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.add, size: 32, color: Colors.white),
            ),
    );
  }

  // ===== 顶部金句横幅（昨天日记的 saying）=====
  Widget _buildSayingBanner(WidgetRef ref) {
    final saying = ref.watch(yesterdaySayingProvider);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('“', style: TextStyle(color: AppColors.accent, fontSize: 22, height: 1)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              saying,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Text('”', style: TextStyle(color: AppColors.accent, fontSize: 22, height: 1)),
        ],
      ),
    );
  }

  // ===== 内容分发 =====
  Widget _buildBody(List<Todo> all) {
    switch (_filterIndex) {
      case 0:
      case 1:
        return _buildRegularList(_applyInboxOrToday(all, _filterIndex));
      case 2:
        return _buildPlannedList(_applyPlanned(all));
      case 3:
        return _buildCompletedList(all.where((t) => t.isDone).toList());
    }
    return const SizedBox.shrink();
  }

  // ===== 顶部标题 =====
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(
            '待办',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 4 个筛选 chips =====
  Widget _buildFilterChips() {
    const filters = [
      ('收集箱', Icons.inbox_outlined),
      ('今日', Icons.today),
      ('计划', Icons.event),
      ('已完成', Icons.check_circle_outline),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = _filterIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.secondaryBg : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? Colors.transparent : AppColors.divider,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filters[i].$2,
                    size: 16,
                    color: selected ? AppColors.textPrimary : AppColors.textMuted2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filters[i].$1,
                    style: TextStyle(
                      color: selected ? AppColors.textPrimary : AppColors.textMuted2,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== 过滤逻辑 =====
  // 0 收集箱：dueDate == null
  // 1 今日：dueDate = 今天
  // 2 计划：dueDate > 今天（按月分组）
  // 3 已完成：isDone == true
  List<Todo> _applyInboxOrToday(List<Todo> all, int idx) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final byDate = switch (idx) {
      0 => all.where((t) => t.dueDate == null).toList(),
      1 => all.where((t) =>
          t.dueDate != null && !t.dueDate!.isBefore(today) && t.dueDate!.isBefore(tomorrow)).toList(),
      _ => all,
    };
    return byDate.where((t) => !t.isDone).toList();
  }

  List<Todo> _applyPlanned(List<Todo> all) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return all.where((t) => t.dueDate != null && !t.dueDate!.isBefore(tomorrow) && !t.isDone).toList();
  }

  // ===== 收集箱 / 今日 =====
  Widget _buildRegularList(List<Todo> todos) {
    if (todos.isEmpty) return _EmptyTodo(filterIndex: _filterIndex);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: todos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = todos[i];
        return TodoItemWidget(
          key: ValueKey(t.id),
          todo: t,
          onComplete: () => ref.read(todoProvider.notifier).toggle(t.id),
          onExpand: () => ref.read(todoProvider.notifier).toggleExpand(t.id),
          onEdit: () => _openEditDialog(t),
          onDelete: () => _confirmDelete(t),
          onEnterFocus: () => _enterFocusMode(t),
          onAddSubtask: (title) => ref.read(todoProvider.notifier).addSubtask(t.id, title),
          onCompleteSubtask: (subId) => ref.read(todoProvider.notifier).toggle(subId, parentId: t.id),
          onDeleteSubtask: (subId) => ref.read(todoProvider.notifier).removeSubtask(t.id, subId),
        );
      },
    );
  }

  // ===== 计划（按月分组，对齐样图 计划.jpg）=====
  Widget _buildPlannedList(List<Todo> todos) {
    if (todos.isEmpty) return const _EmptyTodo(filterIndex: 2);

    // 按 yyyy-MM 分组
    final groups = <String, List<Todo>>{};
    for (final t in todos) {
      if (t.dueDate == null) continue;
      final k = '${t.dueDate!.year}-${t.dueDate!.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(k, () => []).add(t);
    }
    final keys = groups.keys.toList()..sort();

    // 拼成 widget 列表
    final items = <Widget>[];
    for (final k in keys) {
      final parts = k.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      items.add(_monthHeader(year, month));
      final list = groups[k]!..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      for (final t in list) {
        items.add(_plannedTile(t));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: items,
    );
  }

  Widget _monthHeader(int year, int month) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      child: Row(
        children: [
          Text(
            '$month月',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$year',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _plannedTile(Todo t) {
    return Slidable(
      key: ValueKey('planned-${t.id}'),
      groupTag: 'todo-list',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _enterFocusMode(t),
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            icon: Icons.play_arrow,
            label: '专注',
            autoClose: true,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(0)),
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(t),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: '删除',
            autoClose: true,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(0)),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openEditDialog(t),
        onLongPress: () => _confirmDelete(t),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 大数字日期
              SizedBox(
                width: 44,
                child: Text(
                  '${t.dueDate!.day}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 星期（青色，对齐样图）
              SizedBox(
                width: 36,
                child: Text(
                  _weekdayShort(t.dueDate!),
                  style: const TextStyle(color: AppColors.accent, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              // 任务标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (t.tag?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(t.tag!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ),
              // 距离天数
              if (_daysUntil(t.dueDate!) > 0)
                Text(
                  '${_daysUntil(t.dueDate!)}天后',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayShort(DateTime d) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[d.weekday - 1];
  }

  int _daysUntil(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    return target.difference(today).inDays;
  }

  // ===== 已完成 =====
  Widget _buildCompletedList(List<Todo> doneTodos) {
    if (doneTodos.isEmpty) return const _EmptyTodo(filterIndex: 3);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: doneTodos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = doneTodos[i];
        return Slidable(
          key: ValueKey('done-${t.id}'),
          groupTag: 'todo-list',
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.3,
            children: [
              SlidableAction(
                onPressed: (_) => _confirmDelete(t),
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: '删除',
                autoClose: true,
                borderRadius: BorderRadius.circular(16),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // 完成的勾
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '完成于 ${DateFormat('MM/dd HH:mm').format(t.updatedAt)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmDelete(t),
                  icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== 添加对话框 =====
  Future<void> _openAddDialog() async {
    final titleCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    DateTime? dueDate;
    int colorIndex = 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: const Text('新建任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '任务名称',
                    prefixIcon: Icon(Icons.edit, size: 18, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagCtrl,
                  decoration: const InputDecoration(
                    hintText: '标签（可选）',
                    prefixIcon: Icon(Icons.label_outline, size: 18, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            builder: (c, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(primary: AppColors.accent),
                              ),
                              child: child!,
                            ),
                          );
                          if (d != null) setSt(() => dueDate = d);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          dueDate == null
                              ? '选择截止日期'
                              : DateFormat('MM/dd').format(dueDate!),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (dueDate != null)
                      IconButton(
                        onPressed: () => setSt(() => dueDate = null),
                        icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('任务名称不能为空')),
                  );
                  return;
                }
                ref.read(todoProvider.notifier).add(
                      title: titleCtrl.text,
                      tag: tagCtrl.text.trim().isEmpty ? null : tagCtrl.text.trim(),
                      dueDate: dueDate,
                      colorIndex: colorIndex,
                    );
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('添加', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  // ===== 编辑对话框 =====
  Future<void> _openEditDialog(Todo todo) async {
    final titleCtrl = TextEditingController(text: todo.title);
    final tagCtrl = TextEditingController(text: todo.tag ?? '');
    DateTime? dueDate = todo.dueDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: const Text('编辑任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(hintText: '任务名称'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagCtrl,
                  decoration: const InputDecoration(hintText: '标签（可选）'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setSt(() => dueDate = d);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(dueDate == null ? '选择截止日期' : DateFormat('MM/dd').format(dueDate!)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (dueDate != null)
                      IconButton(
                        onPressed: () => setSt(() => dueDate = null),
                        icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('任务名称不能为空')),
                  );
                  return;
                }
                ref.read(todoProvider.notifier).update(
                      id: todo.id,
                      title: titleCtrl.text,
                      tag: tagCtrl.text.trim().isEmpty ? null : tagCtrl.text.trim(),
                      dueDate: dueDate,
                    );
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('保存', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _confirmDelete(Todo todo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除"${todo.title}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(todoProvider.notifier).remove(todo.id);
    }
  }

  /// 进入专注模式：设置任务名 + 跳转到专注 Tab
  void _enterFocusMode(Todo t) {
    // 把任务名写入 FocusState，专注页时长上面就会显示
    ref.read(focusProvider.notifier).setTaskName(t.title);
    ref.read(currentTabIndexProvider.notifier).state = 3; // 专注 Tab
  }
}

// ============================================================
// 空状态
// ============================================================
class _EmptyTodo extends StatelessWidget {
  final int filterIndex;
  const _EmptyTodo({required this.filterIndex});

  String get _title {
    switch (filterIndex) {
      case 0:
        return '收集箱是空的';
      case 1:
        return '今天没有任务';
      case 2:
        return '计划是空的';
      case 3:
        return '还没有完成的任务';
      default:
        return '暂无任务';
    }
  }

  String get _subtitle {
    switch (filterIndex) {
      case 0:
        return '点击右下角 + 快速记下你的灵感';
      case 1:
        return '享受轻松的一天吧 ✨';
      case 2:
        return '点 + 规划未来要做的事';
      case 3:
        return '勾选完成任务后会自动归档到这里';
      default:
        return '';
    }
  }

  IconData get _icon {
    switch (filterIndex) {
      case 0:
        return Icons.inbox_outlined;
      case 1:
        return Icons.today;
      case 2:
        return Icons.event;
      case 3:
        return Icons.check_circle_outline;
      default:
        return Icons.inbox_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 64, color: AppColors.textMuted2),
          const SizedBox(height: 16),
          Text(_title, style: const TextStyle(color: AppColors.textMuted, fontSize: 16)),
          const SizedBox(height: 4),
          Text(_subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
