import 'dart:convert';

import 'package:bbmusic/constants/cache_key.dart';
import 'package:bbmusic/modules/open_music_order/utils.dart';
import 'package:bbmusic/origin_sdk/origin_types.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dio = Dio();

class OpenMusicOrderModel extends ChangeNotifier {
  final List<MusicOrderItem> dataList = [];
  bool loading = true;
  final dio = Dio();

  Future<void> _loadCache() async {
    try {
      final localStorage = await SharedPreferences.getInstance();
      final cacheStr = localStorage.getString(CacheKey.openMusicOrderDataCache);
      if (cacheStr != null && cacheStr.isNotEmpty) {
        final List<dynamic> cacheData = jsonDecode(cacheStr);
        dataList.clear();
        for (var item in cacheData) {
          dataList.add(MusicOrderItem.fromJson(item));
        }
        notifyListeners();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _saveCache() async {
    try {
      final localStorage = await SharedPreferences.getInstance();
      final cacheData = dataList.map((e) => e.toJson()).toList();
      await localStorage.setString(CacheKey.openMusicOrderDataCache, jsonEncode(cacheData));
    } catch (e) {
      print(e);
    }
  }

  Future<void> load() async {
    await _loadCache();

    final List<String> urls = await getMusicOrderUrl();
    final newDataList = <MusicOrderItem>[];
    bool hasError = false;

    await Future.wait(urls.map((url) async {
      try {
        final res = await dio.get(url);
        if (res.statusCode == 200) {
          final data = res.data;
          final List<MusicOrderItem> l = [];
          data.forEach((item) {
            l.add(MusicOrderItem.fromJson(item));
          });
          newDataList.addAll(l);
        }
      } catch (e) {
        print(e);
        hasError = true;
      }
    }));

    if (newDataList.isNotEmpty || !hasError) {
      dataList.clear();
      dataList.addAll(newDataList);
      await _saveCache();
    }

    loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    loading = true;
    notifyListeners();

    final List<String> urls = await getMusicOrderUrl();
    final newDataList = <MusicOrderItem>[];
    bool hasError = false;

    await Future.wait(urls.map((url) async {
      try {
        final res = await dio.get(url);
        if (res.statusCode == 200) {
          final data = res.data;
          final List<MusicOrderItem> l = [];
          data.forEach((item) {
            l.add(MusicOrderItem.fromJson(item));
          });
          newDataList.addAll(l);
        }
      } catch (e) {
        print(e);
        hasError = true;
      }
    }));

    if (hasError && dataList.isEmpty) {
      BotToast.showSimpleNotification(title: "歌单源错误");
    }

    if (newDataList.isNotEmpty) {
      dataList.clear();
      dataList.addAll(newDataList);
      await _saveCache();
    }

    loading = false;
    notifyListeners();
  }
}
