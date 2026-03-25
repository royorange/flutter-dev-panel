import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'monitoring_data_provider.dart';
import 'dev_panel_controller.dart';

/// 日志级别
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  Color get color {
    switch (level) {
      case LogLevel.verbose:
        return Colors.grey;
      case LogLevel.debug:
        return Colors.blue;
      case LogLevel.info:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  String get levelText {
    switch (level) {
      case LogLevel.verbose:
        return 'V';
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }
}

/// 开发日志管理器
class DevLogger {
  static final DevLogger _instance = DevLogger._internal();
  static DevLogger get instance => _instance;
  
  // 日志捕获配置
  LogCaptureConfig _config = const LogCaptureConfig();
  LogCaptureConfig get config => _config;
  
  // 暂停状态
  bool _isPaused = false;
  bool get isPaused => _isPaused;
  
  // Logger package buffer for combining multi-line output
  final List<String> _loggerBuffer = [];
  DateTime? _loggerBufferStartTime;
  Timer? _loggerBufferTimer;
  
  // Flutter framework warning buffer (for RenderFlex overflow, etc.)
  final List<String> _flutterWarningBuffer = [];
  DateTime? _flutterWarningStartTime;
  Timer? _flutterWarningTimer;
  
  // stdout interception
  StreamController<List<int>>? _stdoutController;
  
  DevLogger._internal() {
    _setupErrorHandlers();
    _interceptPrint();
    _interceptDeveloperLog();
    _setupFrameworkLogging();
    _interceptStdout();
    // 延迟加载配置，等待 binding 初始化
    Future.microtask(() async {
      try {
        // 等待一帧，确保 binding 已初始化
        await Future.delayed(Duration.zero);
        await _loadConfig();
      } catch (e) {
        // 忽略错误，使用默认配置
      }
    });
  }
  
  /// Load configuration from SharedPreferences
  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maxLogs = prefs.getInt('console_max_logs') ?? 1000;
      final autoScroll = prefs.getBool('console_auto_scroll') ?? true;
      final combineLoggerOutput = prefs.getBool('console_combine_logger') ?? true;
      
      _config = LogCaptureConfig(
        maxLogs: maxLogs,
        autoScroll: autoScroll,
        combineLoggerOutput: combineLoggerOutput,
      );
    } catch (e) {
      // If loading fails, keep default config
      debugPrint('Failed to load console config: $e');
    }
  }
  
  /// Save configuration to SharedPreferences
  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('console_max_logs', _config.maxLogs);
      await prefs.setBool('console_auto_scroll', _config.autoScroll);
      await prefs.setBool('console_combine_logger', _config.combineLoggerOutput);
    } catch (e) {
      debugPrint('Failed to save console config: $e');
    }
  }
  
  /// 更新日志捕获配置
  void updateConfig(LogCaptureConfig config) {
    _config = config;
    // Update max logs if changed
    while (_logs.length > config.maxLogs) {
      final evicted = _logs.removeFirst();
      _decrementStats(evicted.level);
    }
    // Save to disk
    _saveConfig();
  }

  /// 增量更新：添加日志时更新统计
  void _incrementStats(LogLevel level) {
    if (level == LogLevel.error) {
      _errorCount++;
    } else if (level == LogLevel.warning) {
      _warningCount++;
    }
  }

  /// 增量更新：移除日志时更新统计
  void _decrementStats(LogLevel level) {
    if (level == LogLevel.error) {
      _errorCount--;
    } else if (level == LogLevel.warning) {
      _warningCount--;
    }
  }

  final _logs = ListQueue<LogEntry>();
  final _logController = StreamController<LogEntry>.broadcast();

  // 缓存的日志级别统计（避免 FAB 等场景 O(n) 遍历）
  int _errorCount = 0;
  int _warningCount = 0;

  int get maxLogs => _config.maxLogs;
  Stream<LogEntry> get logStream => _logController.stream;
  List<LogEntry> get logs => _logs.toList();
  int get logCount => _logs.length;

  /// O(1) 获取错误数量（FAB 使用）
  int get errorCount => _errorCount;

  /// O(1) 获取警告数量（FAB 使用）
  int get warningCount => _warningCount;
  
  Zone? _printInterceptZone;
  
  
  // Setup Flutter error handlers to capture all errors
  void _setupErrorHandlers() {
    if (!kReleaseMode) {
      // 1. Capture Flutter framework errors (synchronous)
      // Store the original handler
      final originalOnError = FlutterError.onError;
      
      FlutterError.onError = (FlutterErrorDetails details) {
        // Use Flutter's built-in toString() which provides the complete formatted error
        final String fullErrorDetails = details.toString();
        final String mainMessage = details.exceptionAsString();
        
        // Determine log level based on error type
        LogLevel level = LogLevel.error;
        if (mainMessage.contains('RenderFlex overflowed')) {
          level = LogLevel.warning;
        }
        
        // Log the error with the complete formatted details
        _addLog(
          level,
          mainMessage,
          error: null,
          stackTrace: fullErrorDetails,
        );
        
        // Call the original handler if it exists (for console output)
        if (originalOnError != null) {
          originalOnError(details);
        } else {
          // Fallback to presentError if no original handler
          FlutterError.presentError(details);
        }
      };
      
      // 2. Use PlatformDispatcher for comprehensive error capture (async and uncaught)
      PlatformDispatcher.instance.onError = (error, stack) {
        // Log uncaught errors
        this.error(
          'Uncaught Error',
          error: error.toString(),
          stackTrace: stack.toString(),
        );
        
        // Return true to indicate we've handled the error
        return true;
      };
    }
  }
  
  
  // Intercept print statements - this is actually handled by the main Zone
  void _interceptPrint() {
    // Print interception is handled by the Zone in main()
    // This method is kept for compatibility
  }
  
  // Intercept developer.log calls
  void _interceptDeveloperLog() {
    if (!kReleaseMode) {
      // Override developer.log using Zone
      developer.registerExtension('ext.flutter.dev_panel.log', (method, parameters) async {
        final message = parameters['message'] ?? '';
        final level = parameters['level'] ?? 'info';
        
        switch (level) {
          case 'verbose':
            verbose(message);
            break;
          case 'debug':
            debug(message);
            break;
          case 'info':
            info(message);
            break;
          case 'warning':
            warning(message);
            break;
          case 'error':
            error(message);
            break;
          default:
            info(message);
        }
        
        return developer.ServiceExtensionResponse.result('{}');
      });
    }
  }
  
  // Setup framework logging capture
  void _setupFrameworkLogging() {
    if (!kReleaseMode) {
      // Override debugPrint to capture all output including overflow errors
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          // Check if this is part of a Flutter framework error output
          if (message.contains('══╡ EXCEPTION CAUGHT BY') || 
              _flutterWarningBuffer.isNotEmpty) {
            // This is part of a framework error, buffer it
            _handleFlutterWarning(LogLevel.warning, message);
          } else {
            // Normal debug print
            _addLog(LogLevel.debug, message);
          }
        }
        // Still print to console using the original function
        debugPrintSynchronously(message, wrapWidth: wrapWidth);
      };
    }
  }
  
  // Intercept stdout to capture Logger package output
  void _interceptStdout() {
    if (!kReleaseMode && !kIsWeb) {
      try {
        // Create a custom stdout that captures output
        _stdoutController = StreamController<List<int>>.broadcast();
        
        // Listen to our custom stdout
        _stdoutController!.stream.listen((data) {
          final message = String.fromCharCodes(data);
          // Process the stdout message (Logger package writes to stdout)
          if (message.isNotEmpty && message != '\n') {
            _addLog(LogLevel.info, message.trim());
          }
        });
        
        // Note: Actually replacing stdout requires platform-specific code
        // and may not work in all environments. The Zone-based approach
        // is more reliable for Flutter apps.
      } catch (e) {
        // Stdout interception failed, fall back to Zone-based approach
        debugPrint('DevLogger: stdout interception not available: $e');
      }
    }
  }
  
  // Enable print interception for the entire app
  static void enablePrintInterception() {
    if (!kReleaseMode) {
      // Create a custom Zone that intercepts print
      final printZone = Zone.current.fork(
        specification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            // Capture print statement
            instance._addLog(LogLevel.info, line);
            // Still print to console
            parent.print(zone, line);
          },
        ),
      );
      
      instance._printInterceptZone = printZone;
    }
  }
  
  // Run callback with print interception
  static T runWithPrintInterception<T>(T Function() callback) {
    if (!kReleaseMode && instance._printInterceptZone != null) {
      return instance._printInterceptZone!.run(callback);
    }
    return callback();
  }
  
  void _addLog(LogLevel level, String message, {String? error, String? stackTrace}) {
    // Production safety: use unified check
    if (!DevPanelController.isEnabled) {
      return;
    }
    
    // Don't capture logs when paused
    if (_isPaused) {
      return;
    }
    
    // Check if we should filter this log based on config
    if (!_shouldCaptureLog(level, message)) {
      return;
    }
    
    // Check if this is a Logger package output and we should combine it
    if (_config.combineLoggerOutput && _isLoggerPackageOutput(message)) {
      _handleLoggerPackageOutput(level, message, error: error, stackTrace: stackTrace);
      return;
    }
    
    // Check if this is a Flutter framework warning (RenderFlex overflow, etc.)
    if (_isFlutterWarning(message) || _flutterWarningBuffer.isNotEmpty) {
      _handleFlutterWarning(level, message, error: error, stackTrace: stackTrace);
      return;
    }
    
    // Parse and detect log source
    final parsedLog = _parseLogMessage(message);
    
    // Skip empty decoration lines from Logger package
    if (parsedLog.skip || parsedLog.message == null || parsedLog.message!.isEmpty) {
      return;
    }
    
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: parsedLog.level ?? level,
      message: parsedLog.message!,
      error: error,
      stackTrace: stackTrace,
    );
    
    _logs.addLast(entry);
    _incrementStats(entry.level);
    if (_logs.length > _config.maxLogs) {
      final evicted = _logs.removeFirst();
      _decrementStats(evicted.level);
    }

    _logController.add(entry);

    // Notify MonitoringDataProvider when logs change
    // This will trigger FAB update
    MonitoringDataProvider.instance.triggerUpdate();

    // Don't print to console to avoid infinite loop when intercepting print
    // The original print will still be called through the Zone
  }
  
  /// Check if message is from Logger package
  bool _isLoggerPackageOutput(String message) {
    return message.contains('┌') || 
           message.contains('├') || 
           message.contains('│') || 
           message.contains('└') ||
           message.contains('┄');
  }
  
  /// Check if message is a Flutter framework warning that should be buffered
  bool _isFlutterWarning(String message) {
    // RenderFlex overflow warnings (these come through FlutterError.onError now)
    // Keep this for backward compatibility
    if (message.contains('RenderFlex overflowed by')) {
      return true;
    }
    // Framework exceptions header
    if (message.startsWith('══╡ EXCEPTION CAUGHT BY') || 
        message.contains('══╡ EXCEPTION CAUGHT BY')) {
      return true;
    }
    // Widget library exceptions
    if (message.contains('The following assertion was thrown')) {
      return true;
    }
    // RenderBox layout issues
    if (message.contains('RenderBox was not laid out')) {
      return true;
    }
    // Framework error boundaries
    if (message.startsWith('════════════════════════')) {
      return true;
    }
    return false;
  }
  
  /// Check if message is continuation of Flutter warning
  bool _isFlutterWarningContinuation(String message) {
    // Common patterns in Flutter warning continuations
    if (message.startsWith('The relevant error-causing widget was:')) {
      return true;
    }
    if (message.startsWith('When the exception was thrown')) {
      return true;
    }
    if (message.contains('The overflowing RenderFlex has')) {
      return true;
    }
    if (message.contains('The edge of the RenderFlex')) {
      return true;
    }
    if (message.contains('Consider applying a flex factor')) {
      return true;
    }
    if (message.contains('Another exception was thrown')) {
      return true;
    }
    // Widget tree output
    if (message.trim().startsWith('Widget:') || 
        message.trim().startsWith('RenderObject:') ||
        message.trim().startsWith('Constraints:')) {
      return true;
    }
    // Indented widget tree lines
    if (message.startsWith('  ') && message.contains(':')) {
      return true;
    }
    // End markers
    if (message.startsWith('════════════════════════════════════')) {
      return true;
    }
    return false;
  }
  
  /// Handle Logger package multi-line output
  void _handleLoggerPackageOutput(LogLevel level, String message, {String? error, String? stackTrace}) {
    // Start or continue buffering
    _loggerBufferStartTime ??= DateTime.now();
    _loggerBuffer.add(message);
    
    // Cancel previous timer
    _loggerBufferTimer?.cancel();
    
    // Check if this is the end of a Logger block
    if (message.contains('└')) {
      // This is the end, flush the buffer
      _flushLoggerBuffer();
    } else {
      // Wait a bit for more lines
      _loggerBufferTimer = Timer(const Duration(milliseconds: 50), () {
        _flushLoggerBuffer();
      });
    }
  }
  
  /// Handle Flutter framework warnings (RenderFlex overflow, etc.)
  void _handleFlutterWarning(LogLevel level, String message, {String? error, String? stackTrace}) {
    // If we have a stackTrace passed in (from FlutterError.onError), 
    // use it directly instead of buffering
    if (stackTrace != null && stackTrace.isNotEmpty) {
      // Create log entry directly with the provided stackTrace
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message,
        error: error,
        stackTrace: stackTrace,
      );
      
      _logs.addLast(entry);
      _incrementStats(entry.level);
      if (_logs.length > _config.maxLogs) {
        final evicted = _logs.removeFirst();
        _decrementStats(evicted.level);
      }

      _logController.add(entry);
      MonitoringDataProvider.instance.triggerUpdate();
      return;
    }
    
    // Original buffering logic for warnings from debugPrint
    // Start or continue buffering
    _flutterWarningStartTime ??= DateTime.now();
    _flutterWarningBuffer.add(message);
    
    // Cancel previous timer
    _flutterWarningTimer?.cancel();
    
    // Check if this is likely the end of the warning
    if (message.startsWith('════════════════════════════════════')) {
      // This is the end marker, flush the buffer
      _flushFlutterWarning();
    } else if (!_isFlutterWarningContinuation(message) && _flutterWarningBuffer.length > 1) {
      // This doesn't look like a continuation, flush what we have
      _flushFlutterWarning();
      // Re-process this message as a new log
      _addLog(level, message, error: error, stackTrace: stackTrace);
    } else {
      // Wait a bit for more lines
      _flutterWarningTimer = Timer(const Duration(milliseconds: 100), () {
        _flushFlutterWarning();
      });
    }
  }
  
  /// Flush the Flutter warning buffer as a single log entry
  void _flushFlutterWarning() {
    if (_flutterWarningBuffer.isEmpty) return;
    
    // Combine all lines
    final fullMessage = _flutterWarningBuffer.join('\n');
    
    // Extract the main error message (usually the first line)
    String mainMessage = _flutterWarningBuffer.first;
    
    // For RenderFlex overflow, try to include the widget info
    if (mainMessage.contains('RenderFlex overflowed')) {
      // Look for the widget that caused it
      for (final line in _flutterWarningBuffer) {
        if (line.contains('The relevant error-causing widget was:')) {
          final nextIndex = _flutterWarningBuffer.indexOf(line) + 1;
          if (nextIndex < _flutterWarningBuffer.length) {
            final widgetLine = _flutterWarningBuffer[nextIndex].trim();
            mainMessage = '$mainMessage (Widget: $widgetLine)';
          }
          break;
        }
      }
    }
    
    // Determine level (usually warning for RenderFlex overflow)
    LogLevel detectedLevel = LogLevel.warning;
    if (fullMessage.contains('EXCEPTION CAUGHT') || fullMessage.contains('assertion was thrown')) {
      detectedLevel = LogLevel.error;
    }
    
    // Create a single log entry with full context in stackTrace
    final entry = LogEntry(
      timestamp: _flutterWarningStartTime ?? DateTime.now(),
      level: detectedLevel,
      message: mainMessage,
      error: null,
      stackTrace: fullMessage, // Store full warning for detail view
    );
    
    _logs.addLast(entry);
    _incrementStats(entry.level);
    if (_logs.length > _config.maxLogs) {
      final evicted = _logs.removeFirst();
      _decrementStats(evicted.level);
    }

    _logController.add(entry);

    // Notify MonitoringDataProvider when logs change
    MonitoringDataProvider.instance.triggerUpdate();

    // Clear buffer
    _flutterWarningBuffer.clear();
    _flutterWarningStartTime = null;
    _flutterWarningTimer?.cancel();
    _flutterWarningTimer = null;
  }
  
  /// 智能检测日志级别（优化版）
  /// 使用单次遍历和早期退出策略，提高性能
  LogLevel _detectLogLevel(String message) {
    // 策略1: 检查 Logger 包特有的 emoji 模式
    // Logger 包的 emoji 通常在行首或者紧跟在 │ 后面
    // 格式如: "│ 🐛 Debug message" 或 "┌─ 🐛 Debug"
    if (message.contains('│') || message.contains('├') || message.contains('┌') || message.contains('└')) {
      // 这可能是 Logger 包的输出，检查 emoji
      const debugEmojis = ['🐛', '🔍'];
      const errorEmojis = ['⛔', '❌', '🔴', '👾'];
      const warnEmojis = ['⚠️', '⚠', '🟡'];
      const infoEmojis = ['💡', 'ℹ️', '🔵'];
      const verboseEmojis = ['🔊', '📝'];
      
      // Logger 包的多行输出，emoji 可能在任何一行
      // 检查整个消息中的 emoji（因为确认是 Logger 包格式）
      for (final emoji in debugEmojis) {
        if (message.contains(emoji)) return LogLevel.debug;
      }
      for (final emoji in errorEmojis) {
        if (message.contains(emoji)) return LogLevel.error;
      }
      for (final emoji in warnEmojis) {
        if (message.contains(emoji)) return LogLevel.warning;
      }
      for (final emoji in infoEmojis) {
        if (message.contains(emoji)) return LogLevel.info;
      }
      for (final emoji in verboseEmojis) {
        if (message.contains(emoji)) return LogLevel.verbose;
      }
    }
    
    // 策略2: 使用组合正则表达式一次性匹配多个模式
    const levelPattern = r'\[([EWDIV])\]|^[│\s]*(ERROR|WARN(?:ING)?|DEBUG|INFO|VERBOSE)\s*[:\-│]';
    final combinedPattern = RegExp(levelPattern, caseSensitive: false, multiLine: true);
    final match = combinedPattern.firstMatch(message);
    if (match != null) {
      // 检查是否是方括号格式 [E], [W], etc.
      final bracketLevel = match.group(1);
      if (bracketLevel != null) {
        switch (bracketLevel) {
          case 'E': return LogLevel.error;
          case 'W': return LogLevel.warning;
          case 'D': return LogLevel.debug;
          case 'I': return LogLevel.info;
          case 'V': return LogLevel.verbose;
        }
      }
      
      // 检查是否是前缀格式 ERROR:, WARN:, etc.
      final prefixLevel = match.group(2)?.toUpperCase();
      if (prefixLevel != null) {
        if (prefixLevel.startsWith('ERROR')) return LogLevel.error;
        if (prefixLevel.startsWith('WARN')) return LogLevel.warning;
        if (prefixLevel.startsWith('DEBUG')) return LogLevel.debug;
        if (prefixLevel.startsWith('INFO')) return LogLevel.info;
        if (prefixLevel.startsWith('VERBOSE')) return LogLevel.verbose;
      }
    }
    
    // 策略3: 关键字检查（更严格的上下文匹配）
    
    // 检查是否是异常堆栈（最可靠的错误标识）
    if (message.contains('Exception') && message.contains('at ') && message.contains('.dart:')) {
      return LogLevel.error;
    }
    
    // 检查明确的错误格式（Error: 或 [ERROR]）
    if (RegExp(r'^\s*(error:|exception:|\[error\])', caseSensitive: false).hasMatch(message)) {
      return LogLevel.error;
    }
    
    // 检查明确的警告格式（Warning: 或 [WARN]）
    if (RegExp(r'^\s*(warning:|warn:|\[warn\])', caseSensitive: false).hasMatch(message)) {
      return LogLevel.warning;
    }
    
    // 检查明确的调试格式（Debug: 或 [DEBUG]）
    if (RegExp(r'^\s*(debug:|trace:|\[debug\])', caseSensitive: false).hasMatch(message)) {
      return LogLevel.debug;
    }
    
    // 默认为 info
    return LogLevel.info;
  }
  
  // Compiled regex for ANSI escape sequences - reused for performance
  static final _ansiCodePattern = RegExp(
    r'(?:\x1B\[[0-9;]*m|\[(?:38;5;)?\d+(?:;\d+)*m)',
  );
  
  /// Flush the Logger buffer as a single log entry
  /// 
  /// This method is critical for handling Logger package's multi-line output.
  /// Logger package prints each line separately (with box-drawing characters),
  /// which would create multiple log entries if not properly combined.
  /// 
  /// This method:
  /// 1. Combines all buffered lines into a single log entry
  /// 2. Detects the appropriate log level from emoji/text indicators
  /// 3. Extracts the core message for list display
  /// 4. Preserves full content in stackTrace for detail view
  /// 5. Triggers FAB update via MonitoringDataProvider
  /// 
  /// IMPORTANT: Must call MonitoringDataProvider.instance.triggerUpdate() 
  /// after adding the log, otherwise FAB won't update for Logger package logs.
  void _flushLoggerBuffer() {
    if (_loggerBuffer.isEmpty) return;
    
    // Combine all lines for full content
    final fullMessage = _loggerBuffer.join('\n');
    
    // Detect log level from the combined message
    LogLevel detectedLevel = _detectLogLevel(fullMessage);
    
    // Extract the core message for list display
    String? coreMessage;
    
    // Find the line with emoji or actual log content (not stack trace or timestamps)
    for (final line in _loggerBuffer) {
      // Remove box drawing characters and ANSI codes for checking
      final cleanLine = line
          .replaceAll(RegExp(r'[┌─├│└╟╚╔╗╝═║╠┄]'), '')
          .replaceAll(_ansiCodePattern, '')
          .trim();
      
      if (cleanLine.isEmpty) continue;
      
      // Skip stack trace lines
      if (cleanLine.startsWith('#') || 
          (cleanLine.contains('.dart:') && !cleanLine.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true))) ||
          (cleanLine.contains('package:') && !cleanLine.contains(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true)))) {
        continue;
      }
      
      // Skip timestamp lines (e.g., "16:49:04.562 (+0:00:01.083551)")
      if (RegExp(r'^\d{2}:\d{2}:\d{2}\.\d+').hasMatch(cleanLine)) {
        continue;
      }
      
      // This line likely contains the actual log message
      // Logger package messages often have emojis like 🐛, 💡, ⛔, etc.
      if (cleanLine.contains(RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true)) ||
          (!cleanLine.startsWith('#') && cleanLine.length > 2)) {
        coreMessage = cleanLine;
        break;
      }
    }
    
    // If no core message found, use the first non-empty, non-decoration line
    if (coreMessage == null || coreMessage.isEmpty) {
      for (final line in _loggerBuffer) {
        final cleanLine = line
            .replaceAll(RegExp(r'[┌─├│└╟╚╔╗╝═║╠┄]'), '')
            .replaceAll(_ansiCodePattern, '')
            .trim();
        if (cleanLine.isNotEmpty && !cleanLine.startsWith('#')) {
          coreMessage = cleanLine;
          break;
        }
      }
    }
    
    // Fallback to cleaned full message if still no core message
    if (coreMessage == null || coreMessage.isEmpty) {
      coreMessage = fullMessage
          .replaceAll(RegExp(r'[┌─├│└╟╚╔╗╝═║╠┄]'), '')
          .replaceAll(_ansiCodePattern, '')
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty, orElse: () => 'Logger output');
    }
    
    // Store the original full message, don't clean it here
    // The UI layer will handle display formatting
    
    // Create a single log entry
    // Use core message for display in list, original full content in stackTrace for detail view
    final entry = LogEntry(
      timestamp: _loggerBufferStartTime ?? DateTime.now(),
      level: detectedLevel,
      message: coreMessage,
      error: null,
      stackTrace: fullMessage, // Store original formatted output for detail view
    );
    
    _logs.addLast(entry);
    _incrementStats(entry.level);
    if (_logs.length > _config.maxLogs) {
      final evicted = _logs.removeFirst();
      _decrementStats(evicted.level);
    }

    _logController.add(entry);

    // Notify MonitoringDataProvider when logs change
    // This will trigger FAB update
    MonitoringDataProvider.instance.triggerUpdate();

    // Clear buffer
    _loggerBuffer.clear();
    _loggerBufferStartTime = null;
    _loggerBufferTimer?.cancel();
    _loggerBufferTimer = null;
  }
  
  /// Check if a log should be captured based on config
  bool _shouldCaptureLog(LogLevel level, String message) {
    // Always capture all logs that come through print/Zone
    // System logs (Logcat, NSLog) don't come through here anyway
    // They are printed directly to the platform's logging system
    return true;
  }
  
  // Parse log messages to detect source and level
  _ParsedLog _parseLogMessage(String message) {
    // Check for Logger package format (e.g., "│ ⛔ Error message")
    if (message.contains('│') || message.contains('┌') || message.contains('└') || message.contains('├') || message.contains('┄')) {
      // Logger package format detected
      String cleanMessage = message;
      
      // Remove Logger package decorations but keep the content
      cleanMessage = cleanMessage.replaceAll(RegExp(r'[┌─├│└╟╚╔╗╝═║╠┄]'), '').trim();
      
      // For Logger package, return cleaned message
      if (cleanMessage.isNotEmpty) {
        // Remove ANSI escape sequences from the cleaned message
        cleanMessage = cleanMessage
            .replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '')
            .replaceAll(RegExp(r'\[38;5;\d+m'), '')
            .replaceAll(RegExp(r'\[\d+m'), '')
            .replaceAll('[0m', '');
        
        // 使用统一的日志级别检测方法
        final level = _detectLogLevel(message);
        return _ParsedLog(level: level, message: cleanMessage);
      } else {
        // Only skip if this is purely a Logger decoration line (only contains Logger special chars)
        // Don't skip user's intentional empty prints
        final hasOnlyLoggerChars = RegExp(r'^[┌─├│└╟╚╔╗╝═║╠┄\s]*$').hasMatch(message);
        if (hasOnlyLoggerChars) {
          return _ParsedLog(level: null, message: null, skip: true);
        } else {
          // Keep the message as is (might be intentional empty line from user)
          return _ParsedLog(level: null, message: message);
        }
      }
    }
    
    // 对于非 Logger 包的消息，使用统一的检测方法
    final detectedLevel = _detectLogLevel(message);
    
    // 如果检测到的不是默认的 info，使用检测到的级别
    // 否则返回 null，让调用者使用传入的默认级别
    return _ParsedLog(
      level: detectedLevel != LogLevel.info ? detectedLevel : null, 
      message: message
    );
  }
  
  // Public logging methods - respect user's configuration
  void verbose(String message) => _addLog(LogLevel.verbose, message);
  void debug(String message) => _addLog(LogLevel.debug, message);
  void info(String message) => _addLog(LogLevel.info, message);
  void warning(String message, {String? error}) => _addLog(LogLevel.warning, message, error: error);
  void error(String message, {String? error, String? stackTrace}) {
    _addLog(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }
  
  // Static convenience methods that mirror print
  // These check isEnabled internally through _addLog
  static void log(String message) => instance.info(message);
  static void logDebug(String message) => instance.debug(message);
  static void logError(String message, {Object? error, StackTrace? stackTrace}) {
    instance.error(message, error: error?.toString(), stackTrace: stackTrace?.toString());
  }
  
  void clear() {
    _logs.clear();
    _errorCount = 0;
    _warningCount = 0;
    // Notify MonitoringDataProvider when logs are cleared
    MonitoringDataProvider.instance.triggerUpdate();
  }
  
  void dispose() {
    _logController.close();
  }
  
  /// Toggle pause state
  void togglePause() {
    _isPaused = !_isPaused;
  }
  
  /// Set pause state
  void setPaused(bool paused) {
    _isPaused = paused;
  }
  
  // Filter logs by level
  List<LogEntry> getFilteredLogs({LogLevel? minLevel, String? filter}) {
    var filtered = logs;
    
    if (minLevel != null) {
      filtered = filtered.where((log) => log.level.index >= minLevel.index).toList();
    }
    
    if (filter != null && filter.isNotEmpty) {
      final lowerFilter = filter.toLowerCase();
      filtered = filtered.where((log) => 
        log.message.toLowerCase().contains(lowerFilter) ||
        (log.error?.toLowerCase().contains(lowerFilter) ?? false)
      ).toList();
    }
    
    return filtered;
  }
}

// Helper class for parsed log
class _ParsedLog {
  final LogLevel? level;
  final String? message;
  final bool skip;
  
  _ParsedLog({this.level, required this.message, this.skip = false});
}

// Global convenience function to replace print in dev panel
void devLog(String message) => DevLogger.log(message);

/// Configuration for log capture
class LogCaptureConfig {
  /// Maximum number of logs to keep in memory
  final int maxLogs;
  
  /// Auto scroll to bottom when new logs arrive
  final bool autoScroll;
  
  /// Combine Logger package multi-line output
  final bool combineLoggerOutput;
  
  const LogCaptureConfig({
    this.maxLogs = 1000,
    this.autoScroll = true,
    this.combineLoggerOutput = true,
  });
  
  LogCaptureConfig copyWith({
    int? maxLogs,
    bool? autoScroll,
    bool? combineLoggerOutput,
  }) {
    return LogCaptureConfig(
      maxLogs: maxLogs ?? this.maxLogs,
      autoScroll: autoScroll ?? this.autoScroll,
      combineLoggerOutput: combineLoggerOutput ?? this.combineLoggerOutput,
    );
  }
}