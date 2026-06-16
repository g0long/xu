import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../services/hive_service.dart';

/// AppSettings 不变更（StateNotifier）
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(_load());

  /// 单例 key，因为 Box 中只有一条 AppSettings 记录
  static const _key = 'app_settings';

  static AppSettings _load() {
    final box = HiveService.settingsBox;
    final existing = box.get(_key);
    if (existing != null) return existing;
    // 首次启动：创建并持久化默认设置
    final fresh = AppSettings();
    box.put(_key, fresh);
    return fresh;
  }

  /// 切换某个 tab 的可见性
  void toggleTab(String tabKey) {
    final newMap = Map<String, bool>.from(state.visibleTabs);
    newMap[tabKey] = !(newMap[tabKey] ?? true);
    state = AppSettings(
      visibleTabs: newMap,
      webdavUrl: state.webdavUrl,
      webdavUsername: state.webdavUsername,
      webdavPassword: state.webdavPassword,
      webdavBackupFolder: state.webdavBackupFolder,
      webdavFilename: state.webdavFilename,
      webdavAutoSync: state.webdavAutoSync,
      lastSyncTime: state.lastSyncTime,
      githubOwner: state.githubOwner,
      githubRepo: state.githubRepo,
      lastUpdateCheckTime: state.lastUpdateCheckTime,
      hardwareEnabled: state.hardwareEnabled,
      hardwareBackendIp: state.hardwareBackendIp,
    );
    _persist();
  }

  /// 更新 WebDAV 配置
  void updateWebDav({
    String? url,
    String? username,
    String? password,
    String? folder,
    String? filename,
    bool? autoSync,
  }) {
    state = AppSettings(
      visibleTabs: state.visibleTabs,
      webdavUrl: url ?? state.webdavUrl,
      webdavUsername: username ?? state.webdavUsername,
      webdavPassword: password ?? state.webdavPassword,
      webdavBackupFolder: folder ?? state.webdavBackupFolder,
      webdavFilename: filename ?? state.webdavFilename,
      webdavAutoSync: autoSync ?? state.webdavAutoSync,
      lastSyncTime: state.lastSyncTime,
      githubOwner: state.githubOwner,
      githubRepo: state.githubRepo,
      lastUpdateCheckTime: state.lastUpdateCheckTime,
      hardwareEnabled: state.hardwareEnabled,
      hardwareBackendIp: state.hardwareBackendIp,
    );
    _persist();
  }

  /// 记录同步时间
  void markSynced(DateTime time) {
    state = AppSettings(
      visibleTabs: state.visibleTabs,
      webdavUrl: state.webdavUrl,
      webdavUsername: state.webdavUsername,
      webdavPassword: state.webdavPassword,
      webdavBackupFolder: state.webdavBackupFolder,
      webdavFilename: state.webdavFilename,
      webdavAutoSync: state.webdavAutoSync,
      lastSyncTime: time,
      githubOwner: state.githubOwner,
      githubRepo: state.githubRepo,
      lastUpdateCheckTime: state.lastUpdateCheckTime,
      hardwareEnabled: state.hardwareEnabled,
      hardwareBackendIp: state.hardwareBackendIp,
    );
    _persist();
  }

  /// 更新 GitHub 仓库配置
  void updateGitHubRepo({String? owner, String? repo}) {
    state = AppSettings(
      visibleTabs: state.visibleTabs,
      webdavUrl: state.webdavUrl,
      webdavUsername: state.webdavUsername,
      webdavPassword: state.webdavPassword,
      webdavBackupFolder: state.webdavBackupFolder,
      webdavFilename: state.webdavFilename,
      webdavAutoSync: state.webdavAutoSync,
      lastSyncTime: state.lastSyncTime,
      githubOwner: owner ?? state.githubOwner,
      githubRepo: repo ?? state.githubRepo,
      lastUpdateCheckTime: state.lastUpdateCheckTime,
      hardwareEnabled: state.hardwareEnabled,
      hardwareBackendIp: state.hardwareBackendIp,
    );
    _persist();
  }

  /// 记录更新检查时间
  void markUpdateChecked(DateTime time) {
    state = AppSettings(
      visibleTabs: state.visibleTabs,
      webdavUrl: state.webdavUrl,
      webdavUsername: state.webdavUsername,
      webdavPassword: state.webdavPassword,
      webdavBackupFolder: state.webdavBackupFolder,
      webdavFilename: state.webdavFilename,
      webdavAutoSync: state.webdavAutoSync,
      lastSyncTime: state.lastSyncTime,
      githubOwner: state.githubOwner,
      githubRepo: state.githubRepo,
      lastUpdateCheckTime: time,
      hardwareEnabled: state.hardwareEnabled,
      hardwareBackendIp: state.hardwareBackendIp,
    );
    _persist();
  }

  /// 更新硬件墨水屏配置
  void updateHardware({bool? enabled, String? backendIp}) {
    state = AppSettings(
      visibleTabs: state.visibleTabs,
      webdavUrl: state.webdavUrl,
      webdavUsername: state.webdavUsername,
      webdavPassword: state.webdavPassword,
      webdavBackupFolder: state.webdavBackupFolder,
      webdavFilename: state.webdavFilename,
      webdavAutoSync: state.webdavAutoSync,
      lastSyncTime: state.lastSyncTime,
      githubOwner: state.githubOwner,
      githubRepo: state.githubRepo,
      lastUpdateCheckTime: state.lastUpdateCheckTime,
      hardwareEnabled: enabled ?? state.hardwareEnabled,
      hardwareBackendIp: backendIp ?? state.hardwareBackendIp,
    );
    _persist();
  }

  void _persist() {
    HiveService.settingsBox.put(_key, state);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

/// 派生：可见的 tab id 列表（按显示顺序）
final visibleTabIdsProvider = Provider<List<String>>((ref) {
  final visible = ref.watch(appSettingsProvider).visibleTabs;
  const order = ['todo', 'habit', 'diary', 'focus', 'stats'];
  return order.where((k) => visible[k] ?? true).toList();
});
