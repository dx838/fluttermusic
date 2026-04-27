import 'dart:async';
import 'dart:convert';
import 'dart:math';

// 缓存键常量
import 'package:bbmusic/constants/cache_key.dart';
// 数据库
import 'package:bbmusic/database/database.dart';
// 播放器常量定义
import 'package:bbmusic/modules/player/const.dart';
// 播放器音频源
import 'package:bbmusic/modules/player/source.dart';
// 音乐来源类型定义
import 'package:bbmusic/origin_sdk/origin_types.dart';
// 工具类
import 'package:bbmusic/utils/utils.dart';
// 消息提示库
import 'package:bot_toast/bot_toast.dart';
// 数据库操作库
import 'package:drift/drift.dart';
// Flutter 基础库
import 'package:flutter/foundation.dart';
// 音频播放库
import 'package:just_audio/just_audio.dart';
// 本地存储库
import 'package:shared_preferences/shared_preferences.dart';

/// 缓存键 - 当前播放歌曲
final _storageKeyCurrent = CacheKey.playerCurrent;
/// 缓存键 - 播放模式
final _storageKeyPlayerMode = CacheKey.playerMode;
/// 缓存键 - 播放进度
final _storageKeyPosition = CacheKey.playerPosition;
/// 缓存键 - 播放历史列表
final _storageKeyHistoryList = CacheKey.playerHistoryList;

/// 哔哔音乐播放器核心类
/// 
/// 实现了播放器的核心功能，包括：
/// - 播放、暂停、上一首、下一首
/// - 播放列表管理
/// - 播放模式切换（单曲循环、列表循环、随机、顺序）
/// - 播放历史记录
/// - 自动关闭功能
/// - 本地存储缓存
class BBPlayer {
  /// 定时器，用于防抖
  Timer? _timer;
  /// 歌曲是否正在加载
  bool isLoading = false;
  /// 是否正在播放
  bool get isPlaying {
    return audio.playing;
  }

  /// 音频播放器实例
  final audio = AudioPlayer();
  /// 当前播放的歌曲
  MusicItem? current;
  /// 播放列表
  final List<MusicItem> playerList = [];
  /// 播放历史，用于随机播放时避免重复
  final List<String> _playerHistory = [];
  /// 当前播放模式
  PlayerMode playerMode = PlayerMode.random;

  /// 自动关闭音乐实例
  late AutoCloseMusic autoClose;

  /// 数据库实例
  final db = AppDatabase();

  /// 初始化播放器
  Future<void> init() async {
    // 初始化自动关闭功能
    autoClose = AutoCloseMusic(onPause: () {
      pause();
    });
    
    // 初始化本地存储
    await _initLocalStorage();
    
    // 创建节流函数，避免播放结束事件重复触发
    var throttleEndNext = Throttle(const Duration(seconds: 1));

    // 监听播放状态变化
    audio.playerStateStream.listen((state) {
      // 加载状态
      if (state.processingState == ProcessingState.loading) {
        isLoading = true;
      }
      // 就绪状态
      if (state.processingState == ProcessingState.ready) {
        isLoading = false;
      }
      // 播放完成状态
      if (state.processingState == ProcessingState.completed) {
        // 使用节流方法避免重复触发
        throttleEndNext.call(() {
          // 如果开启了播放完成后自动关闭
          if (autoClose.isPlayDoneAutoClose) {
            autoClose.isPlayDoneAutoClose = false;
            return pause();
          }
          // 否则播放下一首
          return endNext();
        });
      }
      // notifyListeners();
    });
    // audio.bufferedPositionStream.listen((duration) {
    //   print('缓冲进度：$duration;  总进度：${audio.bufferedPositionStream}');
    // });
    // 记住播放进度
    var t = DateTime.now();
    audio.positionStream.listen((event) {
      var n = DateTime.now();
      if (t.add(const Duration(seconds: 15)).isBefore(n)) {
        _cachePosition();
        t = n;
      }
    });
  }

  /// 销毁播放器
  void dispose() {
    // 释放音频播放器资源
    audio.dispose();
    // 取消定时器
    _timer?.cancel();
  }

  /// 播放错误处理
  /// 
  /// [e]: 错误信息
  Future<void> playError(e) async {
    // 显示错误提示
    BotToast.showText(text: "播放歌曲失败：$e");
    log("播放歌曲失败：$e");
    // 延时2秒后播放下一首
    await Future.delayed(const Duration(seconds: 2));
    await next();
  }

