# WebDAV 双向合并同步 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 WebDAV 同步从全量覆盖模型改为基于时间戳的双向合并模型，支持多设备同步。

**Architecture:** 云端文件新增 `tombstones` 字段追踪删除。本地新增 Hive box `tombstones` 存储待同步的删除记录。上传/下载/同步三个操作均按条目 `id` 匹配、`updatedAt` 比较、新者胜的规则合并。同步 = 先下载后上传。

**Tech Stack:** Dart, Hive, Riverpod, http package

**Files:**
- Modify: `lib/services/hive_service.dart` (新增 tombstones box)
- Modify: `lib/services/webdav_sync_service.dart` (重写合并逻辑)
- Modify: `lib/providers/todo_provider.dart` (删除写墓碑 + 公开 reload)
- Modify: `lib/providers/habit_provider.dart` (同上)
- Modify: `lib/providers/diary_provider.dart` (同上)
- Modify: `lib/providers/focus_provider.dart` (同上)
- Modify: `lib/screens/settings_screen.dart` (三个按钮 + 修复刷新)

---

### Task 1: 新增墓碑 Box

**Files:**
- Modify: `lib/services/hive_service.dart`

- [ ] **Step 1: 添加 tombstones box 常量与访问器**

在 `HiveService` 类中添加：

```dart
static const String boxTombstones = 'tombstones';

// 在 box 访问器区域底部添加：
static Box<String> get tombstonesBox => Hive.box<String>(boxTombstones);
```

- [ ] **Step 2: 在 init() 中打开 tombstones box**

在 `HiveService.init()` 方法中，`await _safeOpen<AppSettings>(boxSettings);` 之后添加：

```dart
await _safeOpen<String>(boxTombstones);
```

---

### Task 2: 重写 WebDAV 同步服务（合并逻辑）

**Files:**
- Modify: `lib/services/webdav_sync_service.dart`

- [ ] **Step 1: 删除旧文件全部内容，重写整个文件**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/todo.dart';
import '../models/habit.dart';
import '../models/focus_session.dart';
import '../models/diary.dart';
import '../models/app_settings.dart';
import 'hive_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final DateTime? time;
  const SyncResult({required this.success, required this.message, this.time});

  factory SyncResult.ok(String msg) =>
      SyncResult(success: true, message: msg, time: DateTime.now());
  factory SyncResult.fail(String msg) =>
      SyncResult(success: false, message: msg);
}

class WebDavSyncService {
  WebDavSyncService._();

  // ========== URL 规范化 ==========

  static String _normalizeUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  static String _fileUrl(AppSettings s) {
    final base = _normalizeUrl(s.webdavUrl);
    final folder = s.webdavBackupFolder.trim();
    return folder.isEmpty
        ? '$base/${s.webdavFilename}'
        : '$base/$folder/${s.webdavFilename}';
  }

  // ========== 墓碑 ==========

  /// 写一条本地墓碑
  static Future<void> writeTombstone(String category, String id) async {
    final key = '${category}_$id';
    await HiveService.tombstonesBox.put(key, DateTime.now().toIso8601String());
  }

  /// 上传成功后清理该类别已同步的墓碑
  static Future<void> _clearTombstones(String category) async {
    final prefix = '${category}_';
    final keys = HiveService.tombstonesBox.keys
        .where((k) => k is String && (k as String).startsWith(prefix))
        .toList();
    for (final k in keys) {
      await HiveService.tombstonesBox.delete(k);
    }
  }

  // ========== HTTP 工具 ==========

  static String _basicAuth(AppSettings s) {
    final raw = '${s.webdavUsername}:${s.webdavPassword}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }

  /// 读云端 JSON，失败返回 null
  static Future<Map<String, dynamic>?> _fetchCloud(AppSettings s) async {
    try {
      final r = await http
          .get(Uri.parse(_fileUrl(s)), headers: {'Authorization': _basicAuth(s)})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      }
      if (r.statusCode == 404) return null; // 云端尚无备份
      return null;
    } catch (_) {
      return null;
    }
  }

