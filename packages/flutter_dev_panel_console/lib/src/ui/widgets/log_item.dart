import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/log_entry.dart';
import '../../providers/console_provider.dart';

/// 单个日志项的显示组件
class LogItem extends StatelessWidget {
  final LogEntry log;
  final ConsoleProvider provider;
  final VoidCallback? onTap;

  const LogItem({
    super.key,
    required this.log,
    required this.provider,
    this.onTap,
  });

  /// Get message text color based on log level
  Color? _getMessageColor(LogLevel level, ThemeData theme) {
    switch (level) {
      case LogLevel.error:
        return Colors.red;
      case LogLevel.warning:
        return Colors.orange;
      default:
        return null; // Use default text color
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelColor = provider.getLevelColor(log.level);
    final timeFormat = DateFormat('HH:mm:ss.SSS');

    return InkWell(
      onTap: onTap ?? () => _showLogDetail(context),
      onLongPress: () => _copyToClipboard(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日志级别标识
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.levelText,
                style: TextStyle(
                  color: levelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ),

            // 时间戳
            Container(
              height: 24, // 与级别标识相同高度
              alignment: Alignment.center, // 垂直居中
              child: Text(
                timeFormat.format(log.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 日志内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 消息
                  Text(
                    log.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: _getMessageColor(log.level, theme),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 错误信息（如果有）
                  if (log.error != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 展开图标
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示日志详情
  void _showLogDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LogDetailSheet(log: log, provider: provider),
    );
  }

  /// 复制到剪贴板
  void _copyToClipboard(BuildContext context) {
    final text = StringBuffer();
    text.writeln('[${log.levelText}] ${log.formattedTime}');
    text.writeln(log.message);
    if (log.error != null) {
      text.writeln('Error: ${log.error}');
    }
    if (log.stackTrace != null) {
      text.writeln('Stack Trace:\n${log.stackTrace}');
    }

    Clipboard.setData(ClipboardData(text: text.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// 日志详情底部弹窗
class LogDetailSheet extends StatelessWidget {
  final LogEntry log;
  final ConsoleProvider provider;

  const LogDetailSheet({
    super.key,
    required this.log,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelColor = provider.getLevelColor(log.level);
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖动手柄
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.getLevelIcon(log.level),
                        size: 16,
                        color: levelColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        log.levelText,
                        style: TextStyle(
                          color: levelColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: 'Copy',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(),

          // 日志内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间戳
                  _buildSection(
                    context,
                    title: 'Time',
                    content: timeFormat.format(log.timestamp),
                    icon: Icons.access_time,
                  ),

                  const SizedBox(height: 16),

                  // 消息
                  _buildSection(
                    context,
                    title: 'Message',
                    content: log.message,
                    icon: Icons.message,
                  ),

                  // 错误信息
                  if (log.error != null) ...[
                    const SizedBox(height: 16),
                    _buildSection(
                      context,
                      title: 'Error',
                      content: log.error!,
                      icon: Icons.error_outline,
                      isError: true,
                    ),
                  ],

                  // 堆栈跟踪或 Logger 格式化输出
                  if (log.stackTrace != null) ...[
                    const SizedBox(height: 16),
                    _buildSection(
                      context,
                      title: _isLoggerFormattedOutput(log.stackTrace!) ? 'Full Output' : 'StackTrace',
                      content: log.stackTrace!,
                      icon: _isLoggerFormattedOutput(log.stackTrace!) ? Icons.format_align_left : Icons.layers,
                      isMonospace: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    bool isError = false,
    bool isMonospace = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isError
                ? Colors.red.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isError
                  ? Colors.red.withValues(alpha: 0.3)
                  : theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: SelectableText(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: isMonospace ? 'Courier New, monospace' : null,
              color: isError ? Colors.red : null,
              fontSize: isMonospace ? 13 : null,
              height: isMonospace ? 1.4 : null,
            ),
          ),
        ),
      ],
    );
  }

  /// Check if the content is Logger package formatted output
  bool _isLoggerFormattedOutput(String content) {
    return content.contains('┌') || 
           content.contains('├') || 
           content.contains('│') || 
           content.contains('└') ||
           content.contains('┄');
  }

  void _copyToClipboard(BuildContext context) {
    final text = StringBuffer();
    text.writeln('[${log.levelText}] ${log.formattedTime}');
    text.writeln(log.message);
    if (log.error != null) {
      text.writeln('Error: ${log.error}');
    }
    if (log.stackTrace != null) {
      text.writeln('Stack Trace:\n${log.stackTrace}');
    }

    Clipboard.setData(ClipboardData(text: text.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
