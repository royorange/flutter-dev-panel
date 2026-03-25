import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dev_panel_console/flutter_dev_panel_console.dart';
import 'package:flutter_dev_panel_console/src/ui/pages/console_page.dart';
import 'package:flutter_dev_panel/flutter_dev_panel.dart';

// Simple test context for unit tests
class _TestBuildContext extends BuildContext {
  @override
  bool get debugDoingBuild => false;

  @override
  Widget get widget => Container();

  @override
  bool get mounted => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Note: SharedPreferences warnings in tests are expected and can be ignored.
  // The storage layer handles these exceptions gracefully.
  
  group('ConsoleModule', () {
    test('should have correct properties', () {
      const module = ConsoleModule();
      
      expect(module.name, equals('Console'));
      expect(module.description, equals('查看应用日志和错误信息'));
      expect(module.icon, equals(Icons.terminal));
      expect(module.fabPriority, equals(1));
      expect(module.id, equals('console'));
      expect(module.enabled, isTrue);
      expect(module.order, equals(0)); // Console has highest priority
    });

    test('buildPage returns ConsolePage', () {
      const module = ConsoleModule();
      
      // Just verify that buildPage returns a ConsolePage widget
      final page = module.buildPage(_TestBuildContext());
      expect(page, isA<ConsolePage>());
    });

    test('buildFabContent returns null when paused', () {
      const module = ConsoleModule();
      DevLogger.instance.setPaused(true);
      
      final fabContent = module.buildFabContent(_TestBuildContext());
      expect(fabContent, isNull);
      
      // Cleanup
      DevLogger.instance.setPaused(false);
    });

    test('buildFabContent returns error/warning counts when not paused', () {
      const module = ConsoleModule();
      DevLogger.instance.clear();
      DevLogger.instance.setPaused(false);
      
      // Add some logs
      DevLogger.instance.error('Test error');
      DevLogger.instance.warning('Test warning');
      
      final fabContent = module.buildFabContent(_TestBuildContext());
      expect(fabContent, isNotNull);
      expect(fabContent, isA<Widget>());
    });

    test('buildFabContent returns null when no errors/warnings', () {
      const module = ConsoleModule();
      DevLogger.instance.clear();
      DevLogger.instance.setPaused(false);
      
      // Only add info logs
      DevLogger.instance.info('Test info');
      
      final fabContent = module.buildFabContent(_TestBuildContext());
      expect(fabContent, isNull);
    });

    test('addTestLogs should add various log types', () {
      DevLogger.instance.clear();
      ConsoleModule.addTestLogs();
      
      final logs = DevLogger.instance.logs;
      expect(logs.length, greaterThan(0));
      
      // Check that we have different log levels
      final hasVerbose = logs.any((log) => log.level == LogLevel.verbose);
      final hasDebug = logs.any((log) => log.level == LogLevel.debug);
      final hasInfo = logs.any((log) => log.level == LogLevel.info);
      final hasWarning = logs.any((log) => log.level == LogLevel.warning);
      final hasError = logs.any((log) => log.level == LogLevel.error);
      
      expect(hasVerbose, isTrue);
      expect(hasDebug, isTrue);
      expect(hasInfo, isTrue);
      expect(hasWarning, isTrue);
      expect(hasError, isTrue);
    });
  });