  /// PUT 数据到云端
  static Future<int> _putCloud(AppSettings s, Map<String, dynamic> payload) async {
    try {
      final body = utf8.encode(jsonEncode(payload));
      // 坚果云根目录不能直接 PUT，需要确保子目录存在
      final folder = s.webdavBackupFolder.trim();
      if (folder.isNotEmpty) {
        final base = _normalizeUrl(s.webdavUrl);
        try {
          final mkcol = http.Request('MKCOL', Uri.parse('$base/$folder'))
            ..headers['Authorization'] = _basicAuth(s);
          (await mkcol.send().timeout(const Duration(seconds: 10))).stream.drain();
        } catch (_) {}
      }
      final r = await http
          .put(Uri.parse(_fileUrl(s)),
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Authorization': _basicAuth(s),
              },
              body: body)
          .timeout(const Duration(seconds: 30));
      return r.statusCode;
    } catch (_) {
      return 0;
    }
  }

  // ========== 收集本地数据 ==========

  static Map<String, dynamic> _collectAllData() {
    final todos = HiveService.todoBox.values.map((t) => t.toJson()).toList();
    final habits = HiveService.habitBox.values.map((h) => h.toJson()).toList();
    final sessions = HiveService.focusBox.values.map((s) => s.toJson()).toList();
    final diaries = HiveService.diaryBox.values.map((d) => d.toJson()).toList();
    return {
      'version': 2,
      'app': 'xu',
      'lastModified': DateTime.now().toIso8601String(),
      'data': {
        'todos': todos,
        'habits': habits,
        'focus_sessions': sessions,
        'diaries': diaries,
      },
      'tombstones': _collectLocalTombstones(),
      'summary': '${todos.length} 待办 / ${habits.length} 习惯 / ${sessions.length} 专注 / ${diaries.length} 日记',
    };
  }

  /// 收集本地墓碑，整理为云端格式
  static Map<String, List<Map<String, String>>> _collectLocalTombstones() {
    final result = <String, List<Map<String, String>>>{
      'todos': [],
      'habits': [],
      'focus_sessions': [],
      'diaries': [],
    };
    for (final entry in HiveService.tombstonesBox.toMap().entries) {
      final k = entry.key as String;
      final v = entry.value as String;
      for (final cat in ['todos', 'habits', 'focus_sessions', 'diaries']) {
        if (k.startsWith('${cat}_')) {
          result[cat]!.add({'id': k.substring('${cat}_'.length), 'deletedAt': v});
          break;
        }
      }
    }
    return result;
  }

  // ========== 通用合并函数 ==========

  /// 合并两个列表（按 id，比较 updatedAt，新者胜）
  /// 返回合并后的列表
  static List<Map<String, dynamic>> _mergeLists({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> remote,
    required List<Map<String, String>> localTombstones,
    required List<Map<String, String>> remoteTombstones,
  }) {
    final result = <String, Map<String, dynamic>>{};
    final deleted = <String>{}; // 确定为删除的 id 集合

    // 合并墓碑：找每个 id 的最新墓碑时间
    final tombTimes = <String, DateTime>{};
    for (final t in localTombstones) {
      final time = DateTime.parse(t['deletedAt']!);
      final id = t['id']!;
      if (tombTimes[id] == null || time.isAfter(tombTimes[id]!)) {
        tombTimes[id] = time;
      }
    }
    for (final t in remoteTombstones) {
      final time = DateTime.parse(t['deletedAt']!);
      final id = t['id']!;
      if (tombTimes[id] == null || time.isAfter(tombTimes[id]!)) {
        tombTimes[id] = time;
      }
    }

    // 收集所有条目
    final allEntries = <Map<String, dynamic>>[...local, ...remote];

    for (final entry in allEntries) {
      final id = entry['id'] as String;
      if (deleted.contains(id)) continue;

      // 检查是否被墓碑杀死
      if (tombTimes.containsKey(id)) {
        DateTime entryTime;
        try {
          entryTime = DateTime.parse(entry['updatedAt'] as String? ?? '');
        } catch (_) {
          entryTime = DateTime.now();
        }
        if (tombTimes[id]!.isAfter(entryTime)) {
          deleted.add(id);
          result.remove(id);
          continue;
        }
      }

      final existing = result[id];
      if (existing == null) {
        result[id] = Map<String, dynamic>.from(entry);
      } else {
        // 比较 updatedAt，保留新的
        DateTime existingTime;
        DateTime entryTime;
        try {
          existingTime = DateTime.parse(existing['updatedAt'] as String? ?? '');
          entryTime = DateTime.parse(entry['updatedAt'] as String? ?? '');
        } catch (_) {
          existingTime = DateTime.now();
          entryTime = DateTime.now();
        }
        if (entryTime.isAfter(existingTime)) {
          result[id] = Map<String, dynamic>.from(entry);
        }
      }
    }

    return result.values.toList();
  }

  // ========== 写入本地 Hive（合并模式）==========

  static Future<void> _mergeIntoLocal(List<Map<String, dynamic>> remoteList,
      String category, List<Map<String, String>> remoteTombstones) async {
    // 收集本地数据
    List<Map<String, dynamic>> localList;
    Box box;
    switch (category) {
      case 'todos':
        box = HiveService.todoBox;
        localList = HiveService.todoBox.values.map((t) => (t as dynamic).toJson() as Map<String, dynamic>).toList();
        break;
      case 'habits':
        box = HiveService.habitBox;
        localList = HiveService.habitBox.values.map((h) => (h as dynamic).toJson() as Map<String, dynamic>).toList();
        break;
      case 'focus_sessions':
        box = HiveService.focusBox;
        localList = HiveService.focusBox.values.map((s) => (s as dynamic).toJson() as Map<String, dynamic>).toList();
        break;
      case 'diaries':
        box = HiveService.diaryBox;
        localList = HiveService.diaryBox.values.map((d) => (d as dynamic).toJson() as Map<String, dynamic>).toList();
        break;
      default:
        return;
    }

    // 收集本地墓碑
    final localTombstones = <Map<String, String>>[];
    final prefix = '${category}_';
    for (final entry in HiveService.tombstonesBox.toMap().entries) {
      final k = entry.key as String;
      if (k.startsWith(prefix)) {
        localTombstones.add({'id': k.substring(prefix.length), 'deletedAt': entry.value as String});
      }
    }

    // 合并
    final merged = _mergeLists(
      local: localList,
      remote: remoteList,
      localTombstones: localTombstones,
      remoteTombstones: remoteTombstones,
    );

    // 写入 Hive（清空后重填）
    await box.clear();
    switch (category) {
      case 'todos':
        for (final m in merged) {
          await box.put(m['id'], Todo.fromJson(Map<String, dynamic>.from(m)));
        }
        break;
      case 'habits':
        for (final m in merged) {
          await box.put(m['id'], Habit.fromJson(Map<String, dynamic>.from(m)));
        }
        break;
      case 'focus_sessions':
        for (final m in merged) {
          await box.put(m['id'], FocusSession.fromJson(Map<String, dynamic>.from(m)));
        }
        break;
      case 'diaries':
        for (final m in merged) {
          await box.put(m['id'], Diary.fromJson(Map<String, dynamic>.from(m)));
        }
        break;
    }

    // 清理此类别中已同步的墓碑
    await _clearTombstones(category);
  }

  // ========== 三个公开操作 ==========

  /// 上传：读云端 → 合并 → 写回 → 清理墓碑
  static Future<SyncResult> upload(AppSettings settings) async {
    final rawUrl = settings.webdavUrl.trim();
    if (rawUrl.isEmpty) return SyncResult.fail('请先填写 WebDAV 服务器地址');

    try {
      // 1) 读云端
      final cloud = await _fetchCloud(settings);

      // 2) 本地全量数据
      final local = _collectAllData();

      Map<String, dynamic> merged;
      if (cloud != null && cloud['version'] != null) {
        // 云端有数据 → 合并
        merged = Map<String, dynamic>.from(cloud);
        merged['lastModified'] = DateTime.now().toIso8601String();
        final cloudData = (cloud['data'] as Map<String, dynamic>?) ?? {};
        final cloudTombs = (cloud['tombstones'] as Map<String, dynamic>?) ?? {};
        final localData = local['data'] as Map<String, dynamic>;
        final localTombs = local['tombstones'] as Map<String, dynamic>;

        final mergedData = <String, dynamic>{};
        for (final cat in ['todos', 'habits', 'focus_sessions', 'diaries']) {
          mergedData[cat] = _mergeLists(
            local: (localData[cat] as List?)?.cast<Map<String, dynamic>>() ?? [],
            remote: (cloudData[cat] as List?)?.cast<Map<String, dynamic>>() ?? [],
            localTombstones: (localTombs[cat] as List?)?.cast<Map<String, String>>() ?? [],
            remoteTombstones: (cloudTombs[cat] as List?)?.cast<Map<String, String>>() ?? [],
          );
        }
        merged['data'] = mergedData;
        // 合并墓碑
        final mergedTombs = <String, dynamic>{};
        for (final cat in ['todos', 'habits', 'focus_sessions', 'diaries']) {
          mergedTombs[cat] = _mergeTombstones(
            local: (localTombs[cat] as List?)?.cast<Map<String, String>>() ?? [],
            remote: (cloudTombs[cat] as List?)?.cast<Map<String, String>>() ?? [],
          );
        }
        merged['tombstones'] = mergedTombs;
        merged['summary'] = local['summary'];
      } else {
        // 云端无数据 → 直接推送本地
        merged = local;
      }

      // 3) PUT
      final code = await _putCloud(settings, merged);
      if (code == 200 || code == 201 || code == 204 || code == 207) {
        // 4) 清理已同步的墓碑
        for (final cat in ['todos', 'habits', 'focus_sessions', 'diaries']) {
          await _clearTombstones(cat);
        }
        return SyncResult.ok('已上传：${local['summary']}');
      } else if (code == 401) {
        return SyncResult.fail('鉴权失败（401），请检查用户名和应用专用密码');
      } else {
        return SyncResult.fail('上传失败：HTTP $code');
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('hostname') || msg.contains('No address')) {
        return SyncResult.fail('DNS 解析失败，请检查地址拼写。坚果云地址：dav.jianguoyun.com/dav');
      }
      return SyncResult.fail('上传异常：$e');
    }
  }

  /// 下载：读云端 → 合并写入 Hive → 返回（Provider 刷新由调用方负责）
  static Future<SyncResult> download(AppSettings settings) async {
    final rawUrl = settings.webdavUrl.trim();
    if (rawUrl.isEmpty) return SyncResult.fail('请先填写 WebDAV 服务器地址');

    try {
      final cloud = await _fetchCloud(settings);
      if (cloud == null) {
        return SyncResult.fail('云端暂无备份文件，请先上传');
      }

      final cloudData = (cloud['data'] as Map<String, dynamic>?) ?? {};
      final cloudTombs = (cloud['tombstones'] as Map<String, dynamic>?) ?? {};

      for (final cat in ['todos', 'habits', 'focus_sessions', 'diaries']) {
        await _mergeIntoLocal(
          (cloudData[cat] as List?)?.cast<Map<String, dynamic>>() ?? [],
          cat,
          (cloudTombs[cat] as List?)?.cast<Map<String, String>>() ?? [],
        );
      }

      return SyncResult.ok('已从云端合并数据');
    } catch (e) {
      return SyncResult.fail('下载异常：$e');
    }
  }

  /// 同步：先下载后上传（双向合并）
  static Future<SyncResult> sync(AppSettings settings) async {
    final dl = await download(settings);
    if (!dl.success) return dl;
    return upload(settings);
  }

  /// 测试连接
  static Future<SyncResult> testConnection(AppSettings settings) async {
    final rawUrl = settings.webdavUrl.trim();
    if (rawUrl.isEmpty) return SyncResult.fail('请先填写 WebDAV 服务器地址');
    final base = _normalizeUrl(rawUrl);
    try {
      final r = await http
          .get(Uri.parse(_fileUrl(settings)),
              headers: {'Authorization': _basicAuth(settings)})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        return SyncResult.ok('连接成功 ✓（云端已有备份）');
      } else if (r.statusCode == 404) {
        return SyncResult.ok('连接成功 ✓（云端暂无备份，请上传）');
      } else if (r.statusCode == 401) {
        return SyncResult.fail('鉴权失败：用户名或密码错误\n→ 坚果云需在网页端生成应用专用密码');
      } else {
        return SyncResult.fail('连接异常：HTTP ${r.statusCode}');
      }
    } catch (e) {
      return SyncResult.fail('连接失败：$e\n→ 请检查设备是否联网，地址是否正确');
    }
  }

  // ========== 墓碑合并 ==========

  static List<Map<String, String>> _mergeTombstones({
    required List<Map<String, String>> local,
    required List<Map<String, String>> remote,
  }) {
    final merged = <String, Map<String, String>>{};
    for (final t in [...local, ...remote]) {
      final id = t['id']!;
      final existing = merged[id];
      if (existing == null) {
        merged[id] = t;
      } else {
        final tTime = DateTime.parse(t['deletedAt']!);
        final eTime = DateTime.parse(existing['deletedAt']!);
        if (tTime.isAfter(eTime)) {
          merged[id] = t;
        }
      }
    }
    return merged.values.toList();
  }
}
```

---

### Task 3: Todo Provider — 删除时写墓碑 + 公开 reload

**Files:**
- Modify: `lib/providers/todo_provider.dart`

- [ ] **Step 1: 在 `remove()` 方法中添加墓碑写入**

找到 `remove` 方法（约第 121 行），改为：

```dart
  Future<void> remove(String id) async {
    // 写墓碑
    await WebDavSyncService.writeTombstone('todos', id);
    await HiveService.todoBox.delete(id);
    _load();
  }
