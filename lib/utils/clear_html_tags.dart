/// 清除HTML标签
/// 
/// [htmlText]: 包含HTML标签的文本
/// 
/// 返回值：去除HTML标签后的纯文本
/// 
/// 处理步骤：
/// 1. 使用正则表达式移除所有HTML标签
/// 2. 将 &nbsp; 和 &amp; 替换为空格
/// 3. 将 】 替换为 -
/// 4. 移除 【
String clearHtmlTags(String htmlText) {
  RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
  return htmlText
      .replaceAll(exp, '')
      .replaceAll(RegExp(r'&nbsp;|&amp;'), ' ')
      .replaceAll(RegExp(r'】'), '-')
      .replaceAll('【', '');
}

/// 将 mm:ss 格式的时间转换为秒
/// 
/// [durationStr]: 格式为 mm:ss 的时间字符串
/// 
/// 返回值：转换后的秒数
/// 
/// 处理逻辑：
/// 1. 检查输入是否为空
/// 2. 按冒号分割字符串
/// 3. 检查分割后的部分是否至少有两部分
/// 4. 解析分钟和秒数
/// 5. 计算总秒数
int duration2seconds(String durationStr) {
  if (durationStr.isEmpty) {
    return 0;
  }
  List<String> parts = durationStr.split(':');
  if (parts.length < 2) {
    return 0;
  }
  int minutes = int.tryParse(parts[0]) ?? 0;
  int seconds = int.tryParse(parts[1]) ?? 0;
  return minutes * 60 + seconds;
}

/// 将秒数转换为 mm:ss 格式的时间字符串
/// 
/// [seconds]: 秒数
/// 
/// 返回值：格式为 mm:ss 的时间字符串
/// 
/// 处理逻辑：
/// 1. 计算分钟数（向下取整）
/// 2. 计算剩余秒数
/// 3. 将分钟和秒数格式化为两位数
/// 4. 拼接成 mm:ss 格式
String seconds2duration(int seconds) {
  int minutes = (seconds / 60).floor();
  int remainingSeconds = seconds % 60;
  String minutesStr = minutes.toString().padLeft(2, '0');
  String secondsStr = remainingSeconds.toString().padLeft(2, '0');
  return '$minutesStr:$secondsStr';
}
