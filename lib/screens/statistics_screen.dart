import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/focus_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/todo_provider.dart';
import '../services/theme.dart';
import 'settings_screen.dart';

/// 统计页面（精简版）
///
/// 仅保留核心数据：
/// - 累计卡片（总专注 / 完成任务 / 最长连续）
/// - 7 日专注趋势柱状图
/// - 习惯连续排行榜
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(todoProvider);
    final doneTodos = todos.fold<int>(0, (sum, t) => sum + (t.isDone ? 1 : 0) + t.doneSubtaskCount);

    final longestStreak = ref.watch(habitLongestStreakProvider);
    final habitStreaks = ref.watch(habitStreakListProvider);

    final totalMin = ref.watch(totalFocusMinutesProvider);
    final last7DaysFocus = ref.watch(last7DaysFocusProvider);

    return Scaffold(
      backgroundColor: AppColors.background3,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildDateHeader(),
              const SizedBox(height: 24),
              _buildSummaryCards(totalMin, doneTodos, longestStreak),
              const SizedBox(height: 28),
              _buildSectionTitle('7 日专注趋势'),
              const SizedBox(height: 12),
              _FocusBar(secondsPerDay: last7DaysFocus),
              const SizedBox(height: 28),
              _buildSectionTitle('习惯连续排行'),
              const SizedBox(height: 12),
              _StreakLeaderboard(streaks: habitStreaks),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 顶部 =====
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Text(
            '统计',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final now = DateTime.now();
    final str = DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(now);
    return Text(
      str,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.accent,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }

  // ===== 3 个核心统计卡片 =====
  Widget _buildSummaryCards(int totalMin, int doneTodos, int longestStreak) {
    final items = [
      ('累计专注', '$totalMin', '分钟', Icons.timer_outlined, AppColors.accent2),
      ('已完成', '$doneTodos', '项', Icons.check_circle_outline, AppColors.accent),
      ('最长连续', '$longestStreak', '天', Icons.local_fire_department_outlined, AppColors.warning),
    ];
    return Row(
      children: items.map((it) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              left: it == items.first ? 0 : 6,
              right: it == items.last ? 0 : 6,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(it.$4, color: it.$5, size: 20),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      it.$2,
                      style: TextStyle(
                        color: it.$5,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(it.$3, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(it.$1, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

// ============================================================
// 7 日专注柱状图
// ============================================================
class _FocusBar extends StatelessWidget {
  final List<int> secondsPerDay;
  const _FocusBar({required this.secondsPerDay});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final maxMin = (secondsPerDay.isEmpty
            ? 0
            : (secondsPerDay.reduce((a, b) => a > b ? a : b) / 60).ceil())
        .toDouble();
    final maxY = (maxMin < 30 ? 30.0 : (maxMin + 15).toDouble());

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      height: 200,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final m = secondsPerDay[i] / 60;
                final barH = maxY == 0 ? 0.0 : (m / maxY).clamp(0.0, 1.0);
                final isToday = i == 6;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          m > 0 ? '${m.round()}分' : '',
                          style: TextStyle(
                            color: isToday ? AppColors.accent2 : AppColors.textMuted,
                            fontSize: 10,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: (barH * 120).clamp(4.0, 120.0),
                          decoration: BoxDecoration(
                            color: isToday ? AppColors.accent2 : AppColors.accent2.withOpacity(0.5),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (i) {
              final d = today.subtract(Duration(days: 6 - i));
              return Expanded(
                child: Text(
                  DateFormat('M/d').format(d),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: i == 6 ? AppColors.accent : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: i == 6 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 习惯连续排行榜（Top 5）
// ============================================================
class _StreakLeaderboard extends StatelessWidget {
  final List<({String name, String emoji, int streak, int longest})> streaks;
  const _StreakLeaderboard({required this.streaks});

  @override
  Widget build(BuildContext context) {
    if (streaks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('暂无习惯数据', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      );
    }

    final top = streaks.where((s) => s.streak > 0).take(5).toList();
    if (top.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('还没有连续打卡记录', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      );
    }

    final maxStreak = top.first.streak;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: top.map((s) {
          final pct = maxStreak == 0 ? 0.0 : s.streak / maxStreak;
          final isTop = s.streak >= maxStreak;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(s.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${s.streak} 天',
                            style: TextStyle(
                              color: isTop ? AppColors.gold : AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          backgroundColor: AppColors.secondaryBg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isTop ? AppColors.gold : AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