```

同时在文件顶部 import 后面加：

```dart
import '../services/webdav_sync_service.dart';
```

- [ ] **Step 2: 将 `_load()` 暴露为公开方法 `reload()`**

在 `_load()` 方法后添加公开的 `reload()` 方法：

```dart
  /// 供同步下载后刷新 UI
  void reload() {
    _load();
  }
```

---

### Task 4: Habit Provider — 删除时写墓碑 + 公开 reload

**Files:**
- Modify: `lib/providers/habit_provider.dart`

- [ ] **Step 1: 在 `remove()` 方法中添加墓碑写入**

找到 `remove` 方法（约第 73 行），改为：

```dart
  Future<void> remove(String id) async {
    await WebDavSyncService.writeTombstone('habits', id);
    await HiveService.habitBox.delete(id);
    _load();
  }
```

文件顶部加 import：

```dart
import '../services/webdav_sync_service.dart';
```

- [ ] **Step 2: 添加公开 `reload()` 方法**

```dart
  /// 供同步下载后刷新 UI
  void reload() {
    _load();
  }
```

---

### Task 5: Diary Provider — 删除时写墓碑 + 公开 reload

**Files:**
- Modify: `lib/providers/diary_provider.dart`

- [ ] **Step 1: 在 `remove()` 方法中添加墓碑写入**

找到 `remove` 方法（约第 65 行），改为：

```dart
  Future<void> remove(String id) async {
    await WebDavSyncService.writeTombstone('diaries', id);
    await HiveService.diaryBox.delete(id);
    _load();
  }
