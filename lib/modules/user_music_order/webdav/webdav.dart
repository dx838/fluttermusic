import 'dart:convert';

import 'package:bbmusic/modules/user_music_order/webdav/config_view.dart';
import 'package:bbmusic/modules/user_music_order/webdav/constants.dart';
import 'package:bbmusic/utils/logs.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:bbmusic/origin_sdk/origin_types.dart';
import 'package:uuid/uuid.dart';

import '../common.dart';

const uuid = Uuid();

class UserMusicOrderForWebDAV implements UserMusicOrderOrigin {
  final dio = Dio();

  @override
  String name = WebDAVOriginConst.name;
  @override
  final String cname = WebDAVOriginConst.cname;
  @override
  final IconData icon = Icons.cloud;

  String url = '';
  String username = '';
  String password = '';
  String filepath = '';

  String get _fullPath {
    final baseUrl = url.endsWith('/') ? url : '$url/';
    return '$baseUrl${filepath.startsWith('/') ? filepath.substring(1) : filepath}';
  }

  _initFile() async {
    try {
      await dio.get(_fullPath);
    } catch (e) {
      if (e is DioException) {
        if ((e).response?.statusCode == 404) {
          try {
            await _update([]);
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

  Future<List<MusicOrderItem>> _loadData() async {
    Response<dynamic>? response;
    try {
      response = await dio.get(_fullPath);
      final data = response.data;
      List<MusicOrderItem> list = [];
      if (data is List) {
        for (var item in data) {
          list.add(MusicOrderItem.fromJson(item));
        }
      } else if (data is String) {
        final parsedJson = json.decode(data);
        if (parsedJson is List) {
          for (var item in parsedJson) {
            list.add(MusicOrderItem.fromJson(item));
          }
        }
      }
      return list;
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
    return WebDAVConfigView(value: value, onChange: onChange);
  }

  @override
  bool canUse() {
    return url.isNotEmpty && filepath.isNotEmpty;
  }

  @override
  Future<void> initConfig(config) async {
    url = config[WebDAVOriginConst.configFieldUrl] ?? '';
    username = config[WebDAVOriginConst.configFieldUsername] ?? '';
    password = config[WebDAVOriginConst.configFieldPassword] ?? '';
    filepath = config[WebDAVOriginConst.configFieldFilepath] ?? '';

    if (username.isNotEmpty && password.isNotEmpty) {
      final auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      dio.options.headers['Authorization'] = auth;
    }
  }

  @override
  getList() async {
    if (!canUse()) {
      return [];
    }
    try {
      await _initFile();
      return await _loadData();
    } catch (e) {
      return [];
    }
  }

  Future _update(List<MusicOrderItem> list) async {
    final jsonStr = json.encode(list);
    try {
      await dio.put(
        _fullPath,
        data: jsonStr,
        options: Options(contentType: 'application/json'),
      );
    } catch (e) {
      return Future.error('编辑歌单失败');
    }
  }

  @override
  Future create(data) async {
    final list = await _loadData();

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

    return _update(list);
  }

  @override
  Future update(data) async {
    final list = await _loadData();
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

    return _update(list);
  }

  @override
  Future delete(data) async {
    final list = await _loadData();
    final index = list.indexWhere((e) => e.id == data.id);
    if (index < 0) {
      return Future.error('歌单不存在');
    }
    list.removeAt(index);
    return _update(list);
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
    final list = await _loadData();
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

    return _update(list);
  }

  @override
  updateMusic(id, musics) async {
    final list = await _loadData();
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

    return _update(list);
  }

  @override
  deleteMusic(id, musics) async {
    final list = await _loadData();
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

    return _update(list);
  }
}
