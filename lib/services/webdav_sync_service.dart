import 'dart:convert';
import 'package:hive/hive.dart';
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

  static const _categories = ['todos', 'habits', 'focus_sessions', 'diaries'];

  // ========== URL normalization ==========

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

  // ========== Tombstones ==========

  /// Write a local tombstone for a deleted item
  static Future<void> writeTombstone(String category, String id) async {
    final key = '${category}_$id';
    await HiveService.tombstonesBox.put(key, DateTime.now().toIso8601String());
  }

  /// Clear synced tombstones for a category after successful upload/sync
  static Future<void> _clearTombstones(String category) async {
    final prefix = '${category}_';
    final keys = HiveService.tombstonesBox.keys
        .where((k) => k is String && (k as String).startsWith(prefix))
        .toList();
    for (final k in keys) {
      await HiveService.tombstonesBox.delete(k);
    }
  }

  // ========== HTTP helpers ==========

  static String _basicAuth(AppSettings s) {
    final raw = '${s.webdavUsername}:${s.webdavPassword}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }

  /// Fetch cloud JSON, returns null if not found (404), throws on auth/other errors
  static Future<Map<String, dynamic>?> _fetchCloud(AppSettings s) async {
    try {
      final r = await http
          .get(Uri.parse(_fileUrl(s)), headers: {'Authorization': _basicAuth(s)})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      }
      if (r.statusCode == 404) return null; // No backup yet
      // Don't silently fail for auth errors
      throw Exception('HTTP ${r.statusCode}');
    } on Exception {
      rethrow;
    } catch (_) {
      return null; // Network errors only
    }
  }

  /// PUT data to cloud, returns HTTP status code (0 on error)
  static Future<int> _putCloud(AppSettings s, Map<String, dynamic> payload) async {
    try {
      final body = utf8.encode(jsonEncode(payload));
      // Ensure subdirectory exists (坚果云 requires it)
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

  // ========== Collect local data ==========

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
      'summary':
          '${todos.length} items / ${habits.length} habits / ${sessions.length} focus / ${diaries.length} diaries',
    };
  }

  /// Collect local tombstones in cloud format
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
      for (final cat in _categories) {
        if (k.startsWith('${cat}_')) {
          result[cat]!.add({'id': k.substring('${cat}_'.length), 'deletedAt': v});
          break;
        }
      }
    }
    return result;
  }

  // ========== Safe list conversion (avoids lazy .cast<> type errors) ==========

  /// Convert a JSON-decoded dynamic value to a properly typed List<Map<String, dynamic>>.
  /// Uses eager conversion to avoid "list<dynamic> is not a subtype of list<Map<String,dynamic>>" errors.
  static List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value == null) return <Map<String, dynamic>>[];
    if (value is! List) return <Map<String, dynamic>>[];
    return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Convert a JSON-decoded dynamic value to a properly typed List<Map<String, String>>.
  /// Uses eager conversion to avoid lazy-cast type errors.
  static List<Map<String, String>> _toStringMapList(dynamic value) {
    if (value == null) return <Map<String, String>>[];
    if (value is! List) return <Map<String, String>>[];
    return value
        .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
        .toList();
  }

  // ========== Merge logic ==========

  /// Merge two lists by id, comparing updatedAt, newer wins.
  /// Tombstones with time > item's updatedAt cause deletion.
  static List<Map<String, dynamic>> _mergeLists({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> remote,
    required List<Map<String, String>> localTombstones,
    required List<Map<String, String>> remoteTombstones,
  }) {
    final result = <String, Map<String, dynamic>>{};

    // Merge tombstones: find latest tombstone time per id
    final tombTimes = <String, DateTime>{};
    for (final t in [...localTombstones, ...remoteTombstones]) {
      final time = DateTime.parse(t['deletedAt']!);
      final id = t['id']!;
      if (tombTimes[id] == null || time.isAfter(tombTimes[id]!)) {
        tombTimes[id] = time;
      }
    }

    // Collect all entries
    final allEntries = <Map<String, dynamic>>[...local, ...remote];

    for (final entry in allEntries) {
      final id = entry['id'] as String;

      // Check if killed by a tombstone
      if (tombTimes.containsKey(id)) {
        DateTime entryTime;
        try {
          entryTime = DateTime.parse(entry['updatedAt'] as String? ?? '');
        } catch (_) {
          entryTime = DateTime(2000); // broken timestamps should lose
        }
        if (tombTimes[id]!.isAfter(entryTime)) {
          // Item was deleted after last update — skip it
          result.remove(id);
          continue;
        }
      }

      final existing = result[id];
      if (existing == null) {
        result[id] = Map<String, dynamic>.from(entry);
      } else {
        // Compare updatedAt, keep newer
        DateTime existingTime;
        DateTime entryTime;
        try {
          existingTime = DateTime.parse(existing['updatedAt'] as String? ?? '');
          entryTime = DateTime.parse(entry['updatedAt'] as String? ?? '');
        } catch (_) {
          existingTime = DateTime(2000); // broken timestamps should lose
          entryTime = DateTime(2000);
        }
        if (entryTime.isAfter(existingTime)) {
          result[id] = Map<String, dynamic>.from(entry);
        }
      }
    }

    return result.values.toList();
  }

  /// Merge tombstones: keep newest tombstone per id
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

  // ========== Write merged data to local Hive ==========

  static Future<void> _mergeIntoLocal(
    List<Map<String, dynamic>> remoteList,
    String category,
    List<Map<String, String>> remoteTombstones,
  ) async {
    // Collect local tombstones
    final localTombstones = <Map<String, String>>[];
    final prefix = '${category}_';
    for (final entry in HiveService.tombstonesBox.toMap().entries) {
      final k = entry.key as String;
      if (k.startsWith(prefix)) {
        localTombstones.add({'id': k.substring(prefix.length), 'deletedAt': entry.value as String});
      }
    }

    switch (category) {
      case 'todos':
        await _mergeCategory(
          remoteList: remoteList,
          remoteTombstones: remoteTombstones,
          localTombstones: localTombstones,
          box: HiveService.todoBox,
          localToJson: (t) => t.toJson(),
          fromJson: (m) => Todo.fromJson(Map<String, dynamic>.from(m)),
        );
      case 'habits':
        await _mergeCategory(
          remoteList: remoteList,
          remoteTombstones: remoteTombstones,
          localTombstones: localTombstones,
          box: HiveService.habitBox,
          localToJson: (h) => h.toJson(),
          fromJson: (m) => Habit.fromJson(Map<String, dynamic>.from(m)),
        );
      case 'focus_sessions':
        await _mergeCategory(
          remoteList: remoteList,
          remoteTombstones: remoteTombstones,
          localTombstones: localTombstones,
          box: HiveService.focusBox,
          localToJson: (s) => s.toJson(),
          fromJson: (m) => FocusSession.fromJson(Map<String, dynamic>.from(m)),
        );
      case 'diaries':
        await _mergeCategory(
          remoteList: remoteList,
          remoteTombstones: remoteTombstones,
          localTombstones: localTombstones,
          box: HiveService.diaryBox,
          localToJson: (d) => d.toJson(),
          fromJson: (m) => Diary.fromJson(Map<String, dynamic>.from(m)),
        );
    }

    // Clear synced tombstones for this category
    await _clearTombstones(category);
  }

  /// Generic merge for a single category — avoids dynamic/inferred types that cause
  /// "list<dynamic> is not a subtype of list<Map<String,dynamic>>" errors.
  static Future<void> _mergeCategory<T extends dynamic>({
    required List<Map<String, dynamic>> remoteList,
    required List<Map<String, String>> remoteTombstones,
    required List<Map<String, String>> localTombstones,
    required Box<T> box,
    required Map<String, dynamic> Function(T) localToJson,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    // Collect local data — everything is statically typed, no dynamic downcasts
    final List<Map<String, dynamic>> localList =
        box.values.map((v) => localToJson(v)).toList();

    // Merge
    final merged = _mergeLists(
      local: localList,
      remote: remoteList,
      localTombstones: localTombstones,
      remoteTombstones: remoteTombstones,
    );

    // Build the list of objects first (validate all fromJson succeed)
    final objects = merged.map((m) => fromJson(m)).toList();

    // Only after ALL objects are built, clear and write
    await box.clear();
    for (final obj in objects) {
      await box.put(obj.id, obj);
    }
  }

  // ========== Three public operations ==========

  /// Upload: read cloud → merge local into cloud → write back → clear local tombstones
  static Future<SyncResult> upload(AppSettings settings) async {
    final rawUrl = settings.webdavUrl.trim();
    if (rawUrl.isEmpty) return SyncResult.fail('Please enter the WebDAV server address');

    try {
      // 1) Read cloud
      final cloud = await _fetchCloud(settings);

      // 2) Collect local data
      final local = _collectAllData();

      Map<String, dynamic> merged;
      if (cloud != null && cloud['version'] != null) {
        // Merge with cloud
        merged = Map<String, dynamic>.from(cloud);
        merged['lastModified'] = DateTime.now().toIso8601String();
        final cloudData = (cloud['data'] as Map<String, dynamic>?) ?? {};
        final cloudTombs = (cloud['tombstones'] as Map<String, dynamic>?) ?? {};
        final localData = local['data'] as Map<String, dynamic>;
        final localTombs = local['tombstones'] as Map<String, dynamic>;

        final mergedData = <String, dynamic>{};
        for (final cat in _categories) {
          mergedData[cat] = _mergeLists(
            local: _toMapList(localData[cat]),
            remote: _toMapList(cloudData[cat]),
            localTombstones: _toStringMapList(localTombs[cat]),
            remoteTombstones: _toStringMapList(cloudTombs[cat]),
          );
        }
        merged['data'] = mergedData;

        // Merge tombstones
        final mergedTombs = <String, dynamic>{};
        for (final cat in _categories) {
          mergedTombs[cat] = _mergeTombstones(
            local: _toStringMapList(localTombs[cat]),
            remote: _toStringMapList(cloudTombs[cat]),
          );
        }
        merged['tombstones'] = mergedTombs;
        merged['summary'] = local['summary'];
      } else {
        // No cloud data — push local directly
        merged = local;
      }

      // 3) PUT
      final code = await _putCloud(settings, merged);
      if (code == 200 || code == 201 || code == 204 || code == 207) {
        // 4) Clear synced tombstones
        for (final cat in _categories) {
          await _clearTombstones(cat);
        }
        return SyncResult.ok('Uploaded: ${local['summary']}');
      } else if (code == 401) {
        return SyncResult.fail('Authentication failed (401). Please check username and app-specific password');
      } else {
        return SyncResult.fail('Upload failed: HTTP $code');
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('hostname') || msg.contains('No address')) {
        return SyncResult.fail('DNS resolution failed. Check the server address.\nJianGuoYun: dav.jianguoyun.com/dav');
      }
      return SyncResult.fail('Upload error: $e');
    }
  }

  /// Download: read cloud → merge into Hive → return (caller reloads providers)
  static Future<SyncResult> download(AppSettings settings) async {
    final rawUrl = settings.webdavUrl.trim();
    if (rawUrl.isEmpty) return SyncResult.fail('Please enter the WebDAV server address');

    try {
      final cloud = await _fetchCloud(settings);
      if (cloud == null) {
        return SyncResult.fail('No backup file found in cloud. Upload first.');
      }

      final cloudData = (cloud['data'] as Map<String, dynamic>?) ?? {};
      final cloudTombs = (cloud['tombstones'] as Map<String, dynamic>?) ?? {};

      for (final cat in _categories) {
        await _mergeIntoLocal(
          _toMapList(cloudData[cat]),
          cat,
          _toStringMapList(cloudTombs[cat]),
        );
      }

      return SyncResult.ok('Merged data from cloud');
    } catch (e) {
      return SyncResult.fail('Download error: $e');
    }
  }

  /// Sync: download first, then upload (bidirectional merge)
  static Future<SyncResult> sync(AppSettings settings) async {
    final dl = await download(settings);
    if (!dl.success) return dl;
    return upload(settings);
  }

  /// Test WebDAV connection
  static Future<SyncResult> testConnection(AppSettings settings) async {
    final rawUrl = settings.webdavUrl.trim();
    if (rawUrl.isEmpty) return SyncResult.fail('Please enter the WebDAV server address');
    try {
      final r = await http
          .get(Uri.parse(_fileUrl(settings)),
              headers: {'Authorization': _basicAuth(settings)})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        return SyncResult.ok('Connected (backup exists)');
      } else if (r.statusCode == 404) {
        return SyncResult.ok('Connected (no backup yet, upload first)');
      } else if (r.statusCode == 401) {
        return SyncResult.fail('Authentication failed.\nJianGuoYun: generate an app-specific password in web settings.');
      } else {
        return SyncResult.fail('Connection error: HTTP ${r.statusCode}');
      }
    } catch (e) {
      return SyncResult.fail('Connection failed: $e\nCheck network and server address.');
    }
  }
}
