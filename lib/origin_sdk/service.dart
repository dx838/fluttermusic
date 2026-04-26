import 'package:bbmusic/origin_sdk/bili/client.dart';

/// 音乐源服务实例
/// 
/// 全局使用的哔哩哔哩音乐源服务实例，用于获取音乐数据
/// 
/// 该实例实现了 OriginService 接口，提供以下功能：
/// - 搜索音乐和歌单
/// - 获取搜索建议
/// - 获取歌曲详情
/// - 获取歌曲播放地址
/// 
/// 使用示例：
/// ```dart
/// // 搜索音乐
/// final response = await service.search(SearchParams(keyword: '周杰伦', page: 1));
/// 
/// // 获取歌曲播放地址
/// final musicUrl = await service.getMusicUrl('BV1xx411c7mW');
/// ```
var service = BiliClient();
