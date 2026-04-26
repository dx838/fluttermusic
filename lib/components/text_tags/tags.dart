import 'package:flutter/material.dart';

/// 文本标签组件
/// 
/// 显示多个文本标签，水平排列
class TextTags extends StatelessWidget {
  /// 标签列表
  final List<String> tags;
  
  /// 构造函数
  /// 
  /// [key]: 组件key
  /// [tags]: 标签列表
  const TextTags({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: tags.map((tag) {
        return Container(
          margin: const EdgeInsets.only(right: 10), // 每个标签右侧的边距
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 12, // 标签字体大小
            ),
          ),
        );
      }).toList(),
    );
  }
}
