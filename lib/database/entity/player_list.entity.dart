import 'package:drift/drift.dart';

/// 播放列表数据表
/// 
/// 存储播放器的歌曲列表信息
class PlayerListEntity extends Table {
  /// 表名
  @override
  String get tableName => 'player_list';

  /// 歌曲 ID
  TextColumn get id => text()();
  
  /// 歌曲名称
  TextColumn get name => text()();
  
  /// 时长（秒）
  IntColumn get duration => integer()();
  
  /// 歌曲封面图片URL
  TextColumn get cover => text().nullable()();
  
  /// 歌手
  TextColumn get author => text().nullable()();
  
  /// 歌曲来源（如：bili, youTube）
  TextColumn get origin => text()();
  
  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// 主键
  @override
  Set<Column> get primaryKey => {id};
}
