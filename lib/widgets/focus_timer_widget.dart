import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/theme.dart';

/// 专注计时器圆环（CustomPaint 自绘）— Kami 编辑风格
///
/// 视觉层次：
/// - 外圈：暖调装饰环 + 四枚刻度点
/// - 进度弧：墨蓝色调，末端圆形指示器
/// - 内圈：半透明光晕
/// - 中心：HH.MM.SS 数字 + 状态标签
class FocusTimerWidget extends StatelessWidget {
  final double progress;       // 0..1
  final int remainingSeconds;  // 剩余秒
  final bool isRunning;
  final VoidCallback onPlayPause;
  final VoidCallback onReset;
  final VoidCallback? onTimeTap;   // ★ 点击中央时间 → 修改时长

  const FocusTimerWidget({
    super.key,
    required this.progress,
    required this.remainingSeconds,
    required this.isRunning,
    required this.onPlayPause,
    required this.onReset,
    this.onTimeTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.maxWidth.clamp(220.0, 320.0);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(size, size),
                  painter: _TimerRingPainter(progress: progress),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onTimeTap,
                      child: Text(
                        _formatTime(remainingSeconds),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 44,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRunning ? '专注中…' : '准备开始',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                // 中央播放按钮
                Positioned(
                  bottom: 6,
                  child: GestureDetector(
                    onTap: onPlayPause,
                    onLongPress: onReset,
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent.withOpacity(0.6), width: 1.5),
                      ),
                      child: Icon(
                        isRunning ? Icons.pause : Icons.play_arrow,
                        color: AppColors.accent,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return '${two(h)}.${two(m)}.${two(s)}';
    return '${two(m)}.${two(s)}';
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  _TimerRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. 背景环
    final bgPaint = Paint()
      ..color = AppColors.secondaryBg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. 进度弧
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, progressPaint);

      // 末端指示器
      final endAngle = -math.pi / 2 + 2 * math.pi * progress;
      final endPoint = center + Offset(math.cos(endAngle) * radius, math.sin(endAngle) * radius);
      final dotPaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, 6, dotPaint);

      final innerDot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, 3, innerDot);
    }
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
