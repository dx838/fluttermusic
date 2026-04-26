import 'dart:async';

// 下载模块模型
import 'package:bbmusic/modules/download/model.dart';
// 消息提示库
import 'package:bot_toast/bot_toast.dart';
// 网络图片缓存库
import 'package:cached_network_image/cached_network_image.dart';
// Flutter 核心库
import 'package:flutter/material.dart';
// 播放器组件
import 'package:bbmusic/modules/player/player.dart';
// 播放器模型
import 'package:bbmusic/modules/player/model.dart';
// 工具类 - 清除HTML标签
import 'package:bbmusic/utils/clear_html_tags.dart';
// 状态管理库
import 'package:provider/provider.dart';

/// 播放器卡片组件
/// 
/// 显示当前播放歌曲的信息和控制按钮
class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key});
  
  @override
  Widget build(BuildContext context) {
    // 封面宽度
    double coverWidth = 160;
    
    return Consumer<PlayerModel>(
      builder: (context, player, child) {
        return Container(
          height: 460,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // 歌曲名称
              Container(
                padding: const EdgeInsets.only(
                  top: 20,
                  left: 30,
                  right: 30,
                  bottom: 20,
                ),
                child: Text(
                  player.current!.name,
                  style: const TextStyle(
                    fontSize: 18,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              
              // 封面图片
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: player.current?.cover != ""
                    ? CachedNetworkImage(
                        imageUrl: player.current!.cover,
                        width: coverWidth,
                        height: coverWidth,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: const Color.fromARGB(255, 227, 226, 226),
                        width: coverWidth,
                        height: coverWidth,
                        child: Center(
                          child: Text(
                            player.current!.name,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
              ),
              
              const SizedBox(height: 10),
              
              // 下载和定时播放按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 下载按钮
                  Tooltip(
                    message: "下载",
                    child: IconButton(
                      iconSize: 30,
                      onPressed: () {
                        // 调用下载功能
                        Provider.of<DownloadModel>(context, listen: false)
                            .download([player.current!]);
                      },
                      icon: const Icon(Icons.download),
                    ),
                  ),
                  
                  // 定时关闭按钮
                  Tooltip(
                    message: "定时关闭",
                    child: IconButton(
                      iconSize: 30,
                      onPressed: () {
                        // 打开定时关闭面板
                        autoClose(context);
                      },
                      icon: const Icon(Icons.alarm),
                    ),
                  )
                ],
              ),
              
              // 播放进度条
              const PlayerProgress(),
              // 播放模式、上一首，下一首，播放，列表
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 播放模式按钮
                  ModeButton(size: 30),
                  // 上一首按钮
                  PrevButton(size: 40),
                  // 播放/暂停按钮
                  PlayButton(size: 60),
                  // 下一首按钮
                  NextButton(size: 40),
                  // 播放列表按钮
                  PlayerListButton(size: 30),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

/// 播放器进度条组件
class PlayerProgress extends StatefulWidget {
  const PlayerProgress({
    super.key,
  });

  @override
  State<PlayerProgress> createState() => _PlayerProgressState();
}

class _PlayerProgressState extends State<PlayerProgress> {
  /// 进度值 (0.0 - 1.0)
  double _value = 0;
  /// 是否正在拖动进度条
  bool _isChanged = false;
  /// 订阅列表
  List<StreamSubscription<Duration>?> listens = [];

  @override
  void initState() {
    final player = Provider.of<PlayerModel>(context, listen: false);
    super.initState();

    // 监听播放进度
    listens.add(player.listenPosition((event) {
      // 如果正在拖动或组件已卸载，不更新进度
      if (_isChanged || !mounted) return;
      
      // 计算进度值
      double c = event.inSeconds.toDouble();
      double total = player.duration?.inSeconds.toDouble() ?? 0.0;
      double v = c / total;
      
      // 处理边界情况
      if (v.isNaN) return;
      if (v > 1.0) {
        v = 1.0;
      }
      if (v < 0.0) {
        v = 0;
      }
      
      // 更新状态
      setState(() {
        _value = v;
      });
    }));
  }

  @override
  void dispose() {
    // 取消所有订阅
    for (final listen in listens) {
      listen?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerModel>(builder: (context, player, child) {
      // 总时长（秒）
      int total = (player.duration?.inSeconds ?? 0);
      
      return Column(
        children: [
          // 进度滑块
          Slider(
            value: _value,
            onChanged: (v) {
              // 拖动时更新进度值
              setState(() {
                _value = v;
              });
            },
            onChangeStart: (value) {
              // 开始拖动
              setState(() {
                _isChanged = true;
              });
            },
            onChangeEnd: (value) {
              // 结束拖动，设置播放位置
              final player = Provider.of<PlayerModel>(context, listen: false);
              int v = (value * total).toInt();
              player.seek(Duration(seconds: v));
              setState(() {
                _isChanged = false;
              });
            },
          ),
          
          // 时间显示
          Container(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 当前播放时间
                Text(
                  seconds2duration((_value * total).toInt()),
                ),
                // 总时长
                Text(seconds2duration(total)),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// 自动关闭项
class AutoCloseItem {
  /// 标签
  final String label;
  /// 时长
  final Duration value;

  /// 构造函数
  AutoCloseItem({required this.label, required this.value});
}

/// 自动关闭选项列表
final List<AutoCloseItem> AutoCloseList = [
  AutoCloseItem(label: "1 分钟", value: const Duration(minutes: 1)),
  AutoCloseItem(label: "5 分钟", value: const Duration(minutes: 5)),
  AutoCloseItem(label: "10 分钟", value: const Duration(minutes: 10)),
  AutoCloseItem(label: "15 分钟", value: const Duration(minutes: 15)),
  AutoCloseItem(label: "30 分钟", value: const Duration(minutes: 30)),
  AutoCloseItem(label: "60 分钟", value: const Duration(minutes: 60)),
];

// 定时关闭
autoClose(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      return SafeArea(
        bottom: true,
        child: Container(
          color: Theme.of(context).cardTheme.color,
          padding: const EdgeInsets.all(10),
          height: 200,
          width: double.infinity,
          child: Column(
            children: [
              // 时间选项
              Wrap(
                spacing: 10,
                runSpacing: 18,
                children: AutoCloseList.map((item) {
                  return OutlinedButton(
                    child: SizedBox(
                      width: 60,
                      child: Center(
                        child: Text(item.label),
                      ),
                    ),
                    onPressed: () {
                      // 关闭面板
                      Navigator.of(context).pop();
                      // 显示提示
                      BotToast.showText(text: "${item.label}后自动关闭");
                      // 设置自动关闭
                      Provider.of<PlayerModel>(context, listen: false)
                          .autoCloseHandler(item.value);
                    },
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // 播放完成后关闭选项
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Consumer<PlayerModel>(builder: (context, player, child) {
                    return Checkbox(
                      value: player.playDoneAutoClose,
                      onChanged: (e) {
                        // 切换播放完成后关闭状态
                        player.togglePlayDoneAutoClose();
                      },
                    );
                  }),
                  const Text("当前歌曲播放完成后再关闭"),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
