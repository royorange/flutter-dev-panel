import 'package:flutter/material.dart';
import 'package:flutter_dev_panel/flutter_dev_panel.dart';
import 'ui/pages/console_page.dart';

/// Console 日志模块
class ConsoleModule extends DevModule {
  final LogCaptureConfig? logConfig;
  
  const ConsoleModule({
    this.logConfig,
  }) : super(
          id: 'console',
          name: 'Console',
          description: '查看应用日志和错误信息',
          icon: Icons.terminal,
          enabled: true,
          order: 0, // 最高优先级，显示在第一个
        );

  @override
  Widget buildPage(BuildContext context) {
    return const ConsolePage();
  }

  @override
  Widget? buildFabContent(BuildContext context) {
    // 如果暂停了，不显示FAB内容
    if (DevLogger.instance.isPaused) {
      return null;
    }

    // 使用 DevLogger 缓存的统计数据，O(1) 获取
    final errorCount = DevLogger.instance.errorCount;
    final warningCount = DevLogger.instance.warningCount;

    if (errorCount > 0 || warningCount > 0) {
      return Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errorCount > 0) ...[
              Flexible(
                child: Text(
                  '$errorCount ${errorCount == 1 ? 'error' : 'errors'}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (errorCount > 0 && warningCount > 0)
              const Text(
                ', ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            if (warningCount > 0) ...[
              Flexible(
                child: Text(
                  '$warningCount ${warningCount == 1 ? 'warning' : 'warnings'}',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      );
    }
    return null;
  }

  @override
  int get fabPriority => 1; // 最高优先级，优先显示错误计数

  @override
  Future<void> initialize() async {
    // 如果提供了配置，更新 DevLogger 配置
    if (logConfig != null) {
      DevLogger.instance.updateConfig(logConfig!);
    }
    DevLogger.log('Console module initialized');
  }

  @override
  void dispose() {
    // 清理资源
  }

  /// 添加测试日志的便捷方法
  static void addTestLogs() {
    DevLogger.instance.verbose('This is a verbose log message');
    DevLogger.instance.debug('Debug: Component rendered successfully');
    DevLogger.instance.info('Info: User logged in');
    DevLogger.instance.warning('Warning: API rate limit approaching',
        error: 'Rate limit: 95%');
    DevLogger.instance.error(
      'Error: Failed to fetch data',
      error: 'NetworkException: Connection timeout',
      stackTrace: '''
at fetchData (network.dart:123)
at _handleRequest (api_client.dart:45)
at main (main.dart:12)
''',
    );
  }
}