  /// 播放歌曲
  /// 
  /// [music]: 可选参数，指定要播放的歌曲，若为null则播放当前歌曲或播放列表第一首
  Future<void> play({MusicItem? music}) async {
    log('PLAY: $music');
    log('current: $current');

    try {
      if (music != null) {
        // 检查播放列表中是否已存在该歌曲
        if (playerList.where((e) => e.id == music.id).isEmpty) {
          // 不存在，添加到播放列表
          addPlayerList([music]);
        }

        // 如果是新歌曲
        if (current?.id != music.id) {
          current = music;
          _updateLocalStorage();
          log("播放新歌曲");
          // 重置播放进度
          await audio.seek(Duration.zero);
          // 播放歌曲
          await _play(music: music);
          // 添加到播放历史
          _addPlayerHistory();
        } else {
          // 和 current 相等
          if (isPlaying) {
            // 播放中则暂停
            log("播放中暂停");
            await audio.pause();
          } else {
            // 暂停中则恢复播放
            log("暂停中恢复播放");
            await _play();
          }
        }
      } else {
        // 未指定歌曲
        if (current != null) {
          // 有当前歌曲
          if (isPlaying) {
            // 播放中则暂停
            log("播放中暂停");
            await audio.pause();
          } else {
            // 停止中则恢复播放
            log("停止中恢复播放");
            await _play();
          }
        } else {
          // 没有当前歌曲
          if (playerList.isNotEmpty) {
            // 播放列表不为空，播放第一首
            current = playerList.first;
            _updateLocalStorage();
            if (current != null) {
              await _play(music: current);
              _addPlayerHistory();
            }
          }
        }
      }
      // 更新本地存储
      _updateLocalStorage();
    } catch (e) {
      // 播放失败处理
      audio.stop();
      audio.clearAudioSources();
      final msg = "歌曲 ${music?.name ?? "未知"} 播放失败";
      BotToast.showText(text: "$msg：$e");
      log("$msg：$e");
      // 延时2秒后播放下一首
      await Future.delayed(const Duration(seconds: 2));
      await next();
    }
    // notifyListeners();
  }

  /// 暂停播放
  Future<void> pause() async {
    await audio.pause();
    // notifyListeners();
  }

  /// 播放上一首
  Future<void> prev() async {
    // 重置播放进度
    await audio.seek(Duration.zero);
    if (current != null) {
      // 查找当前歌曲在播放历史中的位置
      int ind = _playerHistory.indexOf(current!.id);
      if (ind > 0) {
        // 获取上一首歌曲的ID
        String prevId = _playerHistory[ind - 1];
        // 查找播放列表中的歌曲
        final ms = playerList.where((e) => e.id == prevId);
        if (ms.isNotEmpty) {
          // 播放上一首
          await play(music: ms.first);
        }
      }
    }
    // 更新本地存储
    _updateLocalStorage();
  }

  /// 播放下一首
  /// 
  /// [notSeek]: 是否不重置播放进度
  Future<void> next({bool notSeek = false}) async {
    if (current == null) return;
    if (playerMode != PlayerMode.signalLoop) {
      // 非单曲循环模式，调用结束播放逻辑
      await endNext(notSeek: notSeek);
    } else {
      // 单曲循环模式
      int index = playerList.indexWhere((p) => p.id == current!.id);
      if (!notSeek) {
        // 重置播放进度
        await audio.seek(Duration.zero);
      }
      if (playerList.length == 1) {
        // 只有一首歌曲，单曲循环
        await play(music: current);
      } else if (index == playerList.length - 1) {
        // 最后一首，循环到第一首
        await play(music: playerList[0]);
      } else {
        // 播放下一首
        await play(music: playerList[index + 1]);
      }
    }
    // 更新本地存储
    _updateLocalStorage();
  }

