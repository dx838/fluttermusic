import 'dart:convert';

import 'package:bbmusic/constants/cache_key.dart';
import 'package:bbmusic/origin_sdk/origin_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 播放列表缓存服务
class PlayerListCache {
  /// 加载播放列表
  static Future<List<MusicItem>> load() async {
    try {
      final localStorage = await SharedPreferences.getInstance();
      final cacheStr = localStorage.getString(CacheKey.playerList);
      if (cacheStr != null && cacheStr.isNotEmpty) {
        final List<dynamic> cacheData = jsonDecode(cacheStr);
        return cacheData.map((item) => _fromJson(item)).toList();
      }
    } catch (e) {
      print('加载播放列表缓存失败: $e');
    }
    return [];
  }

  /// 保存播放列表
  static Future<void> save(List<MusicItem> list) async {
    try {
      final localStorage = await SharedPreferences.getInstance();
      final cacheData = list.map((e) => _toJson(e)).toList();
      await localStorage.setString(CacheKey.playerList, jsonEncode(cacheData));
    } catch (e) {
      print('保存播放列表缓存失败: $e');
    }
  }

  /// 清空播放列表缓存
  static Future<void> clear() async {
    try {
      final localStorage = await SharedPreferences.getInstance();
      await localStorage.remove(CacheKey.playerList);
    } catch (e) {
      print('清空播放列表缓存失败: $e');
    }
  }

  static Map<String, dynamic> _toJson(MusicItem item) {
    return {
      'id': item.id,
      'cover': item.cover,
      'name': item.name,
      'duration': item.duration,
      'author': item.author,
      'origin': item.origin.name,
    };
  }

  static MusicItem _fromJson(Map<String, dynamic> json) {
    return MusicItem(
      id: json['id'] ?? '',
      cover: json['cover'] ?? '',
      name: json['name'] ?? '',
      duration: json['duration'] ?? 0,
      author: json['author'] ?? '',
      origin: OriginType.values.firstWhere(
        (e) => e.name == json['origin'],
        orElse: () => OriginType.bili,
      ),
    );
  }
}