```

文件顶部加 import：

```dart
import '../services/webdav_sync_service.dart';
```

- [ ] **Step 2: 添加公开 `reload()` 方法**

```dart
  /// 供同步下载后刷新 UI
  void reload() {
    _load();
  }
```

---

### Task 6: Focus Provider — 删除时写墓碑 + 公开 reload

**Files:**
- Modify: `lib/providers/focus_provider.dart`

- [ ] **Step 1: 在 `removeSession()` 和 `removeSessionsByName()` 中添加墓碑写入**

找到 `removeSession`（约第 276 行），改为：

```dart
  Future<void> removeSession(String id) async {
    await WebDavSyncService.writeTombstone('focus_sessions', id);
    await HiveService.focusBox.delete(id);
    _loadSessions();
  }
```

找到 `removeSessionsByName`（约第 283 行），在删除循环中添加墓碑：

```dart
  Future<void> removeSessionsByName(String groupName) async {
    final ids = <String>[];
    for (final s in state.sessions) {
      final name = (s.taskName == null || s.taskName!.isEmpty) ? '专注' : s.taskName!;
      if (name == groupName) ids.add(s.id);
    }
    for (final id in ids) {
      await WebDavSyncService.writeTombstone('focus_sessions', id);
      await HiveService.focusBox.delete(id);
    }
    _loadSessions();
  }