  /// 结束播放，处理下一首逻辑
  /// 
  /// [notSeek]: 是否不重置播放进度
  Future<void> endNext({bool notSeek = false}) async {
    log("播放结束");
    if (current == null) return;

    // 单曲循环函数
    signalLoop() async {
      if (!notSeek) {
        await audio.seek(Duration.zero);
      }
      await play(music: current);
    }

    // 单曲循环模式
    if (playerMode == PlayerMode.signalLoop) {
      await signalLoop();
      if (!audio.playing) {
        audio.play();
      }
      _updateLocalStorage();
      return;
    }
    
    // 随机播放模式
    if (playerMode == PlayerMode.random) {
      // 过滤出未播放过的歌曲
      List<MusicItem> list = 
          playerList.where((p) => !_playerHistory.contains(p.id)).toList();
      int len = list.length;
      if (!notSeek) {
        await audio.seek(Duration.zero);
      }
      if (len == 0) {
        // 所有歌曲都已播放过，清空历史
        _playerHistory.clear();
        // 随机选择一首
        int nn = playerList.length;
        var r = Random().nextInt(nn);
        await play(music: playerList[r]);
      } else {
        // 随机选择一首未播放过的
        var r = Random().nextInt(len);
        await play(music: list[r]);
      }
      if (!audio.playing) {
        audio.play();
      }
      _updateLocalStorage();
      return;
    }
    
    // 查找当前歌曲在播放列表中的位置
    int index = playerList.indexWhere((p) => p.id == current!.id);
    
    // 列表顺序播放模式
    if (playerMode == PlayerMode.listOrder) {
      if (index != playerList.length - 1) {
        // 不是最后一首，播放下一首
        if (!notSeek) {
          await audio.seek(Duration.zero);
        }
        await play(music: playerList[index + 1]);
        if (!audio.playing) {
          audio.play();
        }
      }
      // 是最后一首，停止播放
    }
    
    // 列表循环模式
    if (playerMode == PlayerMode.listLoop) {
      if (!notSeek) {
        await audio.seek(Duration.zero);
      }
      if (playerList.length == 1) {
        // 只有一首，单曲循环
        await signalLoop();
      } else if (index == playerList.length - 1) {
        // 最后一首，循环到第一首
        await play(music: playerList[0]);
      } else {
        // 播放下一首
        await play(music: playerList[index + 1]);
      }
      if (!audio.playing) {
        audio.play();
      }
    }
    // 更新本地存储
    _updateLocalStorage();
  }

  /// 切换播放模式
  /// 
  /// [mode]: 可选参数，指定要切换到的模式，若为null则循环切换
  void togglePlayerMode({PlayerMode? mode}) {
    if (mode != null) {
      // 指定模式
      playerMode = mode;
    } else {
      // 循环切换模式
      const l = [
        PlayerMode.signalLoop,
        PlayerMode.listLoop,
        PlayerMode.random,
        PlayerMode.listOrder,
      ];
      int index = l.indexWhere((p) => playerMode == p);

      if (index == l.length - 1) {
        // 最后一个模式，切换到第一个
        playerMode = l[0];
      } else {
        // 切换到下一个模式
        playerMode = l[index + 1];
      }
    }
    // 更新本地存储
    _updateLocalStorage();
    // notifyListeners();
  }

  /// 添加歌曲到播放列表
  /// 
  /// [musics]: 要添加的歌曲列表
  Future<void> addPlayerList(List<MusicItem> musics) async {
    // 先移除已存在的歌曲，避免重复
    removePlayerList(musics);
    // 添加到播放列表
    playerList.addAll(musics);
    // 从数据库中删除已存在的歌曲
    await db.managers.playerListEntity
        .filter((f) => f.id.isIn(musics.map((m) => m.id)))
        .delete();
    // 批量添加到数据库
    await db.managers.playerListEntity.bulkCreate((o) {
      return musics.map((m) {
        return o(
          id: m.id,
          cover: Value(m.cover),
          name: m.name,
          duration: m.duration,
          author: Value(m.author),
          origin: m.origin.value,
        );
      });
    });
  }

  /// 从播放列表中移除歌曲
  /// 
  /// [musics]: 要移除的歌曲列表
  Future<void> removePlayerList(List<MusicItem> musics) async {
    // 从内存播放列表中移除
    playerList.removeWhere((w) => musics.where((e) => e.id == w.id).isNotEmpty);
    // 从数据库中删除
    final ids = musics.map((m) => m.id);
    await db.managers.playerListEntity.filter((f) => f.id.isIn(ids)).delete();
  }

  /// 清空播放列表
  Future<void> clearPlayerList() async {
    // 清空内存播放列表
    playerList.clear();
    // 清空数据库中的播放列表
    await db.playerListEntity.deleteAll();
  }

  /// 添加到播放历史（用于随机播放）
  void _addPlayerHistory() {
    if (current != null) {
      // 先移除已存在的记录，避免重复
      _playerHistory.removeWhere((e) => e == current!.id);
      // 添加到历史记录末尾
      _playerHistory.add(current!.id);
    }
  }

  /// 内部播放方法
  /// 
  /// [music]: 要播放的歌曲
  /// [isPlay]: 是否立即播放
  Future<void> _play({MusicItem? music, bool isPlay = true}) async {
    if (music != null) {
      // 设置音频源
      await audio.setAudioSources([BBMusicSource(music)]);
    }
    if (isPlay) {
      // 开始播放
      await audio.play();
    } else {
      // 暂停
      await audio.pause();
    }
  }

  /// 缓存播放进度
  Future<void> _cachePosition() async {
    final localStorage = await SharedPreferences.getInstance();
    localStorage.setInt(
      _storageKeyPosition,
      audio.position.inMilliseconds,
    );
  }

