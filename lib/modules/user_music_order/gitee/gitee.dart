import 'dart:convert';

import 'package:bbmusic/icons/icon.dart';
import 'package:bbmusic/modules/user_music_order/gitee/config_view.dart';
import 'package:bbmusic/modules/user_music_order/gitee/constants.dart';
import 'package:bbmusic/modules/user_music_order/gitee/types.dart';
import 'package:bbmusic/utils/logs.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:bbmusic/origin_sdk/origin_types.dart';
import 'package:uuid/uuid.dart';

import '../common.dart';

const uuid = Uuid();

class UserMusicOrderForGitee implements UserMusicOrderOrigin {
  final dio = Dio();

  @override
  String name = GiteeOriginConst.name;
  @override
  final String cname = GiteeOriginConst.cname;
  @override
  final IconData icon = BBIcons.github;

  Function? listenChange;
  String repoUrl = '';
  String branch = '';
  String token = '';
  String filepath = '';

  Uri get _path {
    RepoInfo r = RepoInfo.format(repoUrl);
    return Uri.parse(
      'https://gitee.com/api/v5/repos/${r.owner}/${r.repo}/contents/$filepath',
    );
  }

  Map<String, String> get _headers {
    final opt = {
      'Authorization': 'token $token',
      'Accept': 'application/json',
    };
    return opt;
  }

  _initFile() async {
    try {
      await dio.get(_path.toString(), queryParameters: {'ref': branch});
    } catch (e) {
      if (e is DioException) {
        if ((e).response?.statusCode == 404) {
          try {
            await _update([], '创建歌单文件', '');
          } catch (e) {
            logs.e("创建文件失败", error: e);
            BotToast.showText(text: "创建文件失败");
            return Future.error(e);
          }
        }
      }
      BotToast.showText(text: "初始化歌单文件失败");
      logs.e("初始化歌单文件失败", error: e);
      return Future.error(e);
    }
  }

  Future<GiteeFile> _loadData() async {
    Map<String, String> query = {'ref': branch};
    Response<dynamic>? response;
    try {
      response = await dio.get(_path.toString(), queryParameters: query);
      final res = GiteeFile.fromJson(response.data);
      return res;
    } catch (e) {
      final msg = '$cname歌单获取失败';
      logs.e(msg, error: e);
      BotToast.showText(text: msg);
      return Future.error(msg);
    }
  }

  @override
  Widget? configBuild({
    Map<String, dynamic>? value,
    required Function(Map<String, dynamic>) onChange,
  }) {
    return GiteeConfigView(value: value, onChange: onChange);
  }

  @override
  bool canUse() {
    return repoUrl.isNotEmpty &&
        token.isNotEmpty &&
        branch.isNotEmpty &&
        filepath.isNotEmpty;
  }

  @override
  Future<void> initConfig(config) async {
    repoUrl = config[GiteeOriginConst.configFieldRepoUrl] ?? '';
    token = config[GiteeOriginConst.configFieldToken] ?? '';
    branch = config[GiteeOriginConst.configFieldBranch] ?? '';
    filepath = config[GiteeOriginConst.configFieldFilepath] ?? '';
    dio.options.headers = _headers;
  }

  @override
  getList() async {
    if (!canUse()) {
      return [];
    }
    try {
      await _initFile();
      final res = await _loadData();
      return res.content;
    } catch (e) {
      return [];
    }
  }

  Future _update(List<MusicOrderItem> list, String message, String sha) async {
    final jsonStr = json.encode(list);
    final content = base64Encode(
      utf8.encode(jsonStr),
    );

    Map<String, dynamic> body = {
      'message': message,
      'content': content,
    };
    if (sha.isNotEmpty) {
      body['sha'] = sha;
    }
    if (branch.isNotEmpty) {
      body['branch'] = branch;
    }

    try {
      if (sha.isNotEmpty) {
        await dio.put(_path.toString(), data: body);
      } else {
        await dio.post(_path.toString(), data: body);
      }
    } catch (e) {
      return Future.error('编辑歌单失败');
    }
  }

