// 音乐列表项组件
import 'package:bbmusic/components/music_list_tile/music_list_tile.dart';
// 下载模块模型
import 'package:bbmusic/modules/download/model.dart';
// 编辑音乐页面
import 'package:bbmusic/modules/music_order/edit_music.dart';
// 歌单工具类
import 'package:bbmusic/modules/music_order/utils.dart';
// 歌单来源设置模型
import 'package:bbmusic/modules/setting/music_order_origin/mode.dart';
// 消息提示库
import 'package:bot_toast/bot_toast.dart';
// Flutter 核心库
import 'package:flutter/material.dart';
// 底部弹窗组件
import 'package:bbmusic/components/sheet/bottom_sheet.dart';
// 播放器组件
import 'package:bbmusic/modules/player/player.dart';
// 播放器模型
import 'package:bbmusic/modules/player/model.dart';
// 用户歌单服务
import 'package:bbmusic/modules/user_music_order/common.dart';
// 音乐来源类型定义
import 'package:bbmusic/origin_sdk/origin_types.dart';
// 工具类 - 清除HTML标签
import 'package:bbmusic/utils/clear_html_tags.dart';
// 状态管理库
import 'package:provider/provider.dart';

/// 歌单详情页面
class MusicOrderDetail extends StatefulWidget {
  /// 歌单数据
  final MusicOrderItem data;
  /// 歌单源配置 ID
  String? originSettingId;
  /// 用户歌单服务
  final UserMusicOrderOrigin? umoService;

  /// 构造函数
  /// 
  /// [umoService]: 用户歌单服务
  /// [originSettingId]: 歌单源配置 ID
  /// [data]: 歌单数据
  MusicOrderDetail(
      {super.key, this.umoService, this.originSettingId, required this.data});

  @override
  _MusicOrderDetailState createState() => _MusicOrderDetailState();
}

class _MusicOrderDetailState extends State<MusicOrderDetail> {
  /// 歌单数据
  late MusicOrderItem musicOrder;

  @override
  initState() {
    super.initState();
    // 初始化歌单数据
    musicOrder = widget.data;
  }

  /// 编辑歌曲处理方法
  /// 
  /// [data]: 要编辑的歌曲
  _formItemHandler(MusicItem data) {
    // 检查是否有歌单服务
    if (widget.umoService == null) {
      return;
    }
    // 检查歌单服务是否可用
    if (!widget.umoService!.canUse()) {
      BotToast.showSimpleNotification(
        title: "歌单源目前无法使用,请先完善配置",
      );
      return;
    }
    // 跳转到编辑音乐页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          if (widget.umoService == null || widget.originSettingId == null) {
            BotToast.showText(text: "缺少歌单配置参数");
            return const SizedBox();
          }
          return EditMusic(
            musicOrderId: widget.data.id,
            originSettingId: widget.originSettingId!,
            service: widget.umoService!,
            data: data,
            onOk: (music) {
              // 更新歌单中的歌曲信息
              setState(() {
                final ind = musicOrder.musicList
                    .indexWhere((item) => item.id == data.id);
                if (ind != -1) {
                  musicOrder.musicList[ind] = music;
                }
              });
            },
          );
        },
      ),
    );
  }

  /// 歌曲更多操作处理方法
  /// 
  /// [context]: 上下文
  /// [item]: 歌曲数据
  _moreHandler(BuildContext context, MusicItem item) {
    openBottomSheet(context, [
      // 歌曲名称
      SheetItem(
        title: Text(
          item.name,
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
          Provider.of<PlayerModel>(context, listen: false).play(music: item);
        },
      ),
      // 添加到歌单按钮
      SheetItem(
        title: const Text('添加到歌单'),
        onPressed: () {
          collectToMusicOrder(context, [item], musicOrder: musicOrder);
        },
      ),
      // 编辑按钮
      SheetItem(
        title: const Text('编辑'),
        onPressed: () {
          _formItemHandler(item);
        },
        hidden: widget.umoService == null,
      ),
      // 从歌单中移除按钮
      SheetItem(
        title: const Text('从歌单中移除'),
        onPressed: () async {
          // 调用歌单服务删除歌曲
          await widget.umoService!.deleteMusic(musicOrder.id, [item]);
          // 更新本地歌单数据
          setState(() {
            musicOrder.musicList.remove(item);
          });

          // 重新加载歌单源数据
          if (context.mounted && widget.originSettingId != null) {
            Provider.of<MusicOrderOriginSettingModel>(context, listen: false)
                .loadSignal(widget.originSettingId!);
          }
        },
        hidden: widget.umoService == null,
      ),
      // 添加到播放列表按钮
      SheetItem(
        title: const Text('添加到播放列表'),
        onPressed: () {
          Provider.of<PlayerModel>(context, listen: false)
              .addPlayerList([item]);
        },
      ),
      // 下载按钮
      SheetItem(
        title: const Text('下载'),
        onPressed: () {
          Provider.of<DownloadModel>(context, listen: false).download([item]);
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 显示歌单名称
        title: Text(musicOrder.name),
        actions: [
          // 更多操作按钮
          IconButton(
            icon: const Icon(Icons.more_vert_outlined),
            tooltip: '更多操作',
            onPressed: () {
              final player = Provider.of<PlayerModel>(context, listen: false);
              openBottomSheet(context, [
                // 播放全部按钮
                SheetItem(
                  title: const Text('播放全部'),
                  onPressed: () {
                    // 清空播放列表并添加当前歌单所有歌曲
                    player.clearPlayerList();
                    player.addPlayerList(musicOrder.musicList);
                    // 播放第一首歌曲
                    player.play(music: musicOrder.musicList[0]);
                  },
                ),
                // 追加到播放列表按钮
                SheetItem(
                  title: const Text('追加到播放列表'),
                  onPressed: () {
                    player.addPlayerList(musicOrder.musicList);
                  },
                ),
                // 加入歌单按钮
                SheetItem(
                  title: const Text('加入歌单'),
                  // hidden: widget.umoService != null,
                  onPressed: () {
                    collectToMusicOrder(
                      context,
                      musicOrder.musicList,
                      musicOrder: musicOrder,
                    );
                  },
                ),
                // SheetItem(
                //   title: const Text('下载全部'),
                //   onPressed: () {
                //     Provider.of<DownloadModel>(context, listen: false)
                //         .download(musicOrder.musicList);
                //   },
                // )
              ]);
            },
          )
        ],
      ),
      // 播放器组件
      floatingActionButton: const PlayerView(),
      // 歌曲列表
      body: ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: musicOrder.musicList.length,
          itemBuilder: (context, index) {
            if (musicOrder.musicList.isEmpty) return null;
            final item = musicOrder.musicList[index];
            final List<String> tags = [
              item.origin.name,
              seconds2duration(item.duration),
            ];
            return MusicListTile(
              item,
              onMore: () {
                _moreHandler(context, item);
              },
            );
          }),
    );
  }
}
