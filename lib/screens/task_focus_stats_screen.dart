import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/focus_session.dart';
import '../providers/focus_provider.dart';
import '../services/theme.dart';

/// 任务专注统计页
///
/// 按 taskName 分组显示每个任务累计的专注时长 + 会话数。
/// 从专注页右上角"统计"按钮进入。
class TaskFocusStatsScreen extends ConsumerWidget {
  const TaskFocusStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ★ watch state 触发 UI 自动更新（删除/新增后立即重建）
    final sessions = ref.watch(focusProvider).sessions;

    // 1) 按 taskName 分组（null/空归为"专注"）
    final groups = <String, List<FocusSession>>{};
    for (final s in sessions) {
      final key = (s.taskName == null || s.taskName!.isEmpty) ? '专注' : s.taskName!;
      groups.putIfAbsent(key, () => []).add(s);
    }

    // 2) 计算每个分组的总秒数
    final entries = groups.entries.map((e) {
      final total = e.value.fold<int>(0, (sum, s) => sum + s.durationSeconds);
      final completedCount = e.value.where((s) => s.completed).length;
      final lastTime = e.value.first.startTime; // sessions 已按时间倒序
      return _GroupInfo(name: e.key, total: total, sessions: e.value, completed: completedCount, lastTime: lastTime);
    }).toList();

    // 3) 按总时长倒序
    entries.sort((a, b) => b.total.compareTo(a.total));

    final grandTotal = entries.fold<int>(0, (sum, g) => sum + g.total);
    final maxTotal = entries.isEmpty ? 1 : entries.first.total;

    return Scaffold(
      backgroundColor: AppColors.background2,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background2,
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('任务专注统计', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            SliverToBoxAdapter(
              child: _buildSummary(grandTotal, entries.length, sessions.length),
            ),
            if (entries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final g = entries[i];
                    return _TaskCard(
                      info: g,
                      maxTotal: maxTotal,
                      rank: i + 1,
                      onTap: () => _showSessionList(context, g, ref),
                      onLongPress: () => _confirmDeleteGroup(context, ref, g.name),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===== 顶部汇总卡 =====
  Widget _buildSummary(int totalSeconds, int taskCount, int sessionCount) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    String dur;
    if (h > 0) {
      dur = '$h 时 $m 分';
    } else if (m > 0) {
      dur = '$m 分 $s 秒';
    } else {
      dur = '$s 秒';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('累计专注', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            dur,
            style: const TextStyle(
              color: AppColors.accent2,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryItem('专注任务数', '$taskCount', '个'),
              const SizedBox(width: 24),
              _summaryItem('总会话数', '$sessionCount', '次'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, String unit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(width: 4),
        Text(unit, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  // ===== 点击任务卡 → 弹出该任务所有 session 列表，可逐条删除 =====
  Future<void> _showSessionList(BuildContext context, _GroupInfo info, WidgetRef ref) async {
    final notifier = ref.read(focusProvider.notifier);
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.textMuted2, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(info.name,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('共 ${info.sessions.length} 条记录',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (d) => AlertDialog(
                            title: Text('删除"${info.name}"的所有记录'),
                            content: const Text('此操作不可撤销，所有该任务的专注时长都会被删除。'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
                              FilledButton(
                                onPressed: () => Navigator.pop(d, true),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                child: const Text('全部删除'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await notifier.removeSessionsByName(info.name);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.delete_sweep, color: AppColors.danger, size: 18),
                      label: const Text('全部删除', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.divider, height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: info.sessions.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (_, i) => _SessionTile(
                    session: info.sessions[i],
                    onDelete: () => notifier.removeSession(info.sessions[i].id),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 长按任务卡 → 直接弹确认删除整个分组 =====
  Future<void> _confirmDeleteGroup(BuildContext context, WidgetRef ref, String groupName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('删除"$groupName"的所有记录'),
        content: const Text('此操作不可撤销，所有该任务的专注时长都会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('全部删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(focusProvider.notifier).removeSessionsByName(groupName);
    }
  }
}

// ============================================================
// 数据结构
// ============================================================
class _GroupInfo {
  final String name;
  final int total;
  final List<FocusSession> sessions;
  final int completed;
  final DateTime lastTime;
  const _GroupInfo({
    required this.name,
    required this.total,
    required this.sessions,
    required this.completed,
    required this.lastTime,
  });
}

// ============================================================
// 单个任务卡
// ============================================================
class _TaskCard extends StatelessWidget {
  final _GroupInfo info;
  final int maxTotal;
  final int rank;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _TaskCard({
    required this.info,
    required this.maxTotal,
    required this.rank,
    required this.onTap,
    required this.onLongPress,
  });

  String _formatDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h}时${m}分';
    if (m > 0) return '${m}分${s.toString().padLeft(2, '0')}秒';
    return '${s}秒';
  }

  Color _rankColor() {
    switch (rank) {
      case 1: return const Color(0xFFFFD700); // 金
      case 2: return const Color(0xFFC0C0C0); // 银
      case 3: return const Color(0xFFCD7F32); // 铜
      default: return AppColors.textMuted2;
    }
  }

  String _rankLabel() => rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank';

  @override
  Widget build(BuildContext context) {
    final pct = maxTotal == 0 ? 0.0 : info.total / maxTotal;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 排名
                Container(
                  width: 30, height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _rankColor().withOpacity( 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_rankLabel(), style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 10),
                // 任务名
                Expanded(
                  child: Text(
                    info.name,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 总时长
                Text(
                  _formatDuration(info.total),
                  style: const TextStyle(
                    color: AppColors.accent2,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 进度条（占 maxTotal 的比例）
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: AppColors.secondaryBg,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent2),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${info.sessions.length} 次会话  ·  ${info.completed} 次完整',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
                Text(
                  '最近：${DateFormat('MM/dd HH:mm').format(info.lastTime)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textMuted2, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 单条 session 列表项（可逐条删除）
// ============================================================
class _SessionTile extends StatelessWidget {
  final FocusSession session;
  final Future<void> Function() onDelete;
  const _SessionTile({required this.session, required this.onDelete});

  String _formatDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h}时${m}分${s.toString().padLeft(2, '0')}秒';
    if (m > 0) return '${m}分${s.toString().padLeft(2, '0')}秒';
    return '${s}秒';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent2.withOpacity( 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          session.completed ? Icons.check : Icons.timer,
          color: AppColors.accent2,
          size: 18,
        ),
      ),
      title: Text(
        _formatDuration(session.durationSeconds),
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${DateFormat('MM/dd HH:mm').format(session.startTime)}'
        '${session.completed ? '' : '  ·  未完成'}',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 18),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('删除该专注记录'),
              content: Text(
                '将删除 ${_formatDuration(session.durationSeconds)} 的记录，'
                '统计页面的总时长也会相应减少。',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
                FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  child: const Text('删除'),
                ),
              ],
            ),
          );
          if (ok == true) await onDelete();
        },
      ),
    );
  }
}

// ============================================================
// 空状态
// ============================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 64, color: AppColors.textMuted2),
          const SizedBox(height: 16),
          const Text('还没有专注记录', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('开始一段专注后会在这里看到', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
