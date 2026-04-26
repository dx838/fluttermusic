import 'package:bbmusic/modules/user_music_order/common.dart';
import 'package:bbmusic/modules/user_music_order/github/constants.dart';
import 'package:bbmusic/modules/user_music_order/github/github.dart';
import 'package:bbmusic/modules/user_music_order/gitee/constants.dart';
import 'package:bbmusic/modules/user_music_order/gitee/gitee.dart';
import 'package:bbmusic/modules/user_music_order/webdav/constants.dart';
import 'package:bbmusic/modules/user_music_order/webdav/webdav.dart';
import 'package:bbmusic/modules/user_music_order/local/constants.dart';
import 'package:bbmusic/modules/user_music_order/local/local.dart';

/// 用户歌单源映射
/// 
/// 定义了所有支持的用户歌单源，将歌单源名称映射到对应的实现类
/// 
/// 支持的歌单源：
/// - LocalOriginConst.name: 本地歌单源，使用 UserMusicOrderForLocal 实现
/// - GithubOriginConst.name: GitHub 歌单源，使用 UserMusicOrderForGithub 实现
/// - GiteeOriginConst.name: Gitee 歌单源，使用 UserMusicOrderForGitee 实现
/// - WebDAVOriginConst.name: WebDAV 歌单源，使用 UserMusicOrderForWebDAV 实现
/// 
/// 每个歌单源实现了 UserMusicOrderOrigin 接口，提供歌单的增删改查等操作
final Map<String, UserMusicOrderOrigin Function()> userMusicOrderOrigin = {
  LocalOriginConst.name: () => UserMusicOrderForLocal(),
  GithubOriginConst.name: () => UserMusicOrderForGithub(),
  GiteeOriginConst.name: () => UserMusicOrderForGitee(),
  WebDAVOriginConst.name: () => UserMusicOrderForWebDAV(),
};