```

文件顶部加 import：

```dart
import '../services/webdav_sync_service.dart';
```

- [ ] **Step 2: 添加公开 `reload()` 方法**

```dart
  /// 供同步下载后刷新 UI
  void reload() {
    _loadSessions();
  }
```

---

### Task 7: 设置页面 — 三个按钮 + 修复刷新

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: 替换三个操作按钮区域**

找到三个按钮的区域（测试连接/上传/下载），替换为同步/上传/下载三个按钮：

先找到现有的三个按钮 block（约第 205-248 行附近），替换为：

```dart
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
```

- [ ] **Step 2: 在 `_doAction` 方法的 switch 中添加 sync case、upload case，并修复下载后的刷新**

找到 `_doAction` 方法，修改同步操作部分：

```dart
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
      } else {
        // 'sync'
        result = await WebDavSyncService.sync(settings);
        if (result.success) {
          ref.read(appSettingsProvider.notifier).markSynced(result.time ?? DateTime.now());
          _refreshAllProviders();
        }
      }
    } catch (e) {
      result = SyncResult.fail('异常：$e');
    }
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _lastStatus = (result.success ? '✓ ' : '✗ ') + result.message;
    });
  }

  /// 同步按钮专用
  Future<void> _doSync(AppSettings settings) async {
    await _doAction('sync', settings);
  }
