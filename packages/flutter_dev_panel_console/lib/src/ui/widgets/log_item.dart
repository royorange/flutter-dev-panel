import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/log_entry.dart';
import '../../providers/console_provider.dart';
import 'log_item_painter.dart';

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
                      title: _getStackTraceTitle(log.stackTrace!),
                      content: log.stackTrace!,
                      icon: _getStackTraceIcon(log.stackTrace!),
                      isMonospace: true,
                      isFlutterError: _isFlutterError(log.stackTrace!),
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
    bool isFlutterError = false,
  }) {
    final theme = Theme.of(context);

    // For Flutter errors, we can highlight important parts
    Widget contentWidget;
    if (isFlutterError && content.contains('EXCEPTION CAUGHT BY')) {
      contentWidget = _buildHighlightedErrorContent(context, content);
    } else if (_isLoggerFormattedOutput(content)) {
      // Also use highlighted content for Logger output
      contentWidget = _buildHighlightedErrorContent(context, content);
    } else {
      contentWidget = SelectableText(
        content,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: isMonospace ? 'Courier New, monospace' : null,
          color: isError ? Colors.red : null,
          fontSize: isMonospace ? 13 : null,
          height: isMonospace ? 1.4 : null,
        ),
      );
    }

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
          child: contentWidget,
        ),
      ],
    );
  }

  Widget _buildHighlightedErrorContent(BuildContext context, String content) {
    final theme = Theme.of(context);
    final List<Widget> widgets = [];
    final List<TextSpan> currentSpans = [];
    
    // First, clean ANSI escape codes from the entire content
    // Match all variations of ANSI codes including those without escape character
    String cleanedContent = content;
    
    // Remove standard ANSI escape sequences
    cleanedContent = cleanedContent.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
    
    // Remove bracketed codes that look like ANSI but without escape char
    // This includes [38;5;196m, [0m, etc.
    // More comprehensive pattern to catch all variations
    cleanedContent = cleanedContent.replaceAll(RegExp(r'\[[\d;]+m'), '');
    
    final lines = cleanedContent.split('\n');
    
    // Check if this is Logger formatted output
    final isLoggerOutput = _isLoggerFormattedOutput(cleanedContent);
    
    // Trim trailing empty lines
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Replace Logger box-drawing lines with our own separator
      if (isLoggerOutput && _isLoggerDecorationLine(line)) {
        // Add a subtle separator line instead of the Logger decoration
        // Check if this is a middle separator (between exception and stack trace)
        if (line.startsWith('├') && line.contains('┄')) {
          // First, add any accumulated text spans but remove the trailing newline
          if (currentSpans.isNotEmpty) {
            // Remove last newline before adding divider
            if (currentSpans.last.toPlainText() == '\n') {
              currentSpans.removeLast();
            }
            widgets.add(SelectableText.rich(
              TextSpan(children: List.from(currentSpans)),
            ));
            currentSpans.clear();
          }
          // Add a dashed divider widget with asymmetric margin (more space on top)
          widgets.add(
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 4),
              child: CustomPaint(
                size: const Size(double.infinity, 1),
                painter: DashedLinePainter(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
            ),
          );
        }
        continue; // Skip the original line
      }
      
      // Remove Logger box-drawing prefix if present
      String cleanLine = line;
      if (isLoggerOutput) {
        // Remove various Logger prefixes
        if (line.startsWith('│ ')) {
          cleanLine = line.substring(2); // Remove "│ " prefix
        } else if (line.startsWith('├ ')) {
          cleanLine = line.substring(2); // Remove "├ " prefix  
        } else if (line.startsWith('│')) {
          cleanLine = line.substring(1).trimLeft(); // Remove "│" and spaces
        }
        
        // Check again if the cleaned line is just decoration
        if (_isLoggerDecorationLine(cleanLine)) {
          continue;
        }
      }
      
      // Skip empty lines
      if (cleanLine.trim().isEmpty) {
        continue;
      }
      
      TextStyle style;
      
      // Simple and effective highlighting rules
      if (cleanLine.contains(':') && !cleanLine.contains('://')) {
        // Lines with colons (property lines) - make the label bold
        final colonIndex = cleanLine.indexOf(':');
        if (colonIndex > 0 && colonIndex < cleanLine.length - 1) {
          final label = cleanLine.substring(0, colonIndex + 1);
          final value = cleanLine.substring(colonIndex + 1);
          
          currentSpans.add(TextSpan(
            text: label,
            style: const TextStyle(
              fontFamily: 'Courier New, monospace',
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ));
          currentSpans.add(TextSpan(
            text: value,
            style: const TextStyle(
              fontFamily: 'Courier New, monospace',
              fontSize: 13,
            ),
          ));
        } else {
          // If colon is at the edge, treat as normal text
          currentSpans.add(TextSpan(
            text: cleanLine,
            style: const TextStyle(
              fontFamily: 'Courier New, monospace',
              fontSize: 13,
              height: 1.4,
            ),
          ));
        }
        // Add newline except for last line
        if (i < lines.length - 1) {
          currentSpans.add(const TextSpan(text: '\n'));
        }
      } else if (cleanLine.contains('file:///') || cleanLine.contains('http://')) {
        // URLs - underlined
        style = const TextStyle(
          fontFamily: 'Courier New, monospace',
          decoration: TextDecoration.underline,
          fontSize: 13,
        );
        currentSpans.add(TextSpan(text: cleanLine, style: style));
        if (i < lines.length - 1) {
          currentSpans.add(const TextSpan(text: '\n'));
        }
      } else if (RegExp(r'^[◢◤═─]+$').hasMatch(cleanLine.trim())) {
        // Decorative lines - dimmed
        style = TextStyle(
          fontFamily: 'Courier New, monospace',
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 13,
        );
        currentSpans.add(TextSpan(text: cleanLine, style: style));
        if (i < lines.length - 1) {
          currentSpans.add(const TextSpan(text: '\n'));
        }
      } else if (cleanLine.trim().isNotEmpty) {
        // Everything else - normal monospace (skip empty lines)
        style = const TextStyle(
          fontFamily: 'Courier New, monospace',
          fontSize: 13,
          height: 1.4,
        );
        currentSpans.add(TextSpan(text: cleanLine, style: style));
        if (i < lines.length - 1) {
          currentSpans.add(const TextSpan(text: '\n'));
        }
      }
    }
    
    // Add any remaining spans
    if (currentSpans.isNotEmpty) {
      // Remove trailing newline if present
      if (currentSpans.isNotEmpty) {
        final lastSpan = currentSpans.last;
        final lastText = lastSpan.toPlainText();
        if (lastText == '\n') {
          currentSpans.removeLast();
        }
      }
      widgets.add(SelectableText.rich(
        TextSpan(children: List.from(currentSpans)),
      ));
    }
    
    // If we have multiple widgets, return a Column, otherwise return single SelectableText
    if (widgets.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    } else if (widgets.isNotEmpty) {
      return widgets.first;
    } else {
      // Fallback for empty content
      return SelectableText.rich(
        TextSpan(text: content),
      );
    }
  }
  
  /// Check if a line is purely Logger decoration
  bool _isLoggerDecorationLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return true;
    
    // Check for Logger's dotted separator lines like "├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄"
    if (line.startsWith('├') && line.contains('┄')) return true;
    if (line.startsWith('│') && RegExp(r'^│\s*[┄─╌╍╎╏\-_=]+\s*$').hasMatch(line)) return true;
    
    // More comprehensive check for Logger decoration lines
    // These dashed lines might contain normal dashes
    if (RegExp(r'^-{10,}$').hasMatch(trimmed)) return true; // Lines with 10+ dashes
    if (RegExp(r'^_{10,}$').hasMatch(trimmed)) return true; // Lines with 10+ underscores
    if (RegExp(r'^={10,}$').hasMatch(trimmed)) return true; // Lines with 10+ equals
    if (RegExp(r'^┄{10,}$').hasMatch(trimmed)) return true; // Lines with 10+ dotted lines
    
    // Match pure decoration lines from Logger package
    // Include various types of lines and box-drawing characters including ┄ (dotted)
    return RegExp(r'^[┌├└─┐┤┘│╌╍╎╏┄\-_=]+$').hasMatch(trimmed) ||
           RegExp(r'^[│├]\s*[-─╌╍╎╏┄_=]+\s*$').hasMatch(line) || // Lines like "│ --------"
           (trimmed.startsWith('├') && trimmed.endsWith('┤')) || // Box middle lines
           (trimmed.startsWith('└') && trimmed.endsWith('┘')); // Box bottom lines
  }

  String _getStackTraceTitle(String stackTrace) {
    // Simple and clear: only distinguish real stack traces
    if (_containsStackTrace(stackTrace)) {
      return 'StackTrace';
    }
    // Everything else is just "Details"
    return 'Details';
  }

  IconData _getStackTraceIcon(String stackTrace) {
    if (_containsStackTrace(stackTrace)) {
      return Icons.layers;
    } else if (_isFlutterError(stackTrace)) {
      return Icons.error_outline;
    } else if (_isLoggerFormattedOutput(stackTrace)) {
      return Icons.format_align_left;
    }
    return Icons.info_outline;
  }

  bool _containsStackTrace(String content) {
    // Check for actual stack trace patterns
    return content.contains('#0 ') ||
           content.contains('at ') ||
           content.contains('.dart:') && content.contains('(') ||
           RegExp(r'^\s+at\s+', multiLine: true).hasMatch(content);
  }

  bool _isFlutterError(String content) {
    // Only check for Flutter-specific error markers, not stack traces
    return content.contains('EXCEPTION CAUGHT BY') ||
           content.contains('The following assertion was thrown') ||
           content.contains('RenderFlex overflowed');
  }

  /// Check if the content is Logger package formatted output
  bool _isLoggerFormattedOutput(String content) {
    // More strict check - must have multiple Logger symbols, not just one
    int loggerSymbolCount = 0;
    if (content.contains('┌')) loggerSymbolCount++;
    if (content.contains('├')) loggerSymbolCount++;
    if (content.contains('└')) loggerSymbolCount++;
    return loggerSymbolCount >= 2 && content.contains('│');
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
