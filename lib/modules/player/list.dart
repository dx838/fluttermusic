// 音乐列表项组件
import 'package:bbmusic/components/music_list_tile/music_list_tile.dart';
// 下载模块模型
import 'package:bbmusic/modules/download/model.dart';
// 歌单工具类
import 'package:bbmusic/modules/music_order/utils.dart';
// Flutter 核心库
import 'package:flutter/material.dart';
// 底部弹窗组件
import 'package:bbmusic/components/sheet/bottom_sheet.dart';
// 播放器模型
import 'package:bbmusic/modules/player/model.dart';
// 音乐来源类型定义
import 'package:bbmusic/origin_sdk/origin_types.dart';
// 状态管理库
import 'package:provider/provider.dart';

/// 播放列表组件
class PlayerList extends StatelessWidget {
  const PlayerList({super.key});
  
  @override
  Widget build(BuildContext context) {
    // 计算高度
    double height = MediaQuery.of(context).size.height - 45;
    double topHeight = 56;
    
    return Consumer<PlayerModel>(
      builder: (context, player, child) {
        return SizedBox(
          height: height,
          child: Flex(
            direction: Axis.vertical,
            children: [
              // 头部
              Container(
                height: topHeight,
                padding: const EdgeInsets.only(
                  left: 15,
                  right: 15,
                  top: 5,
                  bottom: 5,
                ),
                child: Row(
                  children: [
                    // 标题和歌曲数量
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            "播放列表",
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "${player.playerList.length}首歌曲",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).disabledColor,
                            ),
                          )
                        ],
                      ),
                    ),
                    // 清空列表按钮
                    Tooltip(
                      message: "清空列表",
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          Provider.of<PlayerModel>(context, listen: false)
                              .clearPlayerList();
                        },
                      ),
                    )
                  ],
                ),
              ),
              
              // 播放列表内容
              player.playerList.isEmpty
                  // 空列表提示
                  ? Container(
                      padding: const EdgeInsets.only(top: 100),
                      child: const Text("播放列表中暂时没有歌曲"),
                    )
                  // 歌曲列表
                  : SizedBox(
                      height: height - topHeight,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: player.playerList.length,
                        itemBuilder: (context, index) {
                          final item = player.playerList.toList()[index];
                          return MusicListTile(
                            item,
                            onMore: () {
                              // 显示操作菜单
                              showItemSheet(context, item);
                            },
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

/// 显示歌曲操作菜单
/// 
/// [context]: 上下文
/// [data]: 音乐项
void showItemSheet(BuildContext context, MusicItem data) {
  final playerModel = Provider.of<PlayerModel>(context, listen: false);
  final downloadModel = Provider.of<DownloadModel>(context, listen: false);
  
  // 打开底部弹窗
  openBottomSheet(context, [
    // 歌曲名称
    SheetItem(
      title: Text(
        data.name,
        style: TextStyle(
          color: Theme.of(context).hintColor,
          fontWeight: FontWeight.bold,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
    // 播放按钮
    SheetItem(
      title: const Text('播放'),
      onPressed: () {
        playerModel.play(music: data);
      },
    ),
    // 添加到歌单按钮
    SheetItem(
      title: const Text('添加到歌单'),
      onPressed: () {
        collectToMusicOrder(context, [data]);
      },
    ),
    // 从播放列表移除按钮
    SheetItem(
      title: const Text('在播放列表中移除'),
      onPressed: () {
        playerModel.removePlayerList([data]);
      },
    ),
    // 下载按钮
    SheetItem(
      title: const Text('下载'),
      onPressed: () {
        downloadModel.download([data]);
      },
    ),
  ]);
}
