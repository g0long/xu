import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/focus_provider.dart';
import '../services/theme.dart';
import '../widgets/focus_timer_widget.dart';

/// 专注页面（精简版）
///
/// 仅保留：
/// - 快速选择时长（15 / 25 / 45 / 60 分钟）
/// - 专注任务名（可双击编辑）
/// - 圆形计时器（点击中央时间可直接修改时长）
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  final _player = AudioPlayer();
  bool _soundLoaded = false;

  @override
  void initState() {
    super.initState();
    _player.setSource(AssetSource('sounds/timer_alert.mp3')).then((_) {
      _soundLoaded = true;
    }).catchError((_) {
      _soundLoaded = false;
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playFinishSound() async {
    if (!_soundLoaded) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/timer_alert.mp3'));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(focusProvider);
    final notifier = ref.read(focusProvider.notifier);

    // 音效监听
    ref.listen<FocusState>(focusProvider, (prev, next) {
      if (prev != null && prev.remainingSeconds > 0 && next.remainingSeconds == 0 && !next.isRunning) {
        _playFinishSound();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background2,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildQuickPresets(state, notifier),
              const SizedBox(height: 16),
              _buildTaskNameChip(state, notifier),
              const SizedBox(height: 16),
              FocusTimerWidget(
                progress: state.progress,
                remainingSeconds: state.remainingSeconds,
                isRunning: state.isRunning,
                onPlayPause: () {
                  if (state.isRunning) {
                    notifier.pause();
                  } else {
                    notifier.start();
                  }
                },
                onReset: () => notifier.reset(),
                onTimeTap: () => _showEditMinutesDialog(notifier, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 标题 =====
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '专注',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  // ===== 快速预设按钮 =====
  Widget _buildQuickPresets(FocusState state, FocusNotifier notifier) {
    final presets = [15, 25, 45, 60];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '快速选择时长',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5),
          ),
        ),
        Row(
          children: presets.map((min) {
            final isCurrent = state.focusSeconds == min * 60;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: min == presets.first ? 0 : 5,
                  right: min == presets.last ? 0 : 5,
                ),
                child: GestureDetector(
                  onTap: () => notifier.setCustomDurations(focusMin: min),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.accent.withOpacity(0.18)
                          : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.accent.withOpacity(0.5)
                            : AppColors.divider,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$min',
                          style: TextStyle(
                            color: isCurrent ? AppColors.accent : AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '分钟',
                          style: TextStyle(
                            color: isCurrent ? AppColors.accent.withOpacity(0.8) : AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ===== 当前专注任务名（可双击编辑）=====
  Widget _buildTaskNameChip(FocusState state, FocusNotifier notifier) {
    final name = state.displayTaskName;
    final hasTask = state.taskName != null && state.taskName!.isNotEmpty;
    return GestureDetector(
      onDoubleTap: () => _editTaskName(state, notifier),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: hasTask ? AppColors.goldSoft : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasTask ? AppColors.gold.withOpacity(0.4) : AppColors.divider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasTask ? Icons.bolt : Icons.center_focus_strong,
              size: 14,
              color: hasTask ? AppColors.gold : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                name,
                style: TextStyle(
                  color: hasTask ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: hasTask ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 11, color: AppColors.textMuted2),
          ],
        ),
      ),
    );
  }

  Future<void> _editTaskName(FocusState state, FocusNotifier notifier) async {
    final ctrl = TextEditingController(text: state.taskName ?? '');
    await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置当前专注任务'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: '例如：写周报 / 阅读 / 专注',
            prefixIcon: Icon(Icons.edit, size: 18, color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.setTaskName(null);
              Navigator.pop(ctx);
            },
            child: const Text('清除'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              notifier.setTaskName(ctrl.text);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===== 点击时间数字 → 修改专注时长（滑块 + 直接填）=====
  Future<void> _showEditMinutesDialog(FocusNotifier notifier, FocusState state) async {
    int minutes = state.remainingSeconds ~/ 60;
    final ctrl = TextEditingController(text: '$minutes');
    const int minVal = 5;
    const int maxVal = 120;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: const Text('修改专注时长'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 文本输入框 + 分钟标签
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null) {
                          setSt(() => minutes = n.clamp(minVal, maxVal));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('分钟', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 20),
              // 滑块快速调节
              Row(
                children: [
                  Text('$minVal', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  Expanded(
                    child: Slider(
                      value: minutes.toDouble().clamp(minVal.toDouble(), maxVal.toDouble()),
                      min: minVal.toDouble(),
                      max: maxVal.toDouble(),
                      divisions: maxVal - minVal,
                      activeColor: AppColors.accent,
                      onChanged: (v) {
                        setSt(() {
                          minutes = v.round();
                          ctrl.text = '$minutes';
                        });
                      },
                    ),
                  ),
                  Text('$maxVal', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, minutes),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('确定', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
    if (result != null && mounted) {
      notifier.setCustomDurations(focusMin: result);
    }
  }
}
