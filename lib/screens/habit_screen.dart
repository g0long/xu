import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../services/theme.dart';
import '../widgets/habit_item_widget.dart';

/// 习惯排序方式
enum HabitSort {
  byCreated,       // 按创建时间
  byStreak,        // 按当前连续天数
  byLongestStreak, // 按历史最长连续
  byCompletion,    // 按完成率
  byName,          // 按名称字母
}

extension HabitSortX on HabitSort {
  String get label {
    switch (this) {
      case HabitSort.byCreated:       return '按创建时间';
      case HabitSort.byStreak:        return '按当前连续';
      case HabitSort.byLongestStreak: return '按最长连续';
      case HabitSort.byCompletion:    return '按完成率';
      case HabitSort.byName:          return '按名称';
    }
  }
}

/// 习惯页 UI 状态（排序 + 过滤）
class HabitUiState {
  final HabitSort sort;
  final bool todayOnly;
  const HabitUiState({this.sort = HabitSort.byCreated, this.todayOnly = false});
  HabitUiState copyWith({HabitSort? sort, bool? todayOnly}) =>
      HabitUiState(sort: sort ?? this.sort, todayOnly: todayOnly ?? this.todayOnly);
}

final habitUiProvider = StateProvider<HabitUiState>((ref) => const HabitUiState());

/// 习惯页面
class HabitScreen extends ConsumerWidget {
  const HabitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(habitProvider);
    final ui = ref.watch(habitUiProvider);
    final habits = _applySortAndFilter(all, ui);

