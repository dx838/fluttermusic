// 消息提示库
import 'package:bot_toast/bot_toast.dart';
// Flutter 核心库
import 'package:flutter/material.dart';
// 播放器卡片组件
import 'package:bbmusic/modules/player/card.dart';
// 播放列表组件
import 'package:bbmusic/modules/player/list.dart';
// 播放器模型
import 'package:bbmusic/modules/player/model.dart';
// 状态管理库
import 'package:provider/provider.dart';

/// 播放器视图组件
/// 
/// 显示在底部的播放器控制条，点击可展开为完整播放器
class PlayerView extends StatelessWidget {
  const PlayerView({super.key});
  
  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;
    
    return GestureDetector(
      // 点击展开播放器卡片
      onTap: () {
        showPlayerCard(context);
      },
      child: Container(
        height: 70,
        width: MediaQuery.of(context).size.width - 30,
        padding: const EdgeInsets.only(left: 15, right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).secondaryHeaderColor,
          border: Border.all(color: primaryColor, width: .5),
        ),
        child: const Flex(
          direction: Axis.horizontal,
          children: [
            // 歌曲信息
            PlayInfo(),
            // 控制按钮
            Row(children: [
              PlayButton(),
              NextButton(),
              PlayerListButton(),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 音乐信息组件
/// 
/// 显示当前播放歌曲的名称
class PlayInfo extends StatelessWidget {
  const PlayInfo({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerModel>(
      builder: (context, player, child) {
        // 获取当前歌曲名称，默认为"暂无歌曲"
        String name = player.current?.name ?? '暂无歌曲';

        return Expanded(
          flex: 1,
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

/// 播放/暂停按钮组件
class PlayButton extends StatelessWidget {
  /// 按钮大小
  final double? size;

  const PlayButton({super.key, this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Consumer<PlayerModel>(
      builder: (context, player, child) {
        // 根据播放状态显示不同的图标
        if (player.isPlaying) {
          // 播放中显示暂停按钮
          return IconButton(
            color: primaryColor,
            iconSize: size,
            icon: const Icon(
              Icons.pause_circle_filled,
            ),
            onPressed: () {
              player.pause();
            },
          );
        }
        // 暂停中显示播放按钮
        return IconButton(
          color: primaryColor,
          iconSize: size,
          icon: const Icon(
            Icons.play_circle_filled,
          ),
          onPressed: () {
            player.play();
          },
        );
      },
    );
  }
}

/// 上一首按钮组件
class PrevButton extends StatelessWidget {
  /// 按钮大小
  final double? size;

  const PrevButton({super.key, this.size = 30.0});

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Consumer<PlayerModel>(
      builder: (context, player, child) {
        return IconButton(
          color: primaryColor,
          onPressed: () {
            player.prev();
          },
          iconSize: size,
          icon: const Icon(
            Icons.skip_previous,
          ),
        );
      },
    );
  }
}

/// 下一首按钮组件
class NextButton extends StatelessWidget {
  /// 按钮大小
  final double? size;

  const NextButton({super.key, this.size = 30.0});

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Consumer<PlayerModel>(
      builder: (context, player, child) {
        return IconButton(
          color: primaryColor,
          iconSize: size,
          onPressed: () {
            player.next();
          },
          icon: const Icon(
            Icons.skip_next,
          ),
        );
      },
    );
  }
}

/// 播放列表按钮组件
class PlayerListButton extends StatelessWidget {
  /// 按钮大小
  final double? size;

  const PlayerListButton({super.key, this.size = 30.0});

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Consumer<PlayerModel>(
      builder: (context, player, child) {
        return IconButton(
          color: primaryColor,
          iconSize: size,
          onPressed: () {
            showPlayerList(context);
          },
          icon: const Icon(
            Icons.queue_music,
          ),
        );
      },
    );
  }
}

/// 播放模式按钮组件
class ModeButton extends StatelessWidget {
  /// 按钮大小
  final double? size;

  const ModeButton({super.key, this.size = 30.0});

  @override
  Widget build(BuildContext context) {
    Color primaryColor = Theme.of(context).primaryColor;

    return Consumer<PlayerModel>(
      builder: (context, player, child) {
        return IconButton(
          color: primaryColor,
          iconSize: size,
          onPressed: () {
            // 切换播放模式
            player.togglePlayerMode();
            // 显示当前播放模式
            BotToast.showText(text: "${player.playerMode.name}模式");
            // Fluttertoast.showToast(
            //   msg: "${player.playerMode.name}模式",
            //   // toastLength: Toast.LENGTH_SHORT,
            //   // timeInSecForIosWeb: 1,
            //   // backgroundColor: Colors.red,
            //   // textColor: Colors.white,
            //   fontSize: 16.0,
            // );
          },
          icon: Icon(
            player.playerMode.icon,
          ),
        );
      },
    );
  }
}

/// 显示播放列表
/// 
/// [context]: 上下文
/// 
/// 返回值：Future对象
Future showPlayerList(BuildContext context) {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: false);
  return navigator.push(ModalBottomSheetRoute(
    isScrollControlled: true,
    builder: (context) {
      return const PlayerList();
    },
  ));
}

/// 显示播放卡片
/// 
/// [context]: 上下文
/// 
/// 返回值：Future<void>?对象，若没有当前歌曲则返回null
Future<void>? showPlayerCard(BuildContext context) {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: false);
  final player = Provider.of<PlayerModel>(context, listen: false);
  // 如果没有当前歌曲，不显示播放卡片
  if (player.current == null) return null;
  return navigator.push(ModalBottomSheetRoute(
    isScrollControlled: true,
    builder: (context) {
      return const PlayerCard();
    },
  ));
}
