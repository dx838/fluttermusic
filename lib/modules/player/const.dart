import 'package:flutter/material.dart';

/// 播放器状态枚举
/// 
/// 定义了播放器的四种状态：
/// - loading: 加载中，值为-1
/// - stop: 停止，值为0
/// - play: 播放中，值为1
/// - pause: 暂停中，值为2
enum PlayerStatus {
  /// 加载中状态
  loading(value: -1, name: '加载中'),
  /// 停止状态
  stop(value: 0, name: '停止'),
  /// 播放中状态
  play(value: 1, name: '播放中'),
  /// 暂停中状态
  pause(value: 2, name: '暂停中');

  /// 构造函数
  /// 
  /// [value]: 状态值
  /// [name]: 状态名称
  const PlayerStatus({required this.value, required this.name});
  
  /// 状态的数值表示
  final int value;
  /// 状态的文字描述
  final String name;
}

/// 播放模式枚举
/// 
/// 定义了播放器的四种播放模式：
/// - signalLoop: 单曲循环，值为1
/// - random: 随机播放，值为2
/// - listLoop: 列表循环，值为3
/// - listOrder: 顺序播放，值为4
enum PlayerMode {
  /// 单曲循环模式
  signalLoop(
    value: 1,
    name: '单曲循环',
    icon: Icons.repeat_one,
  ),
  /// 随机播放模式
  random(
    value: 2,
    name: '随机',
    icon: Icons.shuffle,
  ),
  /// 列表循环模式
  listLoop(
    value: 3,
    name: '列表循环',
    icon: Icons.repeat,
  ),
  /// 顺序播放模式
  listOrder(
    value: 4,
    name: '顺序播放',
    icon: Icons.list,
  );

  /// 构造函数
  /// 
  /// [value]: 模式值
  /// [name]: 模式名称
  /// [icon]: 模式对应的图标
  const PlayerMode(
      {required this.value, required this.name, required this.icon});
  
  /// 模式的数值表示
  final int value;
  /// 模式的文字描述
  final String name;
  /// 模式对应的图标
  final IconData icon;

  /// 根据数值获取对应的播放模式
  /// 
  /// [value]: 模式的数值
  /// 
  /// 返回值：对应的PlayerMode枚举值
  static PlayerMode getByValue(int value) {
    return values.firstWhere((element) => element.value == value);
  }
}
