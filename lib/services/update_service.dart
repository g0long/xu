import 'dart:convert';
import 'package:http/http.dart' as http;

/// GitHub Release 更新信息
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String? releaseNotes;
  final String? apkUrl;       // 直接下载链接
  final String? releaseUrl;   // release 页面
  final String? error;        // 错误信息

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    this.releaseNotes,
    this.apkUrl,
    this.releaseUrl,
    this.error,
  });

  factory UpdateInfo.noUpdate(String v) =>
      UpdateInfo(currentVersion: v, latestVersion: v, hasUpdate: false);
}

/// GitHub Releases 自动更新服务
class UpdateService {
  UpdateService._();

  /// 检查更新
  /// - [owner] / [repo] 形如 "username/todo"
  /// - [currentVersion] 当前 App 版本（pubspec.yaml 中的 version）
  ///
  /// 使用 /releases 列表接口（而非 /releases/latest），
  /// 绕过 GitHub CDN 对 /latest 的缓存延迟。
  static Future<UpdateInfo> checkForUpdate({
    required String owner,
    required String repo,
    required String currentVersion,
  }) async {
    if (owner.isEmpty || repo.isEmpty) {
      return UpdateInfo.noUpdate(currentVersion);
    }
    try {
      // 用 /releases 列表而非 /releases/latest，避免 CDN 缓存旧数据
      final url = 'https://api.github.com/repos/$owner/$repo/releases?per_page=20';
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'Xu-App',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 403) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          hasUpdate: false,
          error: 'GitHub API 限流（每小时 60 次），请稍后再试',
        );
      }
      if (response.statusCode == 404) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          hasUpdate: false,
          error: '仓库 $owner/$repo 尚未发布任何 Release',
        );
      }
      if (response.statusCode != 200) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          hasUpdate: false,
          error: 'GitHub API 返回 ${response.statusCode}',
        );
      }

      final List releases = jsonDecode(response.body) as List;
      if (releases.isEmpty) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          hasUpdate: false,
          error: '仓库 $owner/$repo 尚未发布任何 Release',
        );
      }

      // 从列表中找到最新的非 prerelease、非 draft 版本
      Map<String, dynamic>? latestRelease;
      String? latestVersion;
      for (final release in releases) {
        if (release is! Map) continue;
        final draft = release['draft'] as bool? ?? false;
        final prerelease = release['prerelease'] as bool? ?? false;
        if (draft || prerelease) continue;

        final rawTag = (release['tag_name'] as String?) ?? '';
        final ver = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;
        if (ver.isEmpty) continue;

        if (latestVersion == null || _compareVersions(ver, latestVersion) > 0) {
          latestVersion = ver;
          latestRelease = release as Map<String, dynamic>;
        }
      }

      if (latestRelease == null || latestVersion == null) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          hasUpdate: false,
          error: '仓库 $owner/$repo 没有正式 Release（可能全是草稿或预览版）',
        );
      }

      final htmlUrl = latestRelease['html_url'] as String?;

      // 在 assets 里找 .apk（优先 arm64）
      String? apkUrl;
      final assets = (latestRelease['assets'] as List?) ?? [];
      String? fallbackApk;
      for (final asset in assets) {
        if (asset is Map) {
          final name = (asset['name'] as String?) ?? '';
          final url = asset['browser_download_url'] as String?;
          if (name.endsWith('.apk') && url != null) {
            if (name.contains('arm64') || name.contains('v8a')) {
              apkUrl = url;
              break;
            }
            fallbackApk ??= url;
          }
        }
      }
      apkUrl ??= fallbackApk;

      final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        hasUpdate: hasUpdate,
        releaseNotes: latestRelease['body'] as String?,
        apkUrl: apkUrl,
        releaseUrl: htmlUrl,
      );
    } catch (e) {
      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        hasUpdate: false,
        error: e.toString(),
      );
    }
  }

  /// 语义化版本号比较
  /// 返回：>0 表示 v1 > v2，<0 表示 v1 < v2，0 表示相等
  static int _compareVersions(String v1, String v2) {
    final p1 = v1.split(RegExp(r'[.\-+]')).map(int.tryParse).toList();
    final p2 = v2.split(RegExp(r'[.\-+]')).map(int.tryParse).toList();
    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (int i = 0; i < maxLen; i++) {
      final a = i < p1.length ? (p1[i] ?? 0) : 0;
      final b = i < p2.length ? (p2[i] ?? 0) : 0;
      if (a > b) return 1;
      if (a < b) return -1;
    }
    return 0;
  }
}
