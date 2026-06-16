import 'package:hive/hive.dart';

/// 待办任务模型
///
/// 包含样图中的树状结构支持：每个 Todo 可包含子任务列表，
/// 父任务完成时不自动完成子任务，由用户自行勾选。
class Todo extends HiveObject {
  String id;
  String title;
  bool isDone;
  DateTime? dueDate;
  String? tag;        // 标签（可选）
  int colorIndex;     // 0-6，对应 7 种颜色（用于左侧小条）
  List<Todo> subtasks; // 子任务
  bool isExpanded;    // 是否展开子任务
  DateTime createdAt;
  DateTime updatedAt; // 最近一次变更（用于"已完成"页面显示完成时间）

  Todo({
    required this.id,
    required this.title,
    this.isDone = false,
    this.dueDate,
    this.tag,
    this.colorIndex = 0,
    List<Todo>? subtasks,
    this.isExpanded = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : subtasks = subtasks ?? <Todo>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 子任务完成数
  int get doneSubtaskCount => subtasks.where((t) => t.isDone).length;

  /// 序列化为 Map（用于云同步）
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
        'dueDate': dueDate?.toIso8601String(),
        'tag': tag,
        'colorIndex': colorIndex,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'isExpanded': isExpanded,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// 从 Map 反序列化
  static Todo fromJson(Map<String, dynamic> m) => Todo(
        id: m['id'] as String,
        title: m['title'] as String,
        isDone: (m['isDone'] as bool?) ?? false,
        dueDate: m['dueDate'] != null ? DateTime.parse(m['dueDate'] as String) : null,
        tag: m['tag'] as String?,
        colorIndex: (m['colorIndex'] as int?) ?? 0,
        subtasks: (m['subtasks'] is List)
                ? (m['subtasks'] as List)
                    .map((s) => Todo.fromJson(Map<String, dynamic>.from(s as Map)))
                    .toList()
                : <Todo>[],
        isExpanded: (m['isExpanded'] as bool?) ?? true,
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: m['updatedAt'] != null
            ? DateTime.parse(m['updatedAt'] as String)
            : DateTime.now(),
      );
}

/// Hive 手动 TypeAdapter（不依赖 build_runner）
///
/// 字段顺序（写死，不可改变顺序，只能追加）：
/// 0: id
/// 1: title
/// 2: isDone
/// 3: dueDate (DateTime?)
/// 4: tag (String?)
/// 5: colorIndex
/// 6: subtasks (List<Todo>)
/// 7: isExpanded
/// 8: createdAt
/// 9: updatedAt
class TodoAdapter extends TypeAdapter<Todo> {
  @override
  final int typeId = 0;

  @override
  Todo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Todo(
      id: fields[0] as String,
      title: fields[1] as String,
      isDone: fields[2] as bool,
      dueDate: fields[3] as DateTime?,
      tag: fields[4] as String?,
      colorIndex: (fields[5] as int?) ?? 0,
      subtasks: (fields[6] as List?)?.cast<Todo>() ?? <Todo>[],
      isExpanded: (fields[7] as bool?) ?? true,
      createdAt: fields[8] as DateTime? ?? DateTime.now(),
      updatedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Todo obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.title)
      ..writeByte(2)..write(obj.isDone)
      ..writeByte(3)..write(obj.dueDate)
      ..writeByte(4)..write(obj.tag)
      ..writeByte(5)..write(obj.colorIndex)
      ..writeByte(6)..write(obj.subtasks)
      ..writeByte(7)..write(obj.isExpanded)
      ..writeByte(8)..write(obj.createdAt)
      ..writeByte(9)..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TodoAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
