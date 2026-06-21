import 'package:flutter/material.dart';
import 'package:bbmusic/origin_sdk/origin_types.dart';

/// 用户歌单源抽象接口
/// 
/// 所有用户歌单源都必须实现此接口，提供歌单的增删改查等操作
abstract class UserMusicOrderOrigin {
  /// 歌单源名称（英文）
  String get name => '';
  
  /// 歌单源名称（中文）
  String get cname => '';
  
  /// 歌单源图标
  IconData? get icon => null;

  /// 构建歌单源配置界面
  /// 
  /// [value]: 当前配置值
  /// [onChange]: 配置变更回调函数
  /// 
  /// 返回值：配置界面组件，若返回null则表示不需要配置
  Widget? configBuild({
    Map<String, dynamic>? value,
    required Function(Map<String, dynamic>) onChange,
  });

  /// 检查歌单源是否可用
  /// 
  /// 返回值：true表示可用，false表示不可用
  bool canUse();

  /// 初始化歌单源配置
  /// 
  /// [config]: 配置信息
  Future<void> initConfig(Map<String, dynamic> config);

  /// 获取歌单列表
  /// 
  /// 返回值：歌单列表
  Future<List<MusicOrderItem>> getList();

  /// 创建歌单
  /// 
  /// [item]: 歌单数据
  Future<void> create(MusicOrderItem item);

  /// 更新歌单
  /// 
  /// [item]: 歌单数据
  Future<void> update(MusicOrderItem item);

  /// 删除歌单
  /// 
  /// [item]: 歌单数据
  Future<void> delete(MusicOrderItem item);

  /// 获取歌单详情
  /// 
  /// [id]: 歌单ID
  /// 
  /// 返回值：歌单详情数据
  Future<MusicOrderItem> getDetail(String id);

  /// 添加歌曲到歌单
  /// 
  /// [int]: 歌单ID（参数名应为id，此处保持原有命名）
  /// [musics]: 要添加的歌曲列表
  Future<void> appendMusic(String int, List<MusicItem> musics);

  /// 更新歌单中的歌曲
  /// 
  /// [id]: 歌单ID
  /// [musics]: 歌曲列表
  Future<void> updateMusic(String id, List<MusicItem> musics);

  /// 从歌单中移除歌曲
  /// 
  /// [id]: 歌单ID
  /// [musics]: 要移除的歌曲列表
  Future<void> deleteMusic(String id, List<MusicItem> musics);
}
