import 'dart:async';
import 'dart:io';

// 音频服务库，用于处理后台音频播放
import 'package:audio_service/audio_service.dart';
// 下载模块的模型类
import 'package:bbmusic/modules/download/model.dart';
// 开放歌单模块的模型类
import 'package:bbmusic/modules/open_music_order/model.dart';
// 歌单来源设置模块的模型类
import 'package:bbmusic/modules/setting/music_order_origin/mode.dart';
// 应用版本更新工具
import 'package:bbmusic/utils/update_version.dart';
// 窗口管理工具（针对桌面平台）
import 'package:bbmusic/utils/window_manage.dart';
// 日志工具
// -- import 'package:bbmusic/utils/logs.dart';
// import 'package:bbmusic/utils/logs.dart';
// 消息提示库
import 'package:bot_toast/bot_toast.dart';
// Flutter 核心库
import 'package:flutter/material.dart';
// 首页视图
import 'package:bbmusic/modules/home/home.dart';
// 播放器模型
import 'package:bbmusic/modules/player/model.dart';
// 播放器服务
import 'package:bbmusic/modules/player/service.dart';
// 媒体工具包，用于跨平台媒体播放
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
// 状态管理库
import 'package:provider/provider.dart';
// 数据同步工具
import 'package:bbmusic/modules/data_sync/data_sync.dart';

/// Toast 消息提示初始化
final botToastBuilder = BotToastInit();

/// 应用主题主色调
const primaryColor = Color.fromRGBO(103, 58, 183, 1);

/// 应用主题配置
ThemeData theme = ThemeData(
  // 使用 Material 3 设计
  useMaterial3: true,
  // 基于种子色创建色彩方案
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.white,
    primary: primaryColor,
    brightness: Brightness.light,
  ),
  // 设置主色调
  primaryColor: primaryColor,
);

/// 音频播放器处理器实例
final _playerHandler = AudioPlayerHandler();

/// 应用入口函数
/// 
/// 主要初始化步骤：
/// 1. 初始化桌面平台的窗口管理
/// 2. 确保 Flutter 绑定初始化
/// 3. 自动同步本地数据到数据库
/// 4. 初始化媒体工具包
/// 5. 初始化音频服务
/// 6. 运行应用并配置状态管理
void main() async {
  // 针对桌面平台初始化窗口管理
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await initWindowManage();
  }
  
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化日志系统
  // await initLogs();
  
  // 自动同步本地数据到数据库
  await autoSyncLocalDataToDatabase();

  // 初始化媒体工具包，仅启用桌面平台
  JustAudioMediaKit.ensureInitialized(
    iOS: false,
    android: false,
    windows: true,
    linux: true,
    macOS: false,
  );
  
  // 初始化音频服务
  final playerService = await AudioService.init(
    // 构建音频播放器处理器
    builder: () => _playerHandler,
    // 音频服务配置
    config: const AudioServiceConfig(
      // Android 通知通道 ID
      androidNotificationChannelId: 'com.bbmusic.channel.audio',
      // Android 通知通道名称
      androidNotificationChannelName: 'Audio playback',
      // Android 通知持续显示
      androidNotificationOngoing: true,
      // Windows 系统媒体控制配置 - 快进间隔
      fastForwardInterval: Duration(seconds: 10),
      // Windows 系统媒体控制配置 - 快退间隔
      rewindInterval: Duration(seconds: 10),
    ),
  );
  
  // 运行应用
  runApp(
    // 多状态管理提供者
    MultiProvider(
      // 注册各种状态管理模型
      providers: [
        // 播放器模型
        ChangeNotifierProvider(create: (context) => PlayerModel()),
        // 开放歌单模型
        ChangeNotifierProvider(create: (context) => OpenMusicOrderModel()),
        // 歌单来源设置模型
        ChangeNotifierProvider(
            create: (context) => MusicOrderOriginSettingModel()),
        // 下载模型
        ChangeNotifierProvider(create: (context) => DownloadModel()),
      ],
      child: MaterialApp(
        // 应用标题
        title: '哔哔音乐',
        // 应用主题
        theme: theme,
        // 首页视图
        home: const HomeView(),
        // 导航观察者，用于 BotToast
        navigatorObservers: [BotToastNavigatorObserver()],
        // 应用构建器
        builder: (context, child) {
          // 初始化播放器模型
          Provider.of<PlayerModel>(context, listen: false).init(
            playerHandler: _playerHandler,
            playerService: playerService,
          );
          
          // 配置消息提示框的默认选项
          BotToast.defaultOption.text.duration = const Duration(seconds: 10);
          BotToast.defaultOption.text.textStyle = TextStyle(
            fontSize: 12,
            color: Theme.of(context).cardColor,
          );
          
          // 应用 BotToast 构建器
          child = botToastBuilder(context, child);
          
          // 延迟 1 秒检查应用版本更新
          Timer(const Duration(seconds: 1), () {
            updateAppVersion();
          });
          
          // 初始化歌单来源设置模型
          Provider.of<MusicOrderOriginSettingModel>(context, listen: false)
              .init();
          
          return child;
        },
      ),
    ),
  );
}
