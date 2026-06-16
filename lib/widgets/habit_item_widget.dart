import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/habit.dart';
import '../services/theme.dart';

/// 习惯卡片
///
/// 还原样图：
/// - 左侧彩色圆形 emoji 图标
/// - 中间：习惯名 + 近 7 天打卡小方块 / 进度条
/// - 右侧：当前连续天数 + 打卡按钮
class HabitItemWidget extends StatelessWidget {
  final Habit habit;
  final VoidCallback onCheckToday;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HabitItemWidget({
    super.key,
    required this.habit,
    required this.onCheckToday,
    required this.onEdit,
    required this.onDelete,
  });

  static const _palette = [
    AppColors.accent,
    AppColors.purple,
    AppColors.success,
    AppColors.warning,
    AppColors.danger,
    AppColors.accent2,
    AppColors.accent3,
  ];

  Color get _color => _palette[habit.colorIndex.clamp(0, _palette.length - 1)];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final checkedToday = habit.isCheckedOn(today);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 圆形图标
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: _color.withOpacity(0.4), width: 1.5),
                ),
                child: Text(habit.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              // 标题与频率
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      habit.frequency == HabitFrequency.daily
                          ? '每日'
                          : '每周 ${habit.weeklyTarget} 次',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // 连续天数
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${habit.currentStreak}',
                    style: TextStyle(
                      color: _color,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Text('连续', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 近 7 天打卡
          _buildWeekDots(today),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '完成率 ${(habit.completionRate * 100).toStringAsFixed(0)}%  ·  最长 ${habit.longestStreak} 天',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
              // 打卡按钮
              _CheckButton(checked: checkedToday, color: _color, onTap: onCheckToday),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: AppColors.textMuted, size: 18),
                color: AppColors.cardBg,
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑', style: TextStyle(color: AppColors.textPrimary))),
                  PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: AppColors.danger))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== 近 7 天圆点 =====
  Widget _buildWeekDots(DateTime today) {
    final dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        // 从本周一开始的 7 天
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final d = monday.add(Duration(days: i));
        final checked = habit.isCheckedOn(d);
        final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
        return Column(
          children: [
            Container(
              width: 26, height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? _color : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isToday
                      ? _color
                      : (checked ? _color : AppColors.textMuted2.withOpacity(0.4)),
                  width: isToday ? 2 : 1,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      DateFormat('d').format(d),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
            ),
            const SizedBox(height: 4),
            Text(dayLabels[i], style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
          ],
        );
      }),
    );
  }
}

class _CheckButton extends StatelessWidget {
  final bool checked;
  final Color color;
  final VoidCallback onTap;

  const _CheckButton({required this.checked, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked ? color : color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(
          checked ? Icons.check : Icons.add,
          color: checked ? Colors.white : color,
          size: 20,
        ),
      ),
    );
  }
}
