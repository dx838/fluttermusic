import 'dart:async';

// 音频服务库
import 'package:audio_service/audio_service.dart';
// 播放器服务
import 'package:bbmusic/modules/player/service.dart';
// 音频播放库
import 'package:just_audio/just_audio.dart';
// Flutter 核心库
import 'package:flutter/material.dart';
// 播放器常量定义
import 'package:bbmusic/modules/player/const.dart';
// 音乐来源类型定义
import 'package:bbmusic/origin_sdk/origin_types.dart';

/// 播放器模型类
/// 
/// 管理播放器的状态和操作，提供播放、暂停、上一首、下一首等功能
/// 继承自ChangeNotifier，用于状态管理和通知UI更新
class PlayerModel extends ChangeNotifier {
  /// 获取音频播放器实例
  AudioPlayer? get _audio => _playerHandler?.player.audio;
  
  /// 获取当前播放歌曲的总时长
  Duration? get duration => _audio?.duration;
  
  /// 后台播放服务实例
  AudioHandler? _playerService;
  
  /// 音频播放器处理器实例
  AudioPlayerHandler? _playerHandler;
  
  /// 获取当前播放的歌曲
  MusicItem? get current => _playerHandler?.current;
  
  /// 歌曲是否正在加载
  bool get isLoading => _playerHandler?.player.isLoading ?? false;
  
  /// 是否正在播放
  bool get isPlaying {
    return _playerHandler?.player.isPlaying ?? false;
  }

  /// 获取播放列表
  List<MusicItem> get playerList {
    return _playerHandler?.player.playerList ?? [];
  }

  /// 获取当前播放模式
  PlayerMode get playerMode {
    return _playerHandler?.player.playerMode ?? PlayerMode.random;
  }

  /// 初始化播放器模型
  /// 
  /// [playerHandler]: 音频播放器处理器实例
  /// [playerService]: 后台播放服务实例
  init({
    required AudioPlayerHandler playerHandler,
    required AudioHandler playerService,
  }) async {
    // 初始化后台服务和处理器
    _playerHandler = playerHandler;
    _playerService = playerService;
    
    // 初始化播放器
    await playerHandler.player.init();
    
    // 监听播放器状态变化，通知UI更新
    _audio?.playerStateStream.listen((event) {
      notifyListeners();
    });
  }

  /// 播放歌曲
  /// 
  /// [music]: 可选参数，指定要播放的歌曲，若为null则播放当前歌曲
  Future<void> play({MusicItem? music}) async {
    await _playerHandler?.play(music: music);
    notifyListeners();
  }

  /// 暂停播放
  Future<void> pause() async {
    await _playerService?.pause();
    notifyListeners();
  }

  /// 播放上一首
  Future<void> prev() async {
    await _playerService?.skipToPrevious();
    notifyListeners();
  }

  /// 播放下一首
  Future<void> next() async {
    await _playerService?.skipToNext();
    notifyListeners();
  }

  /// 跳转播放进度
  /// 
  /// [position]: 目标位置
  Future<void>? seek(Duration position) => _playerHandler?.seek(position);

  /// 切换播放模式
  /// 
  /// [mode]: 可选参数，指定要切换到的模式，若为null则循环切换
  void togglePlayerMode({PlayerMode? mode}) {
    _playerHandler?.player.togglePlayerMode();
    notifyListeners();
  }

  /// 添加歌曲到播放列表
  /// 
  /// [musics]: 要添加的歌曲列表
  void addPlayerList(List<MusicItem> musics) {
    _playerHandler?.player.addPlayerList(musics);
    notifyListeners();
  }

  /// 从播放列表中移除歌曲
  /// 
  /// [musics]: 要移除的歌曲列表
  void removePlayerList(List<MusicItem> musics) {
    _playerHandler?.player.removePlayerList(musics);
    notifyListeners();
  }

  /// 清空播放列表
  void clearPlayerList() {
    _playerHandler?.player.clearPlayerList();
    notifyListeners();
  }

  /// 重载播放列表
  Future<void> reloadPlayerList() async {
    await _playerHandler?.player.reloadPlayerList();
    notifyListeners();
  }

  /// 切换播放完成后自动关闭功能
  void togglePlayDoneAutoClose() {
    _playerHandler?.player.autoClose.togglePlayDoneAutoClose();
    notifyListeners();
  }

  /// 获取播放完成后自动关闭功能的状态
  get playDoneAutoClose {
    return _playerHandler?.player.autoClose.openPlayDoneAutoClose ?? false;
  }

  /// 设置自动关闭处理
  /// 
  /// [duration]: 自动关闭的时间
  autoCloseHandler(Duration duration) {
    return _playerHandler?.player.autoClose.close(duration);
  }

  /// 监听播放进度
  /// 
  /// [onData]: 进度更新回调函数
  /// 
  /// 返回值：StreamSubscription<Duration>，可用于取消监听
  StreamSubscription<Duration>? listenPosition(
    void Function(Duration)? onData,
  ) {
    return _audio?.positionStream.listen(onData);
  }
}
