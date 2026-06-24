import 'package:drift/drift.dart';

/// 歌单广场源数据表
/// 
/// 存储歌单广场的源URL
class OpenMusicOrderUrlEntity extends Table {
  /// 表名
  @override
  String get tableName => 'open_music_order_url';

  /// 记录 ID
  TextColumn get id => text()();
  
  /// 歌单广场源 URL
  TextColumn get url => text()();
  
  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 主键
  @override
  Set<Column> get primaryKey => {id};
}
