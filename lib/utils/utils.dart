import 'dart:async';

/// 节流方法类
/// 
/// 用于限制函数调用频率，在指定时间间隔内只执行一次回调
/// 
/// 原理：
/// 1. 当调用 call 方法时，检查是否已有定时器在运行
/// 2. 如果定时器已存在且激活，则直接返回，不执行回调
/// 3. 如果没有定时器或定时器已完成，则创建新的定时器
/// 4. 定时器完成后执行回调，并清除定时器引用
class Throttle {
  /// 节流时间间隔
  final Duration duration;
  
  /// 内部定时器
  Timer? _timer;

  /// 构造函数
  /// 
  /// [duration]: 节流时间间隔
  Throttle(this.duration);

  /// 执行节流操作
  /// 
  /// [callback]: 要执行的回调函数
  /// 
  /// 调用方式：
  /// ```dart
  /// final throttle = Throttle(Duration(seconds: 1));
  /// throttle(() {
  ///   // 执行需要节流的操作
  /// });
  /// ```
  void call(Function callback) {
    if (_timer?.isActive ?? false) {
      return;
    }
    _timer = Timer(duration, () {
      callback();
      _timer = null;
    });
  }
}
