import 'dart:async';
import 'dart:convert';

import 'package:bbmusic/constants/cache_key.dart';
import 'package:bbmusic/database/database.dart';
import 'package:bbmusic/database/uuid.dart';
import 'package:bbmusic/modules/user_music_order/common.dart';
import 'package:bbmusic/modules/user_music_order/local/constants.dart';
import 'package:bbmusic/modules/user_music_order/user_music_order.dart';
import 'package:bbmusic/origin_sdk/origin_types.dart';
import 'package:bbmusic/utils/logs.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

class MusicOrderOriginSettingModel extends ChangeNotifier {
  List<OriginSettingItem> list = [];
  bool isInit = false;
  final db = AppDatabase();

  List<UserMusicOrderOriginItem> userMusicOrderList = [];

  init() async {
    if (isInit) {
      return;
    }
    await load();
    await initUserMusicOrderList();
    isInit = true;
  }

  // 加载源配置列表
  load() async {
    // 云端歌单源
    final cloudList = await db.managers.cloudMusicOrderEntity.get();
    list.clear();
    list.addAll(cloudList.where((t) => t.origin != LocalOriginConst.name).map(
      (l) {
        return OriginSettingItem(
          id: l.id.toString(),
          name: l.origin,
          subName: l.subName ?? '',
          config: jsonDecode(l.config ?? '{}'),
        );
      },
    ));
    // 本地歌单源列表
    list.insert(
      0,
      OriginSettingItem(
        id: LocalOriginConst.name,
        name: LocalOriginConst.name,
        subName: LocalOriginConst.cname,
        config: {},
      ),
    );
  }

  // 更新源配置列表
  void update(String id, String subName, Map<String, dynamic> config) async {
    await db.managers.cloudMusicOrderEntity
        .filter((f) => f.id.equals(id))
        .update((o) {
      return o(
        subName: Value(subName),
        config: Value(jsonEncode(config)),
      );
    });
    await load();
    await initUserMusicOrderList();
    notifyListeners();
  }

  // 新增源配置
  void add(String name, String subName, Map<String, dynamic> config) async {
    await db.managers.cloudMusicOrderEntity.create((o) {
      return o(
        id: generateUUID(),
        origin: name,
        subName: subName,
        config: jsonEncode(config),
      );
    });
    await load();
    await initUserMusicOrderList();
    notifyListeners();
  }

  // 删除源配置
  void delete(String id) async {
    await db.managers.cloudMusicOrderEntity
        .filter((f) => f.id.equals(id))
        .delete();
    await load();
    await initUserMusicOrderList();
    notifyListeners();
  }

  OriginSettingItem? id2OriginInfo(String id) {
    return list.firstWhere((o) => o.id == id);
  }

  // 初始化用户歌单列表
  initUserMusicOrderList() async {
    userMusicOrderList.clear();
    for (var s in list) {
      final umo = userMusicOrderOrigin[s.name];
      if (umo != null) {
        userMusicOrderList.add(
          UserMusicOrderOriginItem(
            id: s.id,
            service: umo(),
          ),
        );
      }
    }
    await Future.wait(userMusicOrderList.map((s) => _loadItem(s)));
  }

  // 重载单个源的列表
  loadSignal(String id) async {
    final current = userMusicOrderList.firstWhere((d) => d.id == id);
    final info = id2OriginInfo(id);
    if (info == null) return;
    await _loadItem(current);
  }

  Future<List<MusicOrderItem>> _loadCache(String originName) async {
    try {
      final localStorage = await SharedPreferences.getInstance();
      final cacheKey = '${CacheKey.userMusicOrderCachePrefix}$originName';
      final cacheStr = localStorage.getString(cacheKey);
      if (cacheStr != null && cacheStr.isNotEmpty) {
        final List<dynamic> cacheData = jsonDecode(cacheStr);
        return cacheData.map((item) => MusicOrderItem.fromJson(item)).toList();
      }
    } catch (e) {
      logs.e("加载歌单缓存失败: $originName", error: e);
    }
    return [];
  }

  Future<void> _saveCache(String originName, List<MusicOrderItem> data) async {
    try {
      final localStorage = await SharedPreferences.getInstance();
      final cacheKey = '${CacheKey.userMusicOrderCachePrefix}$originName';
      final cacheData = data.map((e) => e.toJson()).toList();
      await localStorage.setString(cacheKey, jsonEncode(cacheData));
    } catch (e) {
      logs.e("保存歌单缓存失败: $originName", error: e);
    }
  }

  // 根据配置加载歌单列表
  Future<void> _loadItem(UserMusicOrderOriginItem umo, {bool fromCacheOnly = false}) async {
    umo.loading = true;
    notifyListeners();
    try {
      final config = id2OriginInfo(umo.id)?.config;
      await umo.service.initConfig(config ?? {});

      final originName = umo.service.name;
      final cachedList = await _loadCache(originName);
      if (cachedList.isNotEmpty) {
        umo.list = Future.value(cachedList);
        notifyListeners();
      }

      try {
        final freshList = await umo.service.getList();
        if (freshList.isNotEmpty) {
          umo.list = Future.value(freshList);
          await _saveCache(originName, freshList);
        } else if (cachedList.isEmpty) {
          umo.list = Future.value([]);
        }
      } catch (e) {
        if (cachedList.isEmpty) {
          umo.list = Future.value([]);
          BotToast.showText(text: "加载歌单源失败");
          logs.e("加载歌单源失败", error: e);
        }
      }
    } catch (e) {
      BotToast.showText(text: "加载歌单源失败");
      logs.e("加载歌单源失败", error: e);
    } finally {
      umo.loading = false;
      notifyListeners();
    }
  }
}

class OriginSettingItem {
  final String name;
  final String id;
  String subName;
  Map<String, dynamic> config;

  OriginSettingItem({
    required this.name,
    required this.id,
    required this.subName,
    required this.config,
  });

  /// 转换为JSON字符串
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'sub_name': subName,
      'config': config,
    };
  }

  /// 从JSON字符串转换
  factory OriginSettingItem.fromJson(Map<String, dynamic> json) {
    return OriginSettingItem(
      name: json['name'],
      id: json['id'],
      subName: json['sub_name'] ?? '',
      config: json['config'],
    );
  }
}

Future<List<MusicOrderItem>> initializeList() async {
  await Future.delayed(const Duration(seconds: 0));
  List<MusicOrderItem> initialItems = [];
  return initialItems;
}

class UserMusicOrderOriginItem {
  String id;
  bool loading = false;
  Future<List<MusicOrderItem>>? list = initializeList();
  final UserMusicOrderOrigin service;
  UserMusicOrderOriginItem({
    this.loading = false,
    this.list,
    required this.id,
    required this.service,
  });
}
