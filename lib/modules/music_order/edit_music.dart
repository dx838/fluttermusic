// 歌单来源设置模型
import 'package:bbmusic/modules/setting/music_order_origin/mode.dart';
// 消息提示库
import 'package:bot_toast/bot_toast.dart';
// Flutter 核心库
import 'package:flutter/material.dart';
// 用户歌单服务
import 'package:bbmusic/modules/user_music_order/common.dart';
// 音乐来源类型定义
import 'package:bbmusic/origin_sdk/origin_types.dart';
// 状态管理库
import 'package:provider/provider.dart';

/// 编辑歌单内的歌曲信息页面
class EditMusic extends StatefulWidget {
  /// 歌单 ID
  final String musicOrderId;
  /// 歌曲数据
  final MusicItem data;
  /// 用户歌单服务
  final UserMusicOrderOrigin service;
  /// 歌单源配置 ID
  final String originSettingId;
  /// 确认回调函数
  final Function(MusicItem music) onOk;

  /// 构造函数
  /// 
  /// [originSettingId]: 歌单源配置 ID
  /// [musicOrderId]: 歌单 ID
  /// [data]: 歌曲数据
  /// [service]: 用户歌单服务
  /// [onOk]: 确认回调函数
  const EditMusic({
    super.key,
    required this.originSettingId,
    required this.musicOrderId,
    required this.data,
    required this.service,
    required this.onOk,
  });

  @override
  State<EditMusic> createState() => _EditMusicState();
}

class _EditMusicState extends State<EditMusic> {
  /// 歌曲名称控制器
  final TextEditingController _nameController = TextEditingController();
  /// 歌曲作者控制器
  final TextEditingController _authorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 初始化输入框内容
    setState(() {
      _nameController.text = widget.data.name;
      _authorController.text = widget.data.author;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改歌曲'),
      ),
      body: Container(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // 歌曲名称输入框
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text("歌曲名称"),
              ),
            ),
            const SizedBox(height: 20),
            // 歌曲作者输入框
            TextField(
              controller: _authorController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text("歌曲作者"),
              ),
            ),
            const SizedBox(height: 40),
            // 确认按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  // 显示加载中
                  final cancel = BotToast.showLoading();
                  try {
                    // 创建更新后的歌曲对象
                    final music = MusicItem(
                      id: widget.data.id,
                      origin: widget.data.origin,
                      duration: widget.data.duration,
                      cover: widget.data.cover,
                      name: _nameController.text,
                      author: _authorController.text,
                    );
                    // 调用服务更新歌曲
                    await widget.service.updateMusic(
                      widget.musicOrderId,
                      [music],
                    );
                    // 重新加载歌单源数据
                    if (context.mounted) {
                      Provider.of<MusicOrderOriginSettingModel>(
                        context,
                        listen: false,
                      ).loadSignal(widget.originSettingId);
                      // 关闭页面
                      Navigator.of(context).pop();
                    }
                    // 调用回调函数
                    widget.onOk(music);
                  } catch (e) {
                    // 显示错误提示
                    BotToast.showText(text: "歌曲更新失败");
                  }
                  // 关闭加载中
                  cancel();
                },
                child: const Text('确 认'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
