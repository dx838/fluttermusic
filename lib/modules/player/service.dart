import 'dart:async';

// 音频服务库
import 'package:audio_service/audio_service.dart';
// 播放器实例
import 'package:bbmusic/modules/player/instance.dart';
// 音频播放库
import 'package:just_audio/just_audio.dart';
// 音乐来源类型定义
import 'package:bbmusic/origin_sdk/origin_types.dart';

/// 音频播放器处理器
/// 
/// 继承自BaseAudioHandler，实现音频服务的核心功能
/// 处理播放、暂停、上一首、下一首等操作
class AudioPlayerHandler extends BaseAudioHandler {
  /// 哔哔音乐播放器实例
  final BBPlayer player = BBPlayer();
  
  /// 播放事件
  late PlaybackEvent _audioEvent;
  
  /// 播放状态
  bool _playing = false;
  
  /// 获取播放速度
  double get _speed => player.audio.speed;
  
  /// 获取当前播放的歌曲
  MusicItem? get current => player.current;

  /// 构造函数
  AudioPlayerHandler() {
    // 初始化播放事件
    _audioEvent = PlaybackEvent();
    
    // 定时器，用于防抖
    Timer? timer;
    
    // 监听播放事件流
    player.audio.playbackEventStream.listen((event) {
      _audioEvent = event;
    });
    
    // 监听播放器状态变化
    player.audio.playerStateStream.listen((state) {
      // 取消之前的定时器
      timer?.cancel();
      // 延迟100微秒执行，避免频繁更新
      timer = Timer(const Duration(microseconds: 250), () {
        // 更新媒体项
        _updateMediaItem();
        // 广播状态
        _broadcastState();
      });
    });
    
    // 初始更新媒体项
    _updateMediaItem();
    
    // 监听播放位置变化
    player.audio.positionStream.listen((position) {
      _updatePosition();
    });
    
    // 监听时长变化
    player.audio.durationStream.listen((duration) {
      if (mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });
  }
  
  /// 播放歌曲
  /// 
  /// [music]: 可选参数，指定要播放的歌曲，若为null则播放当前歌曲
  @override
  Future<void> play({MusicItem? music}) async {
    _playing = true;
    await player.play(music: music);
    _updateMediaItem();
    _updatePosition();
    _broadcastState();
  }

  /// 暂停播放
  @override
  Future<void> pause() async {
    _playing = false;
    await player.pause();
    _updatePosition();
    _broadcastState();
  }

  /// 跳转播放进度
  /// 
  /// [position]: 目标位置
  @override
  Future<void> seek(Duration position) => player.audio.seek(position);

  /// 播放上一首
  @override
  Future<void> skipToPrevious() async {
    await player.prev();
    _updateMediaItem();
    _broadcastState();
  }

  /// 播放下一首
  @override
  Future<void> skipToNext() async {
    await player.next();
    _updateMediaItem();
    _broadcastState();
  }

  /// 更新媒体项
  void _updateMediaItem() {
    if (player.current != null) {
      // 将MusicItem转换为MediaItem
      final newItem = music2mediaItem(player.current!);
      mediaItem.add(newItem.copyWith(
        duration: player.audio.duration ?? newItem.duration,
      ));
    }
  }

  /// 更新播放位置
  void _updatePosition() {
    _audioEvent = _audioEvent.copyWith(
      updatePosition: player.audio.position,
      bufferedPosition: player.audio.bufferedPosition,
      updateTime: DateTime.now(),
    );
  }

  /// 广播播放状态
  void _broadcastState() {
    // 构建媒体控制按钮
    final controls = [
      MediaControl.skipToPrevious,
      if (_playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
    ];
    
    // 映射处理状态
    final processingState = const {
      // ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[player.audio.processingState];
    
    // 广播状态
    playbackState.add(playbackState.value.copyWith(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices:
          List.generate(controls.length, (i) => i).toList(),
      processingState: processingState ?? AudioProcessingState.ready,
      playing: _playing,
      updatePosition: player.audio.position,
      bufferedPosition: player.audio.bufferedPosition,
      speed: _speed,
      queueIndex: _audioEvent.currentIndex,
    ));
  }
}

/// 将MusicItem转换为MediaItem
/// 
/// [music]: 要转换的MusicItem对象
/// 
/// 返回值：转换后的MediaItem对象
MediaItem music2mediaItem(MusicItem music) {
  return MediaItem(
    id: music.id,
    title: music.name,
    album: music.author,
    artist: music.author,
    duration: Duration(seconds: music.duration),
    artUri: Uri.parse(music.cover),
  );
}
