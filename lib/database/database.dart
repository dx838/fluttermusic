import 'package:bbmusic/database/entity/cloud_music_order.entity.dart';
import 'package:bbmusic/database/entity/local_music_list.entity.dart';
import 'package:bbmusic/database/entity/local_music_order.entity.dart';
import 'package:bbmusic/database/entity/open_music_order_url.entity.dart';
import 'package:bbmusic/database/entity/player_list.entity.dart';
import 'package:bbmusic/database/entity/search_history.entity.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// 应用数据库类
/// 
/// 使用 Drift 库实现的本地数据库，包含以下数据表：
/// - CloudMusicOrderEntity: 云歌单数据表
/// - LocalMusicOrderEntity: 本地歌单数据表
/// - LocalMusicListEntity: 本地音乐列表数据表
/// - OpenMusicOrderUrlEntity: 开放歌单URL数据表
/// - PlayerListEntity: 播放器列表数据表
/// - SearchHistoryEntity: 搜索历史数据表
@DriftDatabase(tables: [
  CloudMusicOrderEntity,
  LocalMusicOrderEntity,
  LocalMusicListEntity,
  OpenMusicOrderUrlEntity,
  PlayerListEntity,
  SearchHistoryEntity,
])
class AppDatabase extends _$AppDatabase {
  /// 构造函数
  /// 
  /// [executor]: 可选的查询执行器，若为null则使用默认连接
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// 数据库架构版本
  @override
  int get schemaVersion => 1;

  /// 打开数据库连接
  /// 
  /// 返回值：数据库查询执行器
  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bbmusic_database', // 数据库名称
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory, // 数据库存储目录
      ),
    );
  }
}
