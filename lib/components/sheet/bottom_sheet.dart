import 'package:flutter/material.dart';

/// 底部弹窗项类
/// 
/// 定义底部弹窗中的单个选项
class SheetItem {
  /// 选项标题
  final Widget title;
  
  /// 选项图标
  final Widget? icon;
  
  /// 点击回调函数
  final Function()? onPressed;
  
  /// 是否隐藏
  bool? hidden;

  /// 构造函数
  /// 
  /// [title]: 选项标题
  /// [icon]: 选项图标
  /// [onPressed]: 点击回调函数
  /// [hidden]: 是否隐藏
  SheetItem({
    required this.title,
    this.icon,
    this.onPressed,
    this.hidden,
  });
}

/// 打开底部弹窗
/// 
/// 显示包含多个选项的底部弹窗
/// 
/// [context]: 上下文
/// [items]: 弹窗选项列表
/// 
/// 实现步骤：
/// 1. 计算弹窗高度（基于选项数量）
/// 2. 显示带拖拽手柄的底部弹窗
/// 3. 构建弹窗内容，只显示非隐藏的选项
/// 4. 为每个选项添加点击事件，点击后关闭弹窗并执行回调
void openBottomSheet(BuildContext context, List<SheetItem> items) {
  const double itemHeight = 55; // 每个选项的高度
  final double height = 
      (itemHeight * items.where((e) => e.hidden != true).length).toDouble() +
          30; // 计算总高度，加上边距

  showModalBottomSheet(
    context: context,
    showDragHandle: true, // 显示拖拽手柄
    builder: (BuildContext ctx) {
      return SafeArea(
        bottom: true,
        child: Container(
          color: Theme.of(context).cardTheme.color,
          height: height,
          child: ListView(
            children: [
              ...items.toList().map((e) {
                if (e.hidden == true) return Container(); // 跳过隐藏的选项

                return ListTile(
                  minTileHeight: itemHeight,
                  leading: e.icon,
                  title: e.title,
                  onTap: e.onPressed != null
                      ? () {
                          Navigator.of(context).pop(); // 关闭弹窗
                          e.onPressed!(); // 执行回调
                        }
                      : null,
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
