import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 初始化窗口管理
/// 
/// 配置应用窗口的大小、标题、图标等属性
/// 
/// 实现步骤：
/// 1. 确保 Flutter 绑定初始化
/// 2. 初始化窗口管理器
/// 3. 设置窗口选项（大小、最小尺寸、标题、标题栏样式）
/// 4. 设置窗口不可最大化
/// 5. 在 Windows 平台设置应用图标
/// 6. 等待窗口准备就绪后显示并聚焦
/// 
/// 窗口配置：
/// - 大小：460x900
/// - 最小大小：400x700
/// - 标题：哔哔音乐
/// - 标题栏样式：normal
Future<void> initWindowManage() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(460, 900),
    minimumSize: Size(400, 700),
    // center: true,
    title: "哔哔音乐",
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.setMaximizable(false);
  if (Platform.isWindows) {
    windowManager.setIcon("assets/ic_launch.png");
  }
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