  /// 更新本地存储
  void _updateLocalStorage() {
    // 取消之前的定时器
    _timer?.cancel();
    // 延迟500微秒执行，避免频繁写入
    _timer = Timer(const Duration(microseconds: 3000), () async {
      final localStorage = await SharedPreferences.getInstance();
      // 保存当前歌曲
      localStorage.setString(
        _storageKeyCurrent,
        current != null ? jsonEncode(current) : "",
      );
      // 保存播放模式
      localStorage.setString(
        _storageKeyPlayerMode,
        playerMode.value.toString(),
      );
      // 保存播放历史
      localStorage.setStringList(
        _storageKeyHistoryList,
        _playerHistory,
      );
    });
  }

  /// 初始化本地存储
  Future<void> _initLocalStorage() async {
    final localStorage = await SharedPreferences.getInstance();
    
    // 读取当前歌曲
    String? c = localStorage.getString(_storageKeyCurrent);
    if (c != null && c.isNotEmpty) {
      var data = jsonDecode(c) as Map<String, dynamic>;
      current = MusicItem(
        id: data['id'],
        name: data['name'],
        cover: data['cover'],
        author: data['author'],
        duration: data['duration'],
        origin: OriginType.getByValue(data['origin']),
      );

      // 设置音频源，但不播放
      _play(music: current!, isPlay: false).then((res) {
        // 恢复播放进度
        final pos = localStorage.getInt(_storageKeyPosition) ?? 0;
        if (pos > 0) {
          audio.seek(Duration(milliseconds: pos));
        }
      });
    }

    // 读取播放模式
    String? m = localStorage.getString(_storageKeyPlayerMode);
    if (m != null && m.isNotEmpty) {
      playerMode = PlayerMode.getByValue(int.parse(m));
    }

    // 读取播放历史
    List<String>? h = localStorage.getStringList(_storageKeyHistoryList);
    if (h != null && h.isNotEmpty) {
      _playerHistory.clear();
      _playerHistory.addAll(h);
    }

    // 重载播放列表
    reloadPlayerList();
  }

  /// 重载播放列表
  Future<void> reloadPlayerList() async {
    // 从数据库中读取播放列表
    List<PlayerListEntityData> pl = await db.managers.playerListEntity.get();
    // 清空内存播放列表
    playerList.clear();
    // 转换为MusicItem列表
    final ms = pl.map((p) {
      return MusicItem(
        id: p.id,
        name: p.name,
        cover: p.cover ?? '',
        author: p.author ?? '',
        duration: p.duration,
        origin: OriginType.getByValue(p.origin),
      );
    }).toList();
    // 添加到内存播放列表
    playerList.addAll(ms);
  }
}

/// 自动关闭音乐功能
/// 
/// 实现了定时关闭音乐的功能，支持两种模式：
/// 1. 定时直接关闭
/// 2. 等待当前歌曲播放完成后关闭
class AutoCloseMusic {
  /// 是否开启等待播放完成后再关闭
  bool openPlayDoneAutoClose = false;
  /// 是否正在等待播放完成后关闭
  bool isPlayDoneAutoClose = false;
  /// 关闭时间
  DateTime? closeTime;
  /// 自动关闭定时器
  Timer? autoCloseTimer;

  /// 暂停回调函数
  final Function onPause;

  /// 构造函数
  /// 
  /// [onPause]: 暂停回调函数
  AutoCloseMusic({
    required this.onPause,
  });

  /// 切换等待播放完成后再关闭的状态
  void togglePlayDoneAutoClose() {
    openPlayDoneAutoClose = !openPlayDoneAutoClose;
  }

  /// 设置自动关闭
  /// 
  /// [duration]: 倒计时时间
  void close(Duration duration) {
    // 重置状态
    isPlayDoneAutoClose = false;
    // 取消之前的定时器
    if (autoCloseTimer != null) {
      autoCloseTimer!.cancel();
    }

    // 设置时间为 5 min 后
    final now = DateTime.now();
    closeTime = now.add(duration);

    // 创建定时器
    autoCloseTimer = Timer(duration, () {
      if (openPlayDoneAutoClose) {
        // 开启了等待播放完成后关闭
        isPlayDoneAutoClose = true;
      } else {
        // 直接关闭
        onPause();
      }
    });
  }

  /// 取消自动关闭
  void cancel() {
    // 重置状态
    closeTime = null;
    isPlayDoneAutoClose = false;
    // 取消定时器
    if (autoCloseTimer != null) {
      autoCloseTimer!.cancel();
    }
  }
}

/// 日志函数
/// 
/// [value]: 日志内容
/// 
/// 仅在非生产环境打印日志
log(String value) {
  // 判断是否是生产环境
  if (!kReleaseMode) {
    print(value);
  }
}
