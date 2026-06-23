import 'package:drift/drift.dart';

/// 本地歌单数据表
/// 
/// 存储本地歌单的基本信息
class LocalMusicOrderEntity extends Table {
  /// 表名
  @override
  String get tableName => 'local_music_order';

  /// 歌单 ID
  TextColumn get id => text()();
  
  /// 歌单名称
  TextColumn get name => text()();
  
  /// 歌单描述
  TextColumn get desc => text().nullable()();
  
  /// 封面图片URL
  TextColumn get cover => text().nullable()();
  
  /// 作者
  TextColumn get author => text().nullable()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// 主键
  @override
  Set<Column> get primaryKey => {id};
}