  group('DevLogger', () {
    setUp(() {
      DevLogger.instance.clear();
      DevLogger.instance.setPaused(false);
    });

    test('should capture logs with different levels', () {
      final logger = DevLogger.instance;
      
      // Clear existing logs
      logger.clear();
      
      // Add test logs
      logger.verbose('Test verbose');
      logger.debug('Test debug');
      logger.info('Test info');
      logger.warning('Test warning');
      logger.error('Test error', error: 'Error details');
      
      // Verify logs were captured
      final logs = logger.logs;
      expect(logs.length, equals(5));
      
      // Verify log levels
      expect(logs[0].level, equals(LogLevel.verbose));
      expect(logs[1].level, equals(LogLevel.debug));
      expect(logs[2].level, equals(LogLevel.info));
      expect(logs[3].level, equals(LogLevel.warning));
      expect(logs[4].level, equals(LogLevel.error));
      
      // Verify messages
      expect(logs[0].message, equals('Test verbose'));
      expect(logs[4].error, equals('Error details'));
    });

    test('should handle error objects and stack traces', () {
      final logger = DevLogger.instance;
      logger.clear();
      
      final testError = Exception('Test exception');
      final testStack = StackTrace.current;
      
      logger.error('Error with exception', 
        error: testError.toString(), 
        stackTrace: testStack.toString()
      );
      
      final log = logger.logs.first;
      expect(log.error, equals(testError.toString()));
      expect(log.stackTrace, isNotNull);
      expect(log.stackTrace, contains('flutter_dev_panel_console_test.dart'));
    });

    test('should respect pause state', () {
      final logger = DevLogger.instance;
      logger.clear();
      
      logger.info('Before pause');
      logger.setPaused(true);
      logger.info('During pause');
      logger.setPaused(false);
      logger.info('After pause');
      
      expect(logger.logs.length, equals(2));
      expect(logger.logs[0].message, equals('Before pause'));
      expect(logger.logs[1].message, equals('After pause'));
    });

    test('should respect max logs configuration', () {
      final logger = DevLogger.instance;
      logger.clear();
      
      // Set max logs to 3
      logger.updateConfig(const LogCaptureConfig(maxLogs: 3));
      
      // Add 5 logs
      for (int i = 0; i < 5; i++) {
        logger.info('Log $i');
      }
      
      // Should only have last 3 logs
      expect(logger.logs.length, equals(3));
      expect(logger.logs[0].message, equals('Log 2'));
      expect(logger.logs[1].message, equals('Log 3'));
      expect(logger.logs[2].message, equals('Log 4'));
      
      // Reset config
      logger.updateConfig(const LogCaptureConfig());
    });

    test('should filter logs correctly', () {
      final logger = DevLogger.instance;
      
      // Clear and add test logs
      logger.clear();
      logger.verbose('Verbose message');
      logger.debug('Debug message');
      logger.info('Info message');
      logger.warning('Warning message');
      logger.error('Error message');
      
      // Test filtering by level
      final errorLogs = logger.getFilteredLogs(minLevel: LogLevel.error);
      expect(errorLogs.length, equals(1));
      expect(errorLogs[0].level, equals(LogLevel.error));
      
      // Test filtering by level (warning and above)
      final warningLogs = logger.getFilteredLogs(minLevel: LogLevel.warning);
      expect(warningLogs.length, equals(2));
      
      // Test filtering by text
      final debugLogs = logger.getFilteredLogs(filter: 'Debug');
      expect(debugLogs.length, equals(1));
      expect(debugLogs[0].message, contains('Debug'));
    });

    test('should filter by both level and text', () {
      final logger = DevLogger.instance;
      logger.clear();
      
      logger.verbose('Verbose test');
      logger.debug('Debug test');
      logger.info('Info test');
      logger.warning('Warning test');
      logger.error('Error test');
      logger.error('Error production');
      
      // Filter for errors containing "test"
      final filtered = logger.getFilteredLogs(
        minLevel: LogLevel.error,
        filter: 'test',
      );
      
      expect(filtered.length, equals(1));
      expect(filtered[0].message, equals('Error test'));
    });

    test('should handle case-insensitive text filtering', () {
      final logger = DevLogger.instance;
      logger.clear();
      
      logger.info('TEST message');
      logger.info('test message');
      logger.info('Test Message');
      
      final filtered = logger.getFilteredLogs(filter: 'test');
      expect(filtered.length, equals(3));
    });

    test('should track log timestamps correctly', () {
      final logger = DevLogger.instance;
      logger.clear();
      
      final before = DateTime.now();
      logger.info('Test log');
      final after = DateTime.now();
      
      final log = logger.logs.first;
      expect(log.timestamp.isAfter(before) || log.timestamp.isAtSameMomentAs(before), isTrue);
      expect(log.timestamp.isBefore(after) || log.timestamp.isAtSameMomentAs(after), isTrue);
    });

    test('static log method should work', () {
      DevLogger.instance.clear();
      
      DevLogger.log('Static log message');
      
      expect(DevLogger.instance.logs.length, equals(1));
      expect(DevLogger.instance.logs.first.message, equals('Static log message'));
      expect(DevLogger.instance.logs.first.level, equals(LogLevel.info));
    });

    test('should handle multiline messages', () {
      final logger = DevLogger.instance;
      logger.clear();
      
      const multilineMessage = '''First line
Second line
Third line''';
      
      logger.info(multilineMessage);
      
      expect(logger.logs.length, equals(1));
      expect(logger.logs.first.message, equals(multilineMessage));
    });

    test('clear should remove all logs', () {
      final logger = DevLogger.instance;
      
      logger.info('Log 1');
      logger.info('Log 2');
      expect(logger.logs.length, equals(2));
      
      logger.clear();
      expect(logger.logs.length, equals(0));
    });
  });

