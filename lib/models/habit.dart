import 'package:hive/hive.dart';

/// 习惯打卡频率
/// - daily: 每日打卡
/// - weeklyNTimes: 每周 N 次
enum HabitFrequency {
  daily,
  weeklyNTimes,
}

/// 习惯模型
class Habit extends HiveObject {
  String id;
  String name;
  String emoji;       // 图标（emoji 形式，简单且跨平台）
  int colorIndex;     // 0-6 关联主题色
  HabitFrequency frequency;
  int weeklyTarget;   // 当 frequency == weeklyNTimes 时使用
  Map<String, bool> checkIns; // key = 'yyyy-MM-dd' 形式，value = 是否打卡
  DateTime createdAt;
  DateTime updatedAt;

  Habit({
    required this.id,
    required this.name,
    this.emoji = '💧',
    this.colorIndex = 0,
    this.frequency = HabitFrequency.daily,
    this.weeklyTarget = 7,
    Map<String, bool>? checkIns,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : checkIns = checkIns ?? <String, bool>{},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 当前连续打卡天数
  int get currentStreak {
    int streak = 0;
    DateTime d = DateTime.now();
    // 简化：从今天开始往前连续检查
    // （注意：未打卡的"今天"不打断昨日的连续记录）
    String todayKey = _keyOf(d);
    if (checkIns[todayKey] != true) {
      d = d.subtract(const Duration(days: 1));
    }
    while (true) {
      if (checkIns[_keyOf(d)] == true) {
        streak++;
        d = d.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// 历史最长连续天数
  int get longestStreak {
    if (checkIns.isEmpty) return 0;
    final dates = checkIns.entries
        .where((e) => e.value)
        .map((e) => DateTime.parse(e.key))
        .toList()
      ..sort();
    if (dates.isEmpty) return 0;

    int best = 1, cur = 1;
    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 1;
      }
    }
    return best;
  }

  /// 总完成率
  double get completionRate {
    if (frequency == HabitFrequency.daily) {
      final days = DateTime.now().difference(createdAt).inDays + 1;
      if (days <= 0) return 0;
      return (checkIns.values.where((v) => v).length / days).clamp(0.0, 1.0);
    } else {
      // 周频：实际算近 4 周达成率
      int weeksMet = 0;
      final now = DateTime.now();
      for (int w = 0; w < 4; w++) {
        final weekStart = now.subtract(Duration(days: now.weekday - 1 + 7 * w));
        int count = 0;
        for (int d = 0; d < 7; d++) {
          if (checkIns[_keyOf(weekStart.add(Duration(days: d)))] == true) {
            count++;
          }
        }
        if (count >= weeklyTarget) weeksMet++;
      }
      return weeksMet / 4.0;
    }
  }

  /// 切换某天的打卡状态
  void toggleCheckIn(DateTime date) {
    final key = _keyOf(date);
    checkIns[key] = !(checkIns[key] ?? false);
  }

  bool isCheckedOn(DateTime date) => checkIns[_keyOf(date)] ?? false;

  static String _keyOf(DateTime d) {
    final dt = DateTime(d.year, d.month, d.day);
    return dt.toIso8601String().substring(0, 10);
  }

  /// 序列化为 Map（用于云同步）
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorIndex': colorIndex,
        'frequency': frequency.index,
        'weeklyTarget': weeklyTarget,
        'checkIns': checkIns,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// 从 Map 反序列化
  static Habit fromJson(Map<String, dynamic> m) => Habit(
        id: m['id'] as String,
        name: m['name'] as String,
        emoji: (m['emoji'] as String?) ?? '💧',
        colorIndex: (m['colorIndex'] as int?) ?? 0,
        frequency: HabitFrequency.values[(m['frequency'] as int?) ?? 0],
        weeklyTarget: (m['weeklyTarget'] as int?) ?? 7,
        checkIns: (m['checkIns'] is Map)
            ? (m['checkIns'] as Map).map((k, v) => MapEntry(k.toString(), v as bool))
            : <String, bool>{},
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt:
            m['updatedAt'] != null ? DateTime.parse(m['updatedAt'] as String) : DateTime.now(),
      );
}

/// Hive Adapter
///
/// 字段顺序：
/// 0: id
/// 1: name
/// 2: emoji
/// 3: colorIndex
/// 4: frequency (HabitFrequency)
/// 5: weeklyTarget
/// 6: checkIns (Map<String, bool>)
/// 7: createdAt
/// 8: updatedAt
class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 1;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String,
      name: fields[1] as String,
      emoji: fields[2] as String,
      colorIndex: (fields[3] as int?) ?? 0,
      frequency: (fields[4] as HabitFrequency?) ?? HabitFrequency.daily,
      weeklyTarget: (fields[5] as int?) ?? 7,
      checkIns: (fields[6] as Map?)?.cast<String, bool>() ?? <String, bool>{},
      createdAt: fields[7] as DateTime? ?? DateTime.now(),
      updatedAt: fields[8] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.name)
      ..writeByte(2)..write(obj.emoji)
      ..writeByte(3)..write(obj.colorIndex)
      ..writeByte(4)..write(obj.frequency)
      ..writeByte(5)..write(obj.weeklyTarget)
      ..writeByte(6)..write(obj.checkIns)
      ..writeByte(7)..write(obj.createdAt)
      ..writeByte(8)..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HabitAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}

/// 枚举 Adapter
class HabitFrequencyAdapter extends TypeAdapter<HabitFrequency> {
  @override
  final int typeId = 3;

  @override
  HabitFrequency read(BinaryReader reader) {
    final index = reader.readByte();
    return HabitFrequency.values[index];
  }

  @override
  void write(BinaryWriter writer, HabitFrequency obj) {
    writer.writeByte(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitFrequencyAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
