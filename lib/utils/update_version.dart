import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 检查应用更新
/// 
/// 从 GitHub 获取最新版本信息，并与当前应用版本进行对比
/// 如果发现新版本，显示更新提示对话框
/// 
/// 实现步骤：
/// 1. 创建 Dio 实例
/// 2. 调用 GitHub API 获取最新发布版本
/// 3. 解析最新版本号（去除 v 前缀）
/// 4. 获取当前应用版本
/// 5. 对比版本号
/// 6. 如果有更新，显示更新提示对话框
/// 7. 处理异常情况
Future<void> updateAppVersion() async {
  final dio = Dio();
  try {
    final resp = await dio.get(
      "https://api.github.com/repos/bb-music/flutter-app/releases/latest",
      options: Options(headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28'
      }),
    );
    String latestVersion = resp.data['tag_name'];
    latestVersion = latestVersion.replaceFirst('v', '');
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;
    // 版本号对比
    if (isUpdateVersion(latestVersion, currentVersion)) {
      BotToast.showCustomLoading(
        toastBuilder: (cancelFunc) {
          return AlertDialog(
            title: const Text('发现新版本，是否更新？'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            actions: [
              TextButton(
                onPressed: () {
                  cancelFunc();
                },
                child: const Text("取消"),
              ),
              TextButton(
                onPressed: () {
                  cancelFunc();
                  // 打开网址
                  launchUrl(
                    Uri.parse(
                      "https://github.com/bb-music/flutter-app/releases/latest",
                    ),
                  );
                },
                child: const Text("确定"),
              )
            ],
          );
        },
      );
    }
  } catch (e) {
    if (e is DioException) {
      print(e.message);
    }
  }
}

/// 对比版本号，判断是否需要更新
/// 
/// [newVersion]: 新版本号
/// [old]: 当前版本号
/// 
/// 返回值：是否需要更新
/// 
/// 版本号对比逻辑：
/// 1. 检查版本号是否为空
/// 2. 按点分割版本号
/// 3. 逐位比较版本号数字
/// 4. 如果新版本某一位数字大于当前版本，则需要更新
/// 5. 如果所有位都相等，则不需要更新
bool isUpdateVersion(String newVersion, String old) {
  if (newVersion.isEmpty || old.isEmpty) {
    return false;
  }
  int newVersionInt, oldVersion;
  var newList = newVersion.split('.');
  var oldList = old.split('.');
  if (newList.isEmpty || oldList.isEmpty) {
    return false;
  }
  for (int i = 0; i < newList.length; i++) {
    newVersionInt = int.parse(newList[i]);
    oldVersion = int.parse(oldList[i]);
    if (newVersionInt > oldVersion) {
      return true;
    } else if (newVersionInt < oldVersion) {
      return false;
    }
  }
  return false;
}
