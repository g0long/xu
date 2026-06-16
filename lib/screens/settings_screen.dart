import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/diary_provider.dart';
import '../providers/focus_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/todo_provider.dart';
import '../services/theme.dart';
import '../services/update_service.dart';
import '../services/webdav_sync_service.dart';

/// 设置页面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // WebDAV 配置输入控制器
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _folderCtrl;
  late final TextEditingController _filenameCtrl;
  bool _isSyncing = false;
  String _lastStatus = '';
  String _appVersion = '...';

  static const _tabDefs = [
    ('todo', '待办', Icons.check_box_outlined),
    ('habit', '习惯', Icons.calendar_today_outlined),
    ('diary', '日记', Icons.menu_book_outlined),
    ('focus', '专注', Icons.timer_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    _urlCtrl = TextEditingController(text: s.webdavUrl);
    _userCtrl = TextEditingController(text: s.webdavUsername);
    _passCtrl = TextEditingController(text: s.webdavPassword);
    _folderCtrl = TextEditingController(text: s.webdavBackupFolder);
    _filenameCtrl = TextEditingController(text: s.webdavFilename);
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final pkg = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = '${pkg.version}+${pkg.buildNumber}';
      });
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _folderCtrl.dispose();
    _filenameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background3,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background3,
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('设置', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 4),

                // ===== 底栏 Tab 可见性 =====
                _sectionHeader('底栏显示', '关闭后该 tab 将从底栏隐藏'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _tabDefs.length; i++) ...[
                        _tabVisibilityTile(
                          _tabDefs[i].$1,
                          _tabDefs[i].$2,
                          _tabDefs[i].$3,
                          settings.visibleTabs[_tabDefs[i].$1] ?? true,
                          notifier,
                        ),
                        if (i < _tabDefs.length - 1)
                          const Divider(color: AppColors.divider, height: 1, indent: 56),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ===== WebDAV 同步 =====
                _sectionHeader('WebDAV 云同步', '通过 WebDAV 协议在多设备间同步数据'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _urlCtrl,
                        decoration: const InputDecoration(
                          labelText: '服务器地址（填写域名+路径即可）',
                          hintText: 'dav.jianguoyun.com/dav',
                          helperText: '坚果云地址：dav.jianguoyun.com/dav（无需加 https://）',
                          helperMaxLines: 2,
                          prefixIcon: Icon(Icons.cloud_outlined, size: 18, color: AppColors.textMuted),
                        ),
                        keyboardType: TextInputType.url,
                        onChanged: (v) => notifier.updateWebDav(url: v.trim()),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _userCtrl,
                              decoration: const InputDecoration(
                                labelText: '用户名',
                                prefixIcon: Icon(Icons.person_outline, size: 18, color: AppColors.textMuted),
                              ),
                              onChanged: (v) => notifier.updateWebDav(username: v.trim()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _passCtrl,
                              decoration: const InputDecoration(
                                labelText: '密码（应用专用密码）',
                                prefixIcon: Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
                              ),
                              obscureText: true,
                              onChanged: (v) => notifier.updateWebDav(password: v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _folderCtrl,
                        decoration: const InputDecoration(
                          labelText: '备份子目录（坚果云需要）',
                          hintText: 'xu_backups',
                          helperText: '坚果云根目录不能直接放文件，必须放在子目录里',
                          prefixIcon: Icon(Icons.folder_outlined, size: 18, color: AppColors.textMuted),
                        ),
                        onChanged: (v) => notifier.updateWebDav(folder: v.trim().isEmpty ? 'xu_backups' : v.trim()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _filenameCtrl,
                        decoration: const InputDecoration(
                          labelText: '备份文件名',
                          prefixIcon: Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.textMuted),
                        ),
                        onChanged: (v) => notifier.updateWebDav(filename: v.trim().isEmpty ? 'xu_backup.json' : v.trim()),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启动时自动同步', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                        subtitle: const Text('打开 App 时自动从云端拉取', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        value: settings.webdavAutoSync,
                        activeColor: AppColors.accent3,
                        onChanged: (v) => notifier.updateWebDav(autoSync: v),
                      ),
                      const SizedBox(height: 6),
                      // 同步操作按钮
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isSyncing ? null : () => _doSync(settings),
                              icon: const Icon(Icons.sync, size: 16),
                              label: const Text('同步'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSyncing ? null : () => _doAction('upload', settings),
                              icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                              label: const Text('上传'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent3,
                                side: const BorderSide(color: AppColors.accent3),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSyncing ? null : () => _doAction('download', settings),
                              icon: const Icon(Icons.cloud_download_outlined, size: 16),
                              label: const Text('下载'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.warning,
                                side: const BorderSide(color: AppColors.warning),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isSyncing) ...[
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('同步中…', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ],
                      if (_lastStatus.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_lastStatus, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                      const SizedBox(height: 10),
                      // 上次同步时间
                      Row(
                        children: [
                          const Icon(Icons.history, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            settings.lastSyncTime == null
                                ? '尚未同步'
                                : '上次同步：${DateFormat('yyyy-MM-dd HH:mm').format(settings.lastSyncTime!)}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ===== App 更新 =====
                _sectionHeader('App 更新', '从 GitHub Releases 自动检测新版'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.system_update, size: 18, color: AppColors.accent2),
                          const SizedBox(width: 8),
                          Text(
                            '当前版本：$_appVersion',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _isSyncing ? null : _doCheckUpdate,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('检查更新'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent2,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (settings.lastUpdateCheckTime != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '上次检查：${DateFormat('MM/dd HH:mm').format(settings.lastUpdateCheckTime!)}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        '提示：在 GitHub 仓库的 Releases 页面发布新版本后，'
                        '用户可以在这里检测到并一键下载更新。',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ===== 关于 =====
                _sectionHeader('关于', null),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('序', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4)),
                          const SizedBox(width: 8),
                          Text('Xu · $_appVersion', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('万物有序，从容生长', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic)),
                      SizedBox(height: 6),
                      Text('Flutter · Riverpod · Hive · fl_chart · audioplayers', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 检查更新 =====
  Future<void> _doCheckUpdate() async {
    final settings = ref.read(appSettingsProvider);
    setState(() => _isSyncing = true);
    try {
      final pkg = await PackageInfo.fromPlatform();
      final info = await UpdateService.checkForUpdate(
        owner: 'g0long',
        repo: 'xu',
        currentVersion: pkg.version,
      );
      ref.read(appSettingsProvider.notifier).markUpdateChecked(DateTime.now());
      if (!mounted) return;
      _showUpdateDialog(info);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ===== 更新弹窗 =====
  Future<void> _showUpdateDialog(UpdateInfo info) async {
    if (info.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败：${info.error}')),
      );
      return;
    }
    if (!info.hasUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已是最新版本（v${info.currentVersion}）')),
      );
      return;
    }
    final url = info.apkUrl ?? info.releaseUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到 APK 下载链接，请到 GitHub Release 页面手动下载')),
      );
      return;
    }
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
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('立即更新'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent2),
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

  // ===== 同步操作 =====
  Future<void> _doAction(String type, settings) async {
    setState(() {
      _isSyncing = true;
      _lastStatus = '';
    });
    late final SyncResult result;
    try {
      if (type == 'test') {
        result = await WebDavSyncService.testConnection(settings);
      } else if (type == 'upload') {
        result = await WebDavSyncService.upload(settings);
        if (result.success) {
          ref.read(appSettingsProvider.notifier).markSynced(result.time ?? DateTime.now());
        }
      } else if (type == 'download') {
        result = await WebDavSyncService.download(settings);
        if (result.success) {
          ref.read(appSettingsProvider.notifier).markSynced(result.time ?? DateTime.now());
          _refreshAllProviders();
        }
      }
    } catch (e) {
      result = SyncResult.fail('$e');
    }
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _lastStatus = (result.success ? '✓ ' : '✗ ') + result.message;
    });
  }

  /// 同步按钮
  Future<void> _doSync(AppSettings settings) async {
    setState(() {
      _isSyncing = true;
      _lastStatus = '';
    });
    try {
      final result = await WebDavSyncService.sync(settings);
      if (result.success) {
        ref.read(appSettingsProvider.notifier).markSynced(result.time ?? DateTime.now());
        _refreshAllProviders();
      }
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _lastStatus = (result.success ? '✓ ' : '✗ ') + result.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _lastStatus = '✗ $e';
      });
    }
  }

  void _refreshAllProviders() {
    ref.read(todoProvider.notifier).reload();
    ref.read(habitProvider.notifier).reload();
    ref.read(diaryProvider.notifier).reload();
    ref.read(focusProvider.notifier).reload();
  }

  // ===== 通用组件 =====
  Widget _sectionHeader(String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _tabVisibilityTile(
    String key,
    String label,
    IconData icon,
    bool visible,
    AppSettingsNotifier notifier,
  ) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      secondary: Icon(icon, color: visible ? AppColors.accent : AppColors.textMuted2, size: 22),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      value: visible,
      activeColor: AppColors.accent,
      onChanged: (_) => notifier.toggleTab(key),
    );
  }
}