```

- [ ] **Step 3: 修复 `_refreshAllProviders` — 真正刷新数据**

找到 `_refreshAllProviders` 方法（约第 348 行），替换为：

```dart
  void _refreshAllProviders() {
    ref.read(todoProvider.notifier).reload();
    ref.read(habitProvider.notifier).reload();
    ref.read(diaryProvider.notifier).reload();
    ref.read(focusProvider.notifier).reload();
  }
```

- [ ] **Step 4: 同时移除不再使用的 provider refresh key 定义**

删除文件底部的：

```dart
final todoProviderRefresh = Provider<void>((ref) => null);
final habitProviderRefresh = Provider<void>((ref) => null);
final diaryProviderRefresh = Provider<void>((ref) => null);
```

同时确保文件顶部有所有需要的 import。检查是否还需要 `diary_provider.dart`, `focus_provider.dart`, `todo_provider.dart` 的 import——`_refreshAllProviders` 现在直接调用 `notifier.reload()`，所以需要这些 import 中的 provider 引用。

确认文件顶部有这些 import：
```dart
import '../providers/todo_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/diary_provider.dart';
import '../providers/focus_provider.dart';
```

- [ ] **Step 5: 移除不再使用的 `test` action（旧代码中的测试连接按钮已移除，但 test action 在 _doAction 中仍保留，可以留着供测试使用）**

保持不变即可——testConnection 逻辑保留在 `_doAction` 中以便将来需要。

---

### Task 8: 构建验证

- [ ] **Step 1: 编译构建**

```bash
cd C:\codes\xu-master
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

Expected: 构建成功，无编译错误。

- [ ] **Step 2: 确认 APK 大小**

APK 应在 ~7.3MB 左右。

---
