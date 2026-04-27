import 'package:drift/drift.dart';

/// 云歌单数据表
/// 
/// 存储云歌单源的配置信息
class CloudMusicOrderEntity extends Table {
  /// 表名
  @override
  String get tableName => 'cloud_music_order';

  /// 歌单源 ID
  TextColumn get id => text()();
  
  /// 歌单源类型（如：github, gitee, webdav）
  TextColumn get origin => text()();
  
  /// 歌单源子名称（用户自定义名称）
  TextColumn get subName => text()();
  
  /// 配置信息（JSON格式）
  TextColumn get config => text()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// 主键
  @override
  Set<Column> get primaryKey => {id};
}
