import 'package:bbmusic/database/uuid.dart';
import 'package:drift/drift.dart';

/// 本地歌单音乐列表数据表
/// 
/// 存储本地歌单中的歌曲信息
class LocalMusicListEntity extends Table {
  /// 表名
  @override
  String get tableName => 'local_music_list';
  
  /// 记录 ID
  TextColumn get id => text()();
  
  /// 关联的歌单 ID
  TextColumn get orderId => text()();
  
  /// 歌曲 ID
  TextColumn get musicId => text()();
  
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