  @override
  Future create(data) async {
    final res = await _loadData();
    final list = res.content;

    if (list.where((e) => e.name == data.name).isNotEmpty) {
      return Future.error('歌单已存在');
    }
    String id = uuid.v4();
    list.add(
      MusicOrderItem(
        id: id,
        name: data.name,
        cover: data.cover,
        desc: data.desc,
        author: data.author,
        musicList: data.musicList,
      ),
    );

    return _update(list, '创建歌单${data.name}($id)', res.sha);
  }

  @override
  Future update(data) async {
    final res = await _loadData();
    final list = res.content;
    final index = list.indexWhere((e) => e.id == data.id);
    final current = list[index];
    if (index < 0) {
      return Future.error('歌单不存在');
    }

    list[index] = MusicOrderItem(
      id: current.id,
      name: data.name,
      cover: data.cover,
      desc: data.desc,
      author: data.author,
      musicList: current.musicList,
    );

    return _update(list, '更新歌单${data.name}($data.id)', res.sha);
  }

  @override
  Future delete(data) async {
    final res = await _loadData();
    final list = res.content;
    final index = list.indexWhere((e) => e.id == data.id);
    if (index < 0) {
      return Future.error('歌单不存在');
    }
    list.removeAt(index);
    return _update(list, '删除歌单${data.name}($data.id)', res.sha);
  }

  @override
  getDetail(id) async {
    final list = await getList();
    final index = list.indexWhere((r) => r.id == id);
    if (index < 0) {
      return Future.error('歌单不存在');
    }
    return list[index];
  }

  @override
  appendMusic(id, musics) async {
    final res = await _loadData();
    final list = res.content;
    final index = list.indexWhere((e) => e.id == id);
    if (index < 0) {
      throw Exception('歌单不存在');
    }
    final current = list[index];
    List<String> mids = musics.map((e) => e.id).toList();
    current.musicList.removeWhere((m) => mids.contains(m.id));
    current.musicList.addAll(musics);

    list[index] = MusicOrderItem(
      id: current.id,
      name: current.name,
      cover: current.cover,
      desc: current.desc,
      author: current.author,
      musicList: current.musicList,
    );

    return _update(list, '为歌单${current.name}($current.id)添加歌曲', res.sha);
  }

  @override
  updateMusic(id, musics) async {
    final res = await _loadData();
    final list = res.content;
    final index = list.indexWhere((e) => e.id == id);
    if (index < 0) {
      throw Exception('歌单不存在');
    }
    final current = list[index];
    List<String> mids = musics.map((e) => e.id).toList();

    final newList = current.musicList.map((m) {
      if (mids.contains(m.id)) {
        final c = musics.firstWhere((e) => e.id == m.id);
        return MusicItem(
          name: c.name,
          cover: m.cover,
          id: m.id,
          duration: m.duration,
          author: m.author,
          origin: m.origin,
        );
      }
      return m;
    }).toList();

    list[index] = MusicOrderItem(
      id: current.id,
      name: current.name,
      cover: current.cover,
      desc: current.desc,
      author: current.author,
      musicList: newList,
    );

    return _update(list, '为歌单${current.name}($current.id)更新歌曲', res.sha);
  }

  @override
  deleteMusic(id, musics) async {
    final res = await _loadData();
    final list = res.content;
    final index = list.indexWhere((e) => e.id == id);
    if (index < 0) {
      throw Exception('歌单不存在');
    }
    final current = list[index];
    List<String> mids = musics.map((e) => e.id).toList();
    current.musicList.removeWhere((m) => mids.contains(m.id));

    list[index] = MusicOrderItem(
      id: current.id,
      name: current.name,
      cover: current.cover,
      desc: current.desc,
      author: current.author,
      musicList: current.musicList,
    );

    return _update(list, '为歌单${current.name}($current.id)删除歌曲', res.sha);
  }
}

class RepoInfo {
  final String owner;
  final String repo;

  const RepoInfo({required this.owner, required this.repo});

  factory RepoInfo.format(String url) {
    List<String> s = url.split('/');
    return RepoInfo(
      owner: s[3],
      repo: url.endsWith('.git') ? s[4].replaceAll('.git', '') : s[4],
    );
  }
}
