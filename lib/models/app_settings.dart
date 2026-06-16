import 'package:hive/hive.dart';

/// 应用设置
class AppSettings extends HiveObject {
  /// tab 可见性
  Map<String, bool> visibleTabs;

  /// WebDAV 服务器地址（不含文件名）
  String webdavUrl;

  /// WebDAV 用户名
  String webdavUsername;

  /// WebDAV 密码
  String webdavPassword;

  /// 备份子目录（坚果云根目录不允许直接 PUT 文件，必须先建子目录）
  /// 默认 'xu_backups'，上传前会自动 MKCOL 创建
  String webdavBackupFolder;

  /// 备份文件名
  String webdavFilename;

  /// 启动时自动同步
  bool webdavAutoSync;

  /// 上次同步时间
  DateTime? lastSyncTime;

  /// GitHub 仓库 owner（用于检查更新）
  String githubOwner;

  /// GitHub 仓库 repo（用于检查更新）
  String githubRepo;

  /// 上次检查更新时间
  DateTime? lastUpdateCheckTime;

  /// 硬件墨水屏连接开关
  bool hardwareEnabled;

  /// 硬件后端IP地址（不含协议，如 192.168.1.100:8080）
  String hardwareBackendIp;

  AppSettings({
    Map<String, bool>? visibleTabs,
    this.webdavUrl = '',
    this.webdavUsername = '',
    this.webdavPassword = '',
    this.webdavBackupFolder = 'xu_backups',
    this.webdavFilename = 'xu_backup.json',
    this.webdavAutoSync = false,
    this.lastSyncTime,
    this.githubOwner = 'gol0ng',
    this.githubRepo = 'xu',
    this.lastUpdateCheckTime,
    this.hardwareEnabled = false,
    this.hardwareBackendIp = '',
  }) : visibleTabs = visibleTabs ??
            <String, bool>{
              'todo': true,
              'habit': true,
              'diary': true,
              'focus': true,
              'stats': true,
            };
}

/// Hive TypeAdapter（typeId = 5）
///
/// 字段顺序（追加在末尾，避免老数据错位）：
/// 0: visibleTabs
/// 1: webdavUrl
/// 2: webdavUsername
/// 3: webdavPassword
/// 4: webdavBackupFolder
/// 5: webdavFilename
/// 6: webdavAutoSync
/// 7: lastSyncTime
/// 8: githubOwner
/// 9: githubRepo
/// 10: lastUpdateCheckTime
/// 11: hardwareEnabled (新增)
/// 12: hardwareBackendIp (新增)
class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 5;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      visibleTabs: (fields[0] as Map?)?.cast<String, bool>() ??
          <String, bool>{
            'todo': true, 'habit': true, 'diary': true, 'focus': true, 'stats': true,
          },
      webdavUrl: (fields[1] as String?) ?? '',
      webdavUsername: (fields[2] as String?) ?? '',
      webdavPassword: (fields[3] as String?) ?? '',
      webdavBackupFolder: (fields[4] as String?) ?? 'xu_backups',
      webdavFilename: (fields[5] as String?) ?? 'xu_backup.json',
      webdavAutoSync: (fields[6] as bool?) ?? false,
      lastSyncTime: fields[7] as DateTime?,
      githubOwner: (fields[8] as String?) ?? 'gol0ng',
      githubRepo: (fields[9] as String?) ?? 'xu',
      lastUpdateCheckTime: fields[10] as DateTime?,
      hardwareEnabled: (fields[11] as bool?) ?? false,
      hardwareBackendIp: (fields[12] as String?) ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)..write(obj.visibleTabs)
      ..writeByte(1)..write(obj.webdavUrl)
      ..writeByte(2)..write(obj.webdavUsername)
      ..writeByte(3)..write(obj.webdavPassword)
      ..writeByte(4)..write(obj.webdavBackupFolder)
      ..writeByte(5)..write(obj.webdavFilename)
      ..writeByte(6)..write(obj.webdavAutoSync)
      ..writeByte(7)..write(obj.lastSyncTime)
      ..writeByte(8)..write(obj.githubOwner)
      ..writeByte(9)..write(obj.githubRepo)
      ..writeByte(10)..write(obj.lastUpdateCheckTime)
      ..writeByte(11)..write(obj.hardwareEnabled)
      ..writeByte(12)..write(obj.hardwareBackendIp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
