import 'package:uuid/uuid.dart';

/// UUID 实例
/// 
/// 用于生成唯一标识符
const uuid = Uuid();

/// 生成 UUID 字符串
/// 
/// 返回值：唯一的 UUID v4 字符串
/// 
/// 用途：
/// - 为数据库记录生成唯一 ID
/// - 为歌单和歌曲生成唯一标识符
/// - 确保数据唯一性
String generateUUID() {
  return uuid.v4();
}
