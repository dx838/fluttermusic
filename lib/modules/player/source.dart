import 'dart:async';
import 'dart:typed_data';

// 音频服务库
import 'package:audio_service/audio_service.dart';
// 音乐来源类型定义
import 'package:bbmusic/origin_sdk/origin_types.dart';
// 音乐来源服务
import 'package:bbmusic/origin_sdk/service.dart';
// 日志工具
import 'package:bbmusic/utils/logs.dart';
// 消息提示库
import 'package:bot_toast/bot_toast.dart';
// 缓存管理库
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
// HTTP 客户端
import 'package:http/http.dart';
// 音频播放库
import 'package:just_audio/just_audio.dart';

/// 音频缓存管理器
final audioCacheManage = CacheManager(Config("bbmusicMediaCache"));

/// 哔哔音乐音频源
/// 
/// 继承自StreamAudioSource，实现了音频流的获取、缓存和管理
class BBMusicSource extends StreamAudioSource {
  /// 音频数据字节列表
  final List<int> _bytes = [];
  /// 音频源长度
  int? _sourceLength;
  /// 内容类型
  String _contentType = 'video/mp4';
  /// 音乐项
  final MusicItem music;
  /// 是否初始化
  bool _isInit = false;
  /// 缓存键
  String get _cacheKey => music2cacheKey(music);

  /// 获取媒体项标签
  @override
  MediaItem get tag {
    return MediaItem(
      id: music.id,
      title: music.name,
      artUri: Uri.parse(music.cover),
    );
  }

  /// 获取音乐流
  /// 
  /// [music]: 音乐项
  /// [callback]: 数据回调函数
  /// 
  /// 返回值：StreamedResponse对象
  Future<StreamedResponse> getMusicStream(
    MusicItem music,
    Function(List<int> data) callback,
  ) async {
    final completer = Completer<StreamedResponse>();

    // 获取音乐URL
    service.getMusicUrl(music.id).then((musicUrl) {
      // 创建HTTP请求
      var request = Request('GET', Uri.parse(musicUrl.url));
      // 添加请求头
      request.headers.addAll(musicUrl.headers ?? {});
      Client client = Client();
      // 发送请求
      client.send(request).then((response) {
        var isStart = false;
        // 监听响应流
        response.stream.listen((List<int> data) {
          // 回调数据
          callback(data);
          if (!isStart) {
            // 第一次接收到数据时完成completer
            completer.complete(response);
            isStart = true;
          }
        }, onDone: () async {
          // 缓冲完成后将歌曲添加到缓存
          var bytes = Uint8List.fromList(_bytes);
          var ext = musicUrl.url.split('?').first.split('.').last;
          await audioCacheManage.putFile(
            musicUrl.url,
            bytes,
            key: _cacheKey,
            fileExtension: ext,
            maxAge: const Duration(days: 365 * 100), // 缓存100年
          );
        }, onError: (error) {
          completer.completeError(error);
        });
      }).catchError((error) {
        completer.completeError(error);
      });
    }).catchError((error) {
      completer.completeError(error);
    });
    return completer.future;
  }

  /// 构造函数
  /// 
  /// [music]: 音乐项
  BBMusicSource(this.music);

  /// 初始化音频源
  _init() async {
    if (_isInit) return;
    try {
      // 获取音乐流
      var resp = await getMusicStream(music, (List<int> data) {
        _bytes.addAll(data);
      });
      // 设置源长度和内容类型
      _sourceLength = resp.contentLength;
      _contentType = resp.headers['content-type'] ?? 'video/mp4';
      _isInit = true;
    } catch (e) {
      // 显示错误提示
      BotToast.showText(text: '音频源加载失败');
      logs.e("音频源加载失败", error: e);
      rethrow;
    }
  }

  /// 获取缓存文件
  /// 
  /// [start]: 开始位置
  /// [end]: 结束位置
  /// 
  /// 返回值：StreamAudioResponse对象，若缓存不存在则返回null
  Future<StreamAudioResponse?> _getCacheFile(int? start, int? end) async {
    // 读取缓存
    final cacheFile = await audioCacheManage.getFileFromCache(_cacheKey);

    if (cacheFile?.file != null) {
      if (cacheFile!.file.existsSync()) {
        var file = cacheFile.file;
        final sourceLength = file.lengthSync();
        return StreamAudioResponse(
          rangeRequestsSupported: true,
          sourceLength: sourceLength,
          contentLength: (end ?? sourceLength) - (start ?? 0),
          offset: start,
          contentType: "video/mp4",
          stream: file.openRead(start, end).asBroadcastStream(),
        );
      }
    }
    return null;
  }

  /// 请求音频数据
  /// 
  /// [start]: 开始位置
  /// [end]: 结束位置
  /// 
  /// 返回值：StreamAudioResponse对象
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // 检查缓存
    final cacheFile = await _getCacheFile(start, end);
    if (cacheFile != null) {
      // 缓存命中，返回缓存文件
      return cacheFile;
    }
    
    // 初始化音频源
    await _init();
    start ??= 0;
    // print("开始长度: $start");
    // print("结束长度: $end");
    // print("bytes.length: ${_bytes.length}");
    end ??= _bytes.length;

    // 轮询 _bytes 的长度, 等待 _bytes 有足够的数据
    while (_bytes.length < end) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 返回音频响应
    return StreamAudioResponse(
      sourceLength: _sourceLength,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: _contentType,
      rangeRequestsSupported: true,
    );
  }
}

/// 将音乐项转换为缓存键
/// 
/// [music]: 音乐项
/// 
/// 返回值：缓存键字符串
String music2cacheKey(MusicItem music) {
  return "${music.origin.value}-${music.id}";
}
