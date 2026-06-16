import 'package:hive/hive.dart';

/// 日记模型
///
/// - date: 日记所属日期（用户可以选择写"过去的某一天"）
/// - mood: 心情 emoji
/// - title/content: 标题与正文
/// - saying: 一句话金句（≤20字），可呈现在待办页顶部
class Diary extends HiveObject {
  String id;
  DateTime date;
  String title;
  String content;
  String mood; // emoji，如 😊
  String saying; // ★ 一句话金句（≤20字），呈现在待办顶部
  DateTime createdAt;
  DateTime updatedAt;

  Diary({
    required this.id,
    required this.date,
    this.title = '',
    this.content = '',
    this.mood = '📝',
    this.saying = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 序列化为 Map
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'content': content,
        'mood': mood,
        'saying': saying,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// 从 Map 反序列化
  static Diary fromJson(Map<String, dynamic> m) => Diary(
        id: m['id'] as String,
        date: DateTime.parse(m['date'] as String),
        title: (m['title'] as String?) ?? '',
        content: (m['content'] as String?) ?? '',
        mood: (m['mood'] as String?) ?? '📝',
        saying: (m['saying'] as String?) ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: m['updatedAt'] != null
            ? DateTime.parse(m['updatedAt'] as String)
            : DateTime.now(),
      );
}

/// Hive TypeAdapter（手动实现，typeId = 4）
///
/// 字段顺序（不可变更，只能追加）：
/// 0: id
/// 1: date
/// 2: title
/// 3: content
/// 4: mood
/// 5: saying (新增)
/// 6: createdAt
/// 7: updatedAt
class DiaryAdapter extends TypeAdapter<Diary> {
  @override
  final int typeId = 4;

  @override
  Diary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Diary(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      title: (fields[2] as String?) ?? '',
      content: (fields[3] as String?) ?? '',
      mood: (fields[4] as String?) ?? '📝',
      saying: (fields[5] as String?) ?? '',
      createdAt: fields[6] as DateTime? ?? DateTime.now(),
      updatedAt: fields[7] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, Diary obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.date)
      ..writeByte(2)..write(obj.title)
      ..writeByte(3)..write(obj.content)
      ..writeByte(4)..write(obj.mood)
      ..writeByte(5)..write(obj.saying)
      ..writeByte(6)..write(obj.createdAt)
      ..writeByte(7)..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
