import 'package:bbmusic/components/text_tags/tags.dart';
import 'package:bbmusic/modules/player/model.dart';
import 'package:bbmusic/origin_sdk/origin_types.dart';
import 'package:bbmusic/utils/clear_html_tags.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 音乐列表项组件
/// 
/// 显示音乐列表中的单个歌曲项，包含歌曲名称、标签、播放状态和更多操作
class MusicListTile extends StatelessWidget {
  /// 歌曲数据
  final MusicItem music;
  
  /// 更多操作回调函数
  final void Function() onMore;

  /// 构造函数
  /// 
  /// [music]: 歌曲数据
  /// [key]: 组件key
  /// [onMore]: 更多操作回调函数
  const MusicListTile(this.music, {super.key, required this.onMore});

  @override
  Widget build(BuildContext context) {
    // 生成标签列表：来源和时长
    final List<String> tags = [
      music.origin.name,
      seconds2duration(music.duration),
    ];
    
    return Consumer<PlayerModel>(builder: (context, player, child) {
      // 判断当前歌曲是否正在播放
      final isPlaying = 
          (player.current != null && player.current!.id == music.id);
      
      // 根据播放状态显示不同的图标
      final playingIcon = isPlaying
          ? Icon(
              player.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 18,
              color: Theme.of(context).primaryColor,
            )
          : null;
      
      return ListTile(
        // 歌曲名称
        title: Text(
          music.name,
          style: TextStyle(
            overflow: TextOverflow.ellipsis,
            color: isPlaying ? Theme.of(context).primaryColor : null,
          ),
        ),
        // 播放状态图标
        leading: playingIcon,
        // 标签（来源和时长）
        subtitle: TextTags(tags: tags),
        // 更多操作按钮
        trailing: InkWell(
          borderRadius: BorderRadius.circular(4.0),
          onTap: onMore,
          child: const Icon(Icons.more_vert),
        ),
        // 点击播放歌曲
        onTap: () {
          Provider.of<PlayerModel>(context, listen: false).play(music: music);
        },
        // 长按触发更多操作
        onLongPress: onMore,
      );
    });
  }
}
