import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前底部导航的 Tab 索引（用于跨页面切换 Tab）
///
/// 0 = 待办
/// 1 = 习惯
/// 2 = 日记
/// 3 = 专注
/// 4 = 统计
final currentTabIndexProvider = StateProvider<int>((ref) => 0);
