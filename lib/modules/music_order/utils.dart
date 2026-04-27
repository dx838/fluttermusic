import 'package:bbmusic/modules/music_order/list.dart';
import 'package:bbmusic/modules/setting/music_order_origin/mode.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:bbmusic/origin_sdk/origin_types.dart';
import 'package:provider/provider.dart';

/// 收藏歌曲到歌单
/// 
/// 该函数打开一个底部弹窗，显示用户的歌单列表，用户可以选择将歌曲添加到指定歌单
/// 
/// [context]: 上下文
/// [musics]: 要添加的歌曲列表
/// [musicOrder]: 可选参数，歌单数据
/// 
/// 实现原理：
/// 1. 显示底部弹窗，展示所有可用的歌单源和歌单
/// 2. 当用户选择歌单时，调用对应歌单源的 appendMusic 方法添加歌曲
/// 3. 添加完成后显示成功提示，并刷新歌单数据
/// 4. 处理添加失败的情况，显示错误提示
void collectToMusicOrder(
  BuildContext context,
  List<MusicItem> musics, {
  MusicOrderItem? musicOrder,
}) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height - 80,
    ),
    builder: (ctx) {
      return UserMusicOrderList(
        musicOrder: MusicOrderItem(
          author: "",
          id: "",
          name: musicOrder?.name ?? "",
          desc: musicOrder?.desc ?? "",
          cover: musicOrder?.cover ?? "",
          musicList: musicOrder?.musicList ?? [],
        ),
        collectModalStyle: true,
        onItemTap: (UserMusicOrderOriginItem umo, MusicOrderItem data) async {
          final cancel = BotToast.showLoading();
          try {
            // 调用歌单源服务的 appendMusic 方法添加歌曲
            await umo.service.appendMusic(data.id, musics);
            if (context.mounted) {
              BotToast.showText(text: '添加成功');
              // 刷新歌单数据
              Provider.of<MusicOrderOriginSettingModel>(context, listen: false)
                  .loadSignal(umo.id);
              Navigator.of(context).pop();
            }
          } catch (e) {
            BotToast.showText(
              text: '添加失败 $e',
              duration: const Duration(seconds: 5),
            );
            rethrow;
          } finally {
            cancel();
          }
        },
      );
    },
  );
}
