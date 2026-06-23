import 'package:drift/drift.dart';

/// 搜索历史数据表
/// 
/// 存储用户的搜索历史记录
class SearchHistoryEntity extends Table {
  /// 表名
  @override
  String get tableName => 'search_history';

  /// 搜索关键词（唯一）
  TextColumn get name => text().unique()();
  
  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