    return Scaffold(
      backgroundColor: AppColors.background4,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(ref, ui),
            Expanded(
              child: habits.isEmpty
                  ? _EmptyHabit(filter: ui, allEmpty: all.isEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: habits.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final h = habits[i];
                        return HabitItemWidget(
                          key: ValueKey(h.id),
                          habit: h,
                          onCheckToday: () =>
                              ref.read(habitProvider.notifier).checkInToday(h.id),
                          onEdit: () => _openEditDialog(context, ref, h),
                          onDelete: () => _confirmDelete(context, ref, h),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddDialog(context, ref),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
    );
  }

  // ===== 排序与过滤 =====
  List<Habit> _applySortAndFilter(List<Habit> all, HabitUiState ui) {
    var list = List<Habit>.from(all);
    if (ui.todayOnly) {
      list = list.where((h) => !h.isCheckedOn(DateTime.now())).toList();
    }
    switch (ui.sort) {
      case HabitSort.byCreated:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case HabitSort.byStreak:
        list.sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
        break;
      case HabitSort.byLongestStreak:
        list.sort((a, b) => b.longestStreak.compareTo(a.longestStreak));
        break;
      case HabitSort.byCompletion:
        list.sort((a, b) => b.completionRate.compareTo(a.completionRate));
        break;
      case HabitSort.byName:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return list;
  }

  // ===== 顶部标题 =====
  Widget _buildHeader(WidgetRef ref, HabitUiState ui) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const Text(
            '习惯',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          // 第一个按钮：习惯统计面板
          IconButton(
            icon: const Icon(Icons.insert_chart_outlined, color: AppColors.textSecondary),
            tooltip: '习惯统计',
            onPressed: () => _showHabitStats(ref.context, ref),
          ),
          // 第二个按钮：排序/筛选菜单（真正生效）
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.textSecondary),
            tooltip: '排序与筛选',
            onPressed: () => _showFilterMenu(ref.context, ref, ui),
          ),
        ],
      ),
    );
  }

  // ===== 习惯统计面板（底部弹层）=====
  Future<void> _showHabitStats(BuildContext context, WidgetRef ref) async {
    final habits = ref.read(habitProvider);
    final now = DateTime.now();

    int todayDone = 0;
    int totalCheckIns = 0;
    int longestStreak = 0;
    double avgRate = 0;
    for (final h in habits) {
      if (h.isCheckedOn(now)) todayDone++;
      totalCheckIns += h.checkIns.values.where((v) => v).length;
      if (h.longestStreak > longestStreak) longestStreak = h.longestStreak;
      avgRate += h.completionRate;
    }
    if (habits.isNotEmpty) avgRate /= habits.length;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('习惯统计', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Row(
                children: [
                  _statBox('习惯总数', '${habits.length}', '项', AppColors.accent),
                  _statBox('今日完成', '$todayDone', '/${habits.length}', AppColors.success),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statBox('平均完成率', '${(avgRate * 100).toStringAsFixed(0)}', '%', AppColors.accent2),
                  _statBox('最长连续', '$longestStreak', '天', AppColors.warning),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 16),
              const Text('累计打卡', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              Text('$totalCheckIns 次', style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              if (habits.isNotEmpty) ...[
                const Text('各习惯连续天数', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 10),
                ...habits.map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(h.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(h.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          Text('${h.currentStreak} 天', style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('还没有习惯数据', style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background4,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(width: 4),
                Text(unit, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== 排序 + 筛选菜单 =====
  Future<void> _showFilterMenu(BuildContext context, WidgetRef ref, HabitUiState ui) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.textMuted2, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Text('排序方式', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            for (final s in HabitSort.values)
              _sortTile(ctx, ref, s, ui.sort == s),
            const Divider(color: AppColors.divider, height: 1),
            ListTile(
              leading: Icon(
                ui.todayOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: ui.todayOnly ? AppColors.accent : AppColors.textSecondary,
                size: 20,
              ),
              title: const Text('只看今日未完成', style: TextStyle(color: AppColors.textPrimary)),
              trailing: Switch(
                value: ui.todayOnly,
                onChanged: (v) {
                  ref.read(habitUiProvider.notifier).state = ui.copyWith(todayOnly: v);
                  Navigator.pop(ctx);
                },
                activeColor: AppColors.accent,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _sortTile(BuildContext ctx, WidgetRef ref, HabitSort sort, bool selected) {
    IconData icon;
    switch (sort) {
      case HabitSort.byCreated:       icon = Icons.schedule; break;
      case HabitSort.byStreak:        icon = Icons.local_fire_department_outlined; break;
      case HabitSort.byLongestStreak: icon = Icons.emoji_events_outlined; break;
      case HabitSort.byCompletion:    icon = Icons.percent; break;
      case HabitSort.byName:          icon = Icons.sort_by_alpha; break;
    }
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.accent : AppColors.textSecondary, size: 20),
      title: Text(sort.label, style: TextStyle(color: selected ? AppColors.accent : AppColors.textPrimary)),
      trailing: selected ? const Icon(Icons.check, color: AppColors.accent, size: 18) : null,
      onTap: () {
        ref.read(habitUiProvider.notifier).state =
            ref.read(habitUiProvider).copyWith(sort: sort);
        Navigator.pop(ctx);
      },
    );
  }

  // ===== 新建对话框 =====
  Future<void> _openAddDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    String emoji = '💧';
    int colorIndex = 0;
    HabitFrequency frequency = HabitFrequency.daily;
    int weeklyTarget = 7;

    const emojis = ['💧', '📚', '🏃', '🧘', '😴', '🥗', '✍️', '🎵', '💪', '🚴', '🧠', '☀️'];
    const colors = [AppColors.accent, AppColors.purple, AppColors.success, AppColors.warning, AppColors.danger, AppColors.accent2, AppColors.accent3];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: const Text('新建习惯'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '习惯名称（例：早起喝一杯水）'),
                ),
                const SizedBox(height: 16),
                const Text('选择图标', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: emojis.map((e) {
                    final selected = e == emoji;
                    return GestureDetector(
                      onTap: () => setSt(() => emoji = e),
                      child: Container(
                        width: 40, height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.accent.withOpacity( 0.2) : AppColors.secondaryBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? AppColors.accent : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('主题色', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: List.generate(colors.length, (i) {
                    final selected = i == colorIndex;
                    return GestureDetector(
                      onTap: () => setSt(() => colorIndex = i),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: colors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text('频率', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _freqChip(ctx, '每日', frequency == HabitFrequency.daily, () {
                        setSt(() => frequency = HabitFrequency.daily);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _freqChip(ctx, '每周 N 次', frequency == HabitFrequency.weeklyNTimes, () {
                        setSt(() => frequency = HabitFrequency.weeklyNTimes);
                      }),
                    ),
                  ],
                ),
                if (frequency == HabitFrequency.weeklyNTimes) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('每周目标：', style: TextStyle(color: AppColors.textSecondary)),
                      IconButton(
                        onPressed: weeklyTarget > 1 ? () => setSt(() => weeklyTarget--) : null,
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
                      ),
                      Text('$weeklyTarget', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                      IconButton(
                        onPressed: weeklyTarget < 7 ? () => setSt(() => weeklyTarget++) : null,
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('习惯名称不能为空')),
                  );
                  return;
                }
                ref.read(habitProvider.notifier).add(
                      name: nameCtrl.text,
                      emoji: emoji,
                      colorIndex: colorIndex,
                      frequency: frequency,
                      weeklyTarget: weeklyTarget,
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

  Widget _freqChip(BuildContext ctx, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity( 0.2) : AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ===== 编辑对话框 =====
  Future<void> _openEditDialog(BuildContext context, WidgetRef ref, Habit habit) async {
    final nameCtrl = TextEditingController(text: habit.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑习惯'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: '习惯名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('习惯名称不能为空')),
                );
                return;
              }
              ref.read(habitProvider.notifier).update(id: habit.id, name: nameCtrl.text);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Habit habit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除习惯'),
        content: Text('确定要删除"${habit.name}"吗？所有打卡记录将一并清除。'),
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
      ref.read(habitProvider.notifier).remove(habit.id);
    }
  }
}

class _EmptyHabit extends StatelessWidget {
  final HabitUiState filter;
  final bool allEmpty;
  const _EmptyHabit({required this.filter, required this.allEmpty});

  @override
  Widget build(BuildContext context) {
    if (allEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: AppColors.textMuted2),
            const SizedBox(height: 16),
            const Text('还没有习惯', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('点击右下角 + 添加你的第一个习惯',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: AppColors.textMuted2),
          const SizedBox(height: 14),
          const Text('今日已全部打卡 ✨', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('关闭筛选查看全部习惯', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
