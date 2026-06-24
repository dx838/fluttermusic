import 'dart:async';

import 'package:bbmusic/constants/cache_key.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用主题模式（区分于 Flutter 内置的 ThemeMode）
enum AppThemeMode {
  /// 浅色（白天）
  light,

  /// 深色（黑夜）
  dark,

  /// 跟随系统
  system,

  /// 定时切换：白天/黑夜按设置时间切换
  timed,
}

/// 主题模型
///
/// 负责：
/// - 持久化主题设置（模式 / 定时切换时间）
/// - 根据当前模式计算实际生效的 `Brightness`
/// - 定时切换模式下，监听时间到达时自动切换主题
class ThemeModel extends ChangeNotifier with WidgetsBindingObserver {
  AppThemeMode _mode = AppThemeMode.light;

  /// 定时切换起始时间（白天开始，24h 制，时/分）
  int _lightStartHour = 6;
  int _lightStartMinute = 0;

  /// 定时切换结束时间（黑夜开始，24h 制，时/分）
  int _darkStartHour = 20;
  int _darkStartMinute = 0;

  SharedPreferences? _prefs;

  /// 定时切换定时器
  Timer? _timer;

  AppThemeMode get mode => _mode;
  int get lightStartHour => _lightStartHour;
  int get lightStartMinute => _lightStartMinute;
  int get darkStartHour => _darkStartHour;
  int get darkStartMinute => _darkStartMinute;

  /// 当前实际亮度
  Brightness get brightness {
    switch (_mode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
      case AppThemeMode.timed:
        return _computeTimedBrightness(DateTime.now());
    }
  }

  /// 初始化：读取本地设置 + 注册系统主题变化监听 + 启动定时任务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
    WidgetsBinding.instance.addObserver(this);
    _scheduleTimerIfNeeded();
    notifyListeners();
  }

  /// 从 SharedPreferences 读取配置
  void _loadFromPrefs() {
    final modeName = _prefs?.getString(CacheKey.themeMode);
    if (modeName != null) {
      _mode = AppThemeMode.values.firstWhere(
        (e) => e.name == modeName,
        orElse: () => AppThemeMode.light,
      );
    }
    _lightStartHour = _prefs?.getInt(CacheKey.themeLightStartHour) ?? 6;
    _lightStartMinute = _prefs?.getInt(CacheKey.themeLightStartMinute) ?? 0;
    _darkStartHour = _prefs?.getInt(CacheKey.themeDarkStartHour) ?? 20;
    _darkStartMinute = _prefs?.getInt(CacheKey.themeDarkStartMinute) ?? 0;
  }

  /// 计算定时模式下的亮度
  Brightness _computeTimedBrightness(DateTime now) {
    final startLight = DateTime(now.year, now.month, now.day,
        _lightStartHour, _lightStartMinute);
    final startDark = DateTime(now.year, now.month, now.day,
        _darkStartHour, _darkStartMinute);

    if (startLight == startDark) {
      return Brightness.light;
    }

    // 处理跨天：若黑夜时间早于白天时间，视为跨日
    final crossesDay = startDark.isBefore(startLight);

    if (!crossesDay) {
      // 同日：[lightStart, darkStart) 为白天
      final inLight =
          !now.isBefore(startLight) && now.isBefore(startDark);
      return inLight ? Brightness.light : Brightness.dark;
    } else {
      // 跨日：[lightStart, 24:00) + [0:00, darkStart) 为白天
      final inLight = !now.isBefore(startLight) || now.isBefore(startDark);
      return inLight ? Brightness.light : Brightness.dark;
    }
  }

  /// 重新计算并通知（定时/系统模式下由定时器或 observer 调用）
  void _refresh() {
    notifyListeners();
  }

  /// 启动/重启定时调度
  void _scheduleTimerIfNeeded() {
    _timer?.cancel();
    if (_mode != AppThemeMode.timed) return;

    // 计算到下一次切换的时间点
    final now = DateTime.now();
    final startLight = DateTime(now.year, now.month, now.day,
        _lightStartHour, _lightStartMinute);
    final startDark = DateTime(now.year, now.month, now.day,
        _darkStartHour, _darkStartMinute);

    final candidates = <DateTime>[];
    if (startLight.isAfter(now)) candidates.add(startLight);
    if (startDark.isAfter(now)) candidates.add(startDark);
    // 若两个时间点都已过，则下一次切换在明天
    final tomorrow = now.add(const Duration(days: 1));
    if (startLight.isBefore(now) || startLight == now) {
      candidates.add(DateTime(tomorrow.year, tomorrow.month, tomorrow.day,
          _lightStartHour, _lightStartMinute));
    }
    if (startDark.isBefore(now) || startDark == now) {
      candidates.add(DateTime(tomorrow.year, tomorrow.month, tomorrow.day,
          _darkStartHour, _darkStartMinute));
    }

    candidates.sort();
    final next = candidates.first;
    final delay = next.difference(now);

    _timer = Timer(delay, () {
      _refresh();
      _scheduleTimerIfNeeded();
    });
  }

  /// 切换主题模式
  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    await _prefs?.setString(CacheKey.themeMode, mode.name);
    _scheduleTimerIfNeeded();
    notifyListeners();
  }

  /// 更新白天起始时间
  Future<void> setLightStart({required int hour, required int minute}) async {
    _lightStartHour = hour;
    _lightStartMinute = minute;
    await _prefs?.setInt(CacheKey.themeLightStartHour, hour);
    await _prefs?.setInt(CacheKey.themeLightStartMinute, minute);
    _scheduleTimerIfNeeded();
    notifyListeners();
  }

  /// 更新黑夜起始时间
  Future<void> setDarkStart({required int hour, required int minute}) async {
    _darkStartHour = hour;
    _darkStartMinute = minute;
    await _prefs?.setInt(CacheKey.themeDarkStartHour, hour);
    await _prefs?.setInt(CacheKey.themeDarkStartMinute, minute);
    _scheduleTimerIfNeeded();
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode == AppThemeMode.system) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
