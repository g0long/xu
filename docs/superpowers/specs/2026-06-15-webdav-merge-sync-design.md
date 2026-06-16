# 多设备双向合并同步

**日期**: 2026-06-15
**状态**: 已确认

## 问题

当前同步是全量覆盖模型（上传=本地覆盖云端，下载=云端覆盖本地），且下载后 Provider 不刷新导致 UI 不更新。无法满足多设备同步需求。

## 方案

### 云端数据结构 (v2)

```json
{
  "version": 2,
  "app": "xu",
  "lastModified": "2026-06-15T10:30:00.000Z",
  "data": {
    "todos": [{ "id":"xxx", ... }],
    "habits": [...],
    "focus_sessions": [...],
    "diaries": [...]
  },
  "tombstones": {
    "todos": [{ "id":"xxx", "deletedAt":"2026-06-15T11:00:00Z" }],
    "habits": [],
    "focus_sessions": [],
    "diaries": []
  }
}
```

### 合并规则

- 按 `id` 匹配，比较 `updatedAt`，新者胜
- 墓碑同理 — 墓碑时间 > 条目的 updatedAt 则删除

### 三个操作

| 操作 | 行为 |
|------|------|
| 上传 | 读云端 → 合并 → 写回云端 → 清理本地墓碑 |
| 下载 | 读云端 → 合并 → 写入 Hive → 刷新 Provider |
| 同步 | 下载 + 上传（先拉后推，双向合并） |

### 墓碑

- 本地墓碑存储在 Hive Box `tombstones`（String→String，key=todo_<id>，value=删除时间）
- 合并完成后清理已同步到云端的墓碑

### 文件变更

| 文件 | 改动 |
|------|------|
| lib/services/hive_service.dart | 新增 tombstones box |
| lib/services/webdav_sync_service.dart | 重写为合并逻辑，版本升级 |
| lib/providers/todo_provider.dart | remove 时写墓碑，新增公开 reload() |
| lib/providers/habit_provider.dart | 同上 |
| lib/providers/diary_provider.dart | 同上 |
| lib/providers/focus_provider.dart | 同上 |
| lib/screens/settings_screen.dart | 按钮改为 同步/上传/下载，修复刷新 |