  group('LogEntry', () {
    test('should format time correctly', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 1, 1, 12, 34, 56, 789),
        level: LogLevel.info,
        message: 'Test',
      );
      
      expect(entry.formattedTime, equals('12:34:56.789'));
    });

    test('should have correct level text', () {
      expect(LogEntry(timestamp: DateTime.now(), level: LogLevel.verbose, message: '').levelText, 'V');
      expect(LogEntry(timestamp: DateTime.now(), level: LogLevel.debug, message: '').levelText, 'D');
      expect(LogEntry(timestamp: DateTime.now(), level: LogLevel.info, message: '').levelText, 'I');
      expect(LogEntry(timestamp: DateTime.now(), level: LogLevel.warning, message: '').levelText, 'W');
      expect(LogEntry(timestamp: DateTime.now(), level: LogLevel.error, message: '').levelText, 'E');
    });

    test('should have correct colors', () {
      expect(LogEntry(timestamp: DateTime.now(), level: LogLevel.verbose, message: '').color, Colors.grey);
      expect(LogEntry(timestamp: DateTime.now(), level: LogLevel.debug, message: '').color, Colors.blue);
      expect(LogEntry(timestamp: DateTime.now(), level: LogLevel.info, message: '').color, Colors.green);
      expect(LogEntry(timestamp: DateTime.now(), level: LogLevel.warning, message: '').color, Colors.orange);
      expect(LogEntry(timestamp: DateTime.now(), level: LogLevel.error, message: '').color, Colors.red);
    });
  });

  group('LogCaptureConfig', () {
    test('should have correct defaults', () {
      const config = LogCaptureConfig();
      expect(config.maxLogs, equals(1000));
      expect(config.autoScroll, isTrue);
      expect(config.combineLoggerOutput, isTrue);
    });

    test('should support custom maxLogs values', () {
      const minimal = LogCaptureConfig(maxLogs: 500);
      const development = LogCaptureConfig(maxLogs: 1000);
      const full = LogCaptureConfig(maxLogs: 5000);
      expect(minimal.maxLogs, equals(500));
      expect(development.maxLogs, equals(1000));
      expect(full.maxLogs, equals(5000));
    });

    test('copyWith should work correctly', () {
      const original = LogCaptureConfig();
      final modified = original.copyWith(
        maxLogs: 2000,
        autoScroll: false,
      );
      
      expect(modified.maxLogs, equals(2000));
      expect(modified.autoScroll, isFalse);
      expect(modified.combineLoggerOutput, equals(original.combineLoggerOutput));
    });
  });
}