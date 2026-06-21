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

/// 编辑/创建歌单页面
class EditMusicOrder extends StatefulWidget {
  /// 歌单数据，为null时表示创建新歌单
  final MusicOrderItem? data;
  /// 用户歌单服务
  final UserMusicOrderOrigin service;
  /// 歌单源配置 ID
  String? originSettingId;

  /// 构造函数
  /// 
  /// [data]: 歌单数据，为null时表示创建新歌单
  /// [originSettingId]: 歌单源配置 ID
  /// [service]: 用户歌单服务
  EditMusicOrder({
    super.key,
    this.data,
    this.originSettingId,
    required this.service,
  });

  @override
  State<EditMusicOrder> createState() => _EditMusicOrderState();
}

class _EditMusicOrderState extends State<EditMusicOrder> {
  /// 歌单名称控制器
  final TextEditingController _nameController = TextEditingController();
  /// 歌单封面控制器
  final TextEditingController _coverController = TextEditingController();
  /// 歌单描述控制器
  final TextEditingController _descController = TextEditingController();

  /// 是否为创建模式
  bool get _isCreate => (widget.data?.id == "" || widget.data == null);

  @override
  void initState() {
    super.initState();
    // 初始化输入框内容
    setState(() {
      _nameController.text = widget.data?.name ?? '';
      _descController.text = widget.data?.desc ?? '';
      _coverController.text = widget.data?.cover ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 根据是否为创建模式显示不同的标题
        title: _isCreate ? const Text('创建歌单') : const Text('修改歌单'),
      ),
      body: Container(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // 歌单封面输入框
            TextField(
              controller: _coverController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text("歌单封面"),
              ),
            ),
            const SizedBox(height: 20),
            // 歌单名称输入框
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text("歌单名称"),
              ),
            ),
            const SizedBox(height: 20),
            // 歌单描述输入框
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text("歌单描述"),
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
                    if (_isCreate) {
                      // 创建新歌单
                      final music = MusicOrderItem(
                        id: '',
                        author: '',
                        name: _nameController.text,
                        desc: _descController.text,
                        cover: _coverController.text,
                        musicList: [],
                      );
                      await widget.service.create(music);
                    } else {
                      // 更新歌单
                      final music = MusicOrderItem(
                        id: widget.data!.id,
                        name: _nameController.text,
                        desc: _descController.text,
                        cover: _coverController.text,
                        author: widget.data!.author,
                        musicList: widget.data!.musicList,
                      );
                      await widget.service.update(music);
                    }
                    // 重新加载歌单源数据
                    if (context.mounted) {
                      if (widget.originSettingId != null) {
                        Provider.of<MusicOrderOriginSettingModel>(
                          context,
                          listen: false,
                        ).loadSignal(widget.originSettingId!);
                      }
                      // 关闭页面
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    // 显示错误提示
                    BotToast.showText(
                      text: "${_isCreate ? "创建" : "更新"}失败 ${e.toString()}",
                    );
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
