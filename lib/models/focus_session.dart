import 'package:hive/hive.dart';

/// 单次专注会话记录
///
/// 每次"完成或暂停"专注时写入一条 FocusSession。
/// taskName 为当时设置的专注任务名（可空，对应未命名的"专注"）。
class FocusSession extends HiveObject {
  String id;
  DateTime startTime;
  int durationSeconds;  // 实际专注时长（秒）
  bool completed;       // 是否完整完成（true=走完一轮；false=中途暂停/重置）
  String mode;          // 'focus' / 'short_break' / 'long_break'
  String? taskName;     // ★ 新增：当时专注的任务名
  DateTime updatedAt;

  FocusSession({
    required this.id,
    required this.startTime,
    required this.durationSeconds,
    this.completed = true,
    this.mode = 'focus',
    this.taskName,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// 序列化为 Map
  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'durationSeconds': durationSeconds,
        'completed': completed,
        'mode': mode,
        'taskName': taskName,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// 从 Map 反序列化
  static FocusSession fromJson(Map<String, dynamic> m) => FocusSession(
        id: m['id'] as String,
        startTime: DateTime.parse(m['startTime'] as String),
        durationSeconds: m['durationSeconds'] as int,
        completed: (m['completed'] as bool?) ?? true,
        mode: (m['mode'] as String?) ?? 'focus',
        taskName: m['taskName'] as String?,
        updatedAt:
            m['updatedAt'] != null ? DateTime.parse(m['updatedAt'] as String) : DateTime.now(),
      );
}

/// Hive Adapter
///
/// 字段顺序：
/// 0: id
/// 1: startTime
/// 2: durationSeconds
/// 3: completed
/// 4: mode
/// 5: taskName (新增，向后兼容：老数据无此字段时为 null)
/// 6: updatedAt
class FocusSessionAdapter extends TypeAdapter<FocusSession> {
  @override
  final int typeId = 2;

  @override
  FocusSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FocusSession(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      durationSeconds: fields[2] as int,
      completed: (fields[3] as bool?) ?? true,
      mode: (fields[4] as String?) ?? 'focus',
      taskName: fields[5] as String?,
      updatedAt: fields[6] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, FocusSession obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.startTime)
      ..writeByte(2)..write(obj.durationSeconds)
      ..writeByte(3)..write(obj.completed)
      ..writeByte(4)..write(obj.mode)
      ..writeByte(5)..write(obj.taskName)
      ..writeByte(6)..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusSessionAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
