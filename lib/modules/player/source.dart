import 'dart:async';
import 'dart:io';

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
// 路径工具
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 音频缓存管理器
/// 修复 M7：增加 maxNrOfCacheObjects 上限，避免只增不减
final audioCacheManage = CacheManager(
  Config(
    "bbmusicMediaCache",
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 200,
  ),
);

/// 哔哔音乐音频源
///
/// 修复 M4/M5/M6：
/// - 不再持有整首歌字节 `_bytes`，改用文件流式提供
/// - 下载完成后立即落盘缓存，未命中缓存时写到临时目录再 stream
/// - HTTP `Client` 在 finally 中统一关闭
class BBMusicSource extends StreamAudioSource {
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
  /// 临时文件（仅在未命中缓存时存在）
  File? _tempFile;
  /// HTTP 客户端（用于切歌时主动取消）
  Client? _httpClient;
  /// 响应订阅（用于主动取消）
  StreamSubscription<List<int>>? _responseSub;

  /// 获取媒体项标签
  @override
  MediaItem get tag {
    return MediaItem(
      id: music.id,
      title: music.name,
      artUri: Uri.parse(music.cover),
    );
  }

  /// 构造函数
  ///
  /// [music]: 音乐项
  BBMusicSource(this.music);

  /// 下载到缓存文件或临时文件
  ///
  /// 命中缓存：直接返回缓存文件对象
  /// 未命中：使用 HTTP 流式下载到临时文件，完成后再写入 cache
  Future<File> _download() async {
    // 1) 先检查缓存
    final cacheFile = await audioCacheManage.getFileFromCache(_cacheKey);
    if (cacheFile?.file != null && cacheFile!.file.existsSync()) {
      return cacheFile.file;
    }

    // 2) 命中失败，下载到临时文件
    final tmpDir = await getTemporaryDirectory();
    final ext = 'mp3';
    final tempPath = p.join(
      tmpDir.path,
      'bbmusic_${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    final tmpFile = File(tempPath);
    _tempFile = tmpFile;
    final sink = tmpFile.openWrite();

    try {
      // 获取音乐 URL
      final musicUrl = await service.getMusicUrl(music.id);
      // 创建 HTTP 请求
      final request = Request('GET', Uri.parse(musicUrl.url));
      request.headers.addAll(musicUrl.headers ?? {});
      final client = Client();
      _httpClient = client;
      final response = await client.send(request);

      _sourceLength = response.contentLength;
      _contentType = response.headers['content-type'] ?? 'video/mp4';

      // 流式写入临时文件
      final completer = Completer<void>();
      _responseSub = response.stream.listen(
        (List<int> data) {
          sink.add(data);
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          // 写入缓存（异步，不阻塞主流程）
          unawaited(_writeToCache(musicUrl.url, tmpFile, ext));
          completer.complete();
        },
        onError: (error, stack) {
          // 出错时关闭 sink 便于删除
          sink.close().catchError((_) {});
          if (!completer.isCompleted) {
            completer.completeError(error, stack);
          }
        },
        cancelOnError: true,
      );
      await completer.future;
      return tmpFile;
    } catch (e) {
      // 出错时清理临时文件
      await sink.close().catchError((_) {});
      if (await tmpFile.exists()) {
        await tmpFile.delete().catchError((_) {});
      }
      _tempFile = null;
      rethrow;
    }
  }

  /// 写缓存（容错：失败不影响主播放）
  Future<void> _writeToCache(String url, File file, String ext) async {
    try {
      final bytes = await file.readAsBytes();
      await audioCacheManage.putFile(
        url,
        bytes,
        key: _cacheKey,
        fileExtension: ext,
        maxAge: const Duration(days: 30),
      );
    } catch (e) {
      logs.e('写缓存失败', error: e);
    }
  }

  /// 初始化音频源
  Future<File> _init() async {
    if (_isInit && _sourceLength != null) {
      // 已初始化且有文件可用
      if (_tempFile != null && _tempFile!.existsSync()) return _tempFile!;
      final cacheFile = await audioCacheManage.getFileFromCache(_cacheKey);
      if (cacheFile?.file != null) return cacheFile!.file;
    }
    try {
      final file = await _download();
      _isInit = true;
      return file;
    } catch (e) {
      BotToast.showText(text: '音频源加载失败');
      logs.e('音频源加载失败', error: e);
      rethrow;
    }
  }

  /// 请求音频数据
  ///
  /// [start]: 开始位置
  /// [end]: 结束位置
  ///
  /// 返回值：StreamAudioResponse 对象
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // 优先检查缓存
    final cacheFile = await audioCacheManage.getFileFromCache(_cacheKey);
    if (cacheFile?.file != null && cacheFile!.file.existsSync()) {
      final file = cacheFile.file;
      final sourceLength = file.lengthSync();
      return StreamAudioResponse(
        rangeRequestsSupported: true,
        sourceLength: sourceLength,
        contentLength: (end ?? sourceLength) - (start ?? 0),
        offset: start,
        contentType: _contentType,
        stream: file.openRead(start, end).asBroadcastStream(),
      );
    }

    // 未命中缓存：下载到临时文件，再以流式方式返回
    final file = await _init();
    final sourceLength = file.lengthSync();
    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: sourceLength,
      contentLength: (end ?? sourceLength) - (start ?? 0),
      offset: start,
      contentType: _contentType,
      stream: file.openRead(start, end).asBroadcastStream(),
    );
  }

  /// 释放资源
  ///
  /// 在切歌时被 `BBPlayer._play` 调用 `audio.clearAudioSources()` 触发
  @override
  Future<void> dispose() async {
    // 取消响应订阅
    await _responseSub?.cancel();
    _responseSub = null;
    // 关闭 HTTP 客户端（修复 M5）
    _httpClient?.close();
    _httpClient = null;
    // 删除临时文件
    final f = _tempFile;
    _tempFile = null;
    if (f != null) {
      try {
        if (await f.exists()) {
          await f.delete();
        }
      } catch (e) {
        logs.e('删除临时文件失败', error: e);
      }
    }
    _isInit = false;
    _sourceLength = null;
    super.dispose();
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
