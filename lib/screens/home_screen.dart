import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_settings_provider.dart';
import '../providers/nav_provider.dart';
import '../services/theme.dart';
import '../services/update_service.dart';
import 'diary_screen.dart';
import 'focus_screen.dart';
import 'habit_screen.dart';
import 'statistics_screen.dart';
import 'todo_screen.dart';

/// 主框架：动态底栏（根据设置中可见的 tab 数量自适应）
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // 5 个 Tab 页面
  static const _allPages = <Widget>[
    TodoScreen(),
    HabitScreen(),
    DiaryScreen(),
    FocusScreen(),
    StatisticsScreen(),
  ];

  static const _tabMeta = <String, (String, IconData, IconData)>{
    'todo':  ('待办', Icons.check_box_outlined, Icons.check_box),
    'habit': ('习惯', Icons.calendar_today_outlined, Icons.calendar_today),
    'diary': ('日记', Icons.menu_book_outlined, Icons.menu_book),
    'focus': ('专注', Icons.timer_outlined, Icons.timer),
    'stats': ('统计', Icons.bar_chart_outlined, Icons.bar_chart),
  };

  static const _tabIndex = <String, int>{
    'todo': 0, 'habit': 1, 'diary': 2, 'focus': 3, 'stats': 4,
  };

  @override
  void initState() {
    super.initState();
    // 启动后 2 秒再异步检查更新（不阻塞首屏）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), _checkUpdateOnStartup);
    });
  }

  Future<void> _checkUpdateOnStartup() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final info = await UpdateService.checkForUpdate(
        owner: 'g0long',
        repo: 'xu',
        currentVersion: pkg.version,
      );
      if (!mounted) return;
      if (info.hasUpdate) {
        await _showUpdateDialog(info);
      }
    } catch (_) {
      // 静默失败
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo info) async {
    final url = info.apkUrl ?? info.releaseUrl;
    if (url == null) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.celebration, color: AppColors.accent2, size: 22),
            const SizedBox(width: 8),
            Text('发现新版本 v${info.latestVersion}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '当前版本：v${info.currentVersion}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if ((info.releaseNotes ?? '').isNotEmpty) ...[
                const Text('更新内容：', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background4,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Text(
                      info.releaseNotes!,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('稍后再说')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent2),
            child: const Text('立即更新', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allIndex = ref.watch(currentTabIndexProvider);
    final visibleIds = ref.watch(visibleTabIdsProvider);

    final pages = visibleIds.map((id) => _allPages[_tabIndex[id]!]).toList();
    final currentIndex = allIndex < pages.length ? allIndex : 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, visibleIds, currentIndex),
    );
  }

  Widget _buildBottomNav(BuildContext context, List<String> visibleIds, int currentIndex) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => ref.read(currentTabIndexProvider.notifier).state = i,
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted2,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
        items: [
          for (final id in visibleIds)
            BottomNavigationBarItem(
              icon: Icon(_tabMeta[id]!.$2),
              activeIcon: Icon(_tabMeta[id]!.$3, size: 26),
              label: _tabMeta[id]!.$1,
            ),
        ],
      ),
    );
  }
}
