import 'package:flutter/material.dart';

/// 无限旋转动画组件
/// 
/// 使子组件无限旋转的动画效果
class InfiniteRotate extends StatefulWidget {
  /// 要旋转的子组件
  final Widget child;

  /// 构造函数
  /// 
  /// [key]: 组件key
  /// [child]: 要旋转的子组件
  const InfiniteRotate({super.key, required this.child});

  @override
  _InfiniteRotateState createState() => _InfiniteRotateState(child: child);
}

/// 无限旋转动画状态管理
class _InfiniteRotateState extends State<InfiniteRotate>
    with TickerProviderStateMixin {
  /// 要旋转的子组件
  final Widget child;

  /// 构造函数
  /// 
  /// [child]: 要旋转的子组件
  _InfiniteRotateState({required this.child});

  /// 动画控制器
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 1), // 旋转一周的时间
    vsync: this,
  );
  
  /// 动画曲线
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.linear, // 线性动画，匀速旋转
  );
  
  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: false); // 重复动画，不反向
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      alignment: Alignment.center, // 中心点旋转
      turns: _animation, // 动画值
      child: child, // 子组件
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // 释放动画控制器
    super.dispose();
  }
}
