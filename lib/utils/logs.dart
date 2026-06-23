// import 'dart:io';
import 'package:logger/logger.dart';
// import 'package:path_provider/path_provider.dart';

// import 'package:logger/logger.dart';

/// 全局日志实例
/// 
/// 使用 logger 库创建的日志实例，用于在开发和生产环境中记录日志
/// 
/// 使用示例：
/// ```dart
/// logs.d('调试信息'); // 调试级别日志
/// logs.i('信息'); // 信息级别日志
/// logs.w('警告'); // 警告级别日志
/// logs.e('错误'); // 错误级别日志
/// logs.v('详细信息'); // 详细级别日志
/// ```
/// 
/// 用途：
/// - 记录应用运行状态
/// - 调试代码
/// - 捕获和分析错误
/// - 监控应用性能

// final logs = Logger();

final logs = Logger();

// Future<Logger> createLogger() async {
//   final directory = await getApplicationDocumentsDirectory();
//   final file = File('${directory.path}/fluttermusic.log');
//   return Logger(
//     output: MultiOutput([
//       ConsoleOutput(),
//       FileOutput(
//         file: file,
//         append: true,
//       ),
//     ]),
//     level: Level.verbose,
//   );
// }

// // 全局日志实例
// late final Logger logs;

// /// 初始化日志
// Future<void> initLogs() async {
//   logs = await createLogger();
// }
