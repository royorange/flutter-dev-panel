library flutter_dev_panel;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Core exports
export 'src/core/dev_panel_controller.dart';
export 'src/core/module_registry.dart';
export 'src/core/monitoring_data_provider.dart';
export 'src/core/dev_logger.dart';
export 'src/core/environment_manager.dart';
export 'src/core/theme_manager.dart';

// API exports
export 'src/api/dev_panel_api.dart';

// Import for internal use in DevPanel class
import 'src/core/environment_manager.dart';
import 'src/core/theme_manager.dart';

// Model exports
export 'src/models/dev_module.dart';
export 'src/models/dev_panel_config.dart';
export 'src/models/panel_settings.dart';

// UI exports
export 'src/ui/dev_panel.dart';
export 'src/ui/dev_panel_wrapper.dart';
export 'src/ui/widgets/shake_detector.dart';
export 'src/ui/widgets/modular_monitoring_fab.dart';
export 'src/ui/widgets/environment_switcher.dart';
export 'src/ui/widgets/theme_switcher.dart';

// Module exports are now separate packages that users install independently:
// - flutter_dev_panel_console
// - flutter_dev_panel_network
// - flutter_dev_panel_device
// - flutter_dev_panel_performance

// Import for internal use
import 'src/flutter_dev_panel_core.dart' as core;
import 'src/models/dev_panel_config.dart';
import 'src/models/dev_module.dart';
import 'src/core/dev_logger.dart' as core;
import 'src/core/module_registry.dart' as core;
import 'src/api/dev_panel_api.dart';

/// 编译时常量，通过 --dart-define=FORCE_DEV_PANEL=true 在生产环境启用
const bool _forceDevPanel = bool.fromEnvironment(
  'FORCE_DEV_PANEL',
  defaultValue: false,
);

/// Flutter开发面板的主入口类
/// 提供更简洁的API访问方式
class DevPanel {
  DevPanel._();

  static bool _initialized = false;

  /// 获取单例实例
  static core.DevPanelCore get instance => core.DevPanelCore.instance;
  
  /// 便捷访问器
  /// 使用 DevPanel.get() 获取 API 访问器，用于访问各模块的 API
  /// 
  /// 示例：
  /// ```dart
  /// DevPanel.get().performance?.startMonitoring();
  /// DevPanel.get().network?.clearRequests();
  /// ```
  static DevPanelAPI get() => DevPanelAPI.instance;

  /// 环境管理器
  static EnvironmentManager get environment => EnvironmentManager.instance;

  /// 主题管理器
  static ThemeManager get theme => ThemeManager.instance;

  /// 获取已注册的模块（类型安全的方式）
  /// 
  /// 示例:
  /// ```dart
  /// // 获取性能模块
  /// final perfModule = DevPanel.getModule<PerformanceModule>();
  /// if (perfModule != null) {
  ///   // 使用模块功能
  /// }
  /// ```
  static T? getModule<T extends DevModule>() {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('DevPanel: Not initialized. Please call DevPanel.initialize() first.');
      }
      return null;
    }
    
    final modules = core.ModuleRegistry.instance.modules;
    try {
      return modules.whereType<T>().firstOrNull;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DevPanel: Module ${T.toString()} not found. '
            'Make sure the module is registered during initialization.');
      }
      return null;
    }
  }
  
  /// 通过 ID 获取模块
  static DevModule? getModuleById(String moduleId) {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('DevPanel: Not initialized. Please call DevPanel.initialize() first.');
      }
      return null;
    }
    
    final module = core.ModuleRegistry.instance.getModule(moduleId);
    if (module == null && kDebugMode) {
      final availableModules = core.ModuleRegistry.instance.modules.map((m) => m.id).join(', ');
      if (availableModules.isNotEmpty) {
        debugPrint('DevPanel: Module "$moduleId" not found. Available modules: $availableModules');
      } else {
        debugPrint('DevPanel: Module "$moduleId" not found. No modules registered.');
      }
    }
    return module;
  }
  
  /// 检查模块是否已安装
  static bool hasModule(String moduleId) {
    if (!_initialized) return false;
    return core.ModuleRegistry.instance.getModule(moduleId) != null;
  }
  
  /// 检查是否已初始化
  static bool get isInitialized => _initialized;

  /// 初始化开发面板
  ///
  /// 默认情况下：
  /// - 调试模式：自动启用
  /// - 生产模式：自动禁用（代码被 tree shaking 优化）
  ///
  /// 如需在生产环境启用，使用：
  /// ```bash
  /// flutter build apk --release --dart-define=FORCE_DEV_PANEL=true
  /// ```
  ///
  /// 示例:
  /// ```dart
  /// void main() {
  ///   DevPanel.initialize(
  ///     modules: [ConsoleModule(), NetworkModule()],
  ///   );
  ///   runApp(MyApp());
  /// }
  /// ```
  static void initialize({
    DevPanelConfig config = const DevPanelConfig(),
    List<DevModule> modules = const [],
    bool enableLogCapture = true,
  }) {
    // 使用编译时常量，支持 tree shaking
    if (kDebugMode || _forceDevPanel) {
      if (_initialized) return;
      _initialized = true;

      core.DevPanelCore.instance.initialize(
        config: config,
        modules: modules,
        enableLogCapture: enableLogCapture,
      );
    }
  }

  /// 打开开发面板（需要BuildContext）
  ///
  /// 注意：context 必须在 MaterialApp/CupertinoApp 内部
  static void open(BuildContext context) {
    if ((kDebugMode || _forceDevPanel) && _initialized) {
      // 检查 Navigator 是否可用
      final navigator = Navigator.maybeOf(context);
      if (navigator == null) {
        debugPrint('DevPanel: Cannot open - No Navigator found in context. '
            'Make sure to call this from within MaterialApp/CupertinoApp.');
        return;
      }
      core.DevPanelCore.instance.open(context);
    }
  }

  /// 关闭开发面板
  static void close() {
    if ((kDebugMode || _forceDevPanel) && _initialized) {
      core.DevPanelCore.instance.close();
    }
  }

  /// 重置开发面板
  static void reset() {
    if ((kDebugMode || _forceDevPanel) && _initialized) {
      core.DevPanelCore.instance.reset();
      _initialized = false;
    }
  }

  /// 初始化并运行应用（类似 Sentry 的模式）
  ///
  /// 这个方法会自动设置 Zone 来拦截所有 print 语句。
  ///
  /// 示例 1 - 最简单使用（使用所有默认值）:
  /// ```dart
  /// void main() async {
  ///   await DevPanel.init(
  ///     () => runApp(const MyApp()),
  ///   );
  /// }
  /// ```
  ///
  /// 示例 2 - 带模块和配置:
  /// ```dart
  /// void main() async {
  ///   await DevPanel.init(
  ///     () => runApp(const MyApp()),
  ///     modules: [ConsoleModule()],
  ///     config: const DevPanelConfig(
  ///       triggerModes: {TriggerMode.fab},
  ///     ),
  ///   );
  /// }
  /// ```
  ///
  /// 示例 3 - 与 Sentry 配合使用:
  /// ```dart
  /// void main() async {
  ///   await SentryFlutter.init(
  ///     (options) {
  ///       options.dsn = 'your-dsn';
  ///     },
  ///     appRunner: () async {
  ///       await DevPanel.init(
  ///         () => runApp(const MyApp()),
  ///         modules: [ConsoleModule()],
  ///       );
  ///     },
  ///   );
  /// }
  /// ```
  static Future<void> init(
    FutureOr<void> Function() appRunner, {
    DevPanelConfig config = const DevPanelConfig(),
    List<DevModule> modules = const [],
    void Function(Object error, StackTrace stack)? onError,
    List<EnvironmentConfig>? environments, // 可选的代码配置环境
  }) async {
    // Shared initialization: binding + environment loading.
    // Must be called inside the Zone that will also call runApp(),
    // otherwise Flutter detects a zone mismatch.
    Future<void> initAndRun() async {
      WidgetsFlutterBinding.ensureInitialized();

      // Environment loading runs in ALL build modes (debug, profile, release).
      // It has zero runtime cost when no environments are configured.
      await _initializeEnvironment(
        config: config,
        environments: environments,
      );

      // Debug UI is gated behind kDebugMode / FORCE_DEV_PANEL
      if (kDebugMode || _forceDevPanel) {
        if (!_initialized) {
          _initialized = true;
          core.DevPanelCore.instance.initialize(
            config: config,
            modules: modules,
            enableLogCapture: config.enableLogCapture,
          );
        }
      }

      await appRunner();
    }

    // Non-debug mode: no Zone needed, run directly
    if (!(kDebugMode || _forceDevPanel)) {
      await initAndRun();
      return;
    }

    // Check if we're already inside a DevPanel Zone
    final hasPrintInterception =
        Zone.current[#_devPanelPrintIntercepted] == true;

    if (hasPrintInterception || !config.enableLogCapture) {
      // Already in a print-intercepting Zone, or log capture disabled
      await initAndRun();
    } else {
      // 创建新的 Zone 来拦截 print
      await runZonedGuarded(
        initAndRun,
        (error, stack) {
          // 延迟记录错误，避免在 binding 初始化前访问 DevLogger
          Future.microtask(() {
            try {
              core.DevLogger.instance.error(
                'Uncaught Error',
                error: error.toString(),
                stackTrace: stack.toString(),
              );
            } catch (_) {
              // 如果 DevLogger 还没准备好，只打印到控制台
              debugPrint('Uncaught Error: $error\n$stack');
            }
          });

          // 调用用户的错误处理器（如果提供）
          onError?.call(error, stack);
        },
        zoneSpecification: _createCombinedZoneSpec(config, modules),
        zoneValues: {
          #_devPanelPrintIntercepted: true,
        },
      );
    }
  }

  /// Initialize environment from .env files and code configuration.
  /// Runs in ALL build modes (debug, profile, release).
  /// Guarded by EnvironmentManager.isInitialized to prevent duplicate calls.
  static Future<void> _initializeEnvironment({
    required DevPanelConfig config,
    List<EnvironmentConfig>? environments,
  }) async {
    if (config.loadFromEnvFiles || environments != null) {
      try {
        await EnvironmentManager.instance.initialize(
          loadFromEnvFiles: config.loadFromEnvFiles,
          environments: environments,
        );
      } catch (e) {
        debugPrint('DevPanel: Environment init failed: $e');
        // Fallback: add environments directly
        if (environments != null && environments.isNotEmpty) {
          for (final env in environments) {
            try {
              EnvironmentManager.instance.addEnvironment(env);
            } catch (addErr) {
              debugPrint('DevPanel: Fallback addEnvironment failed: $addErr');
            }
          }
          try {
            if (environments.any((e) => e.isDefault)) {
              final defaultEnv =
                  environments.firstWhere((e) => e.isDefault);
              EnvironmentManager.instance
                  .switchEnvironment(defaultEnv.name);
            } else if (EnvironmentManager
                .instance.environments.isNotEmpty) {
              EnvironmentManager.instance.switchEnvironment(
                  EnvironmentManager.instance.environments.first.name);
            }
          } catch (switchErr) {
            debugPrint('DevPanel: Fallback switchEnvironment failed: $switchErr');
          }
        }
      }
    }
  }

  /// 创建合并的 ZoneSpecification
  /// 合并 print 拦截和其他模块的 Zone 配置
  static ZoneSpecification _createCombinedZoneSpec(
    DevPanelConfig config,
    List<DevModule> modules,
  ) {
    // print 拦截处理器
    void Function(Zone, ZoneDelegate, Zone, String)? printHandler;
    
    if (config.enableLogCapture) {
      printHandler = (Zone self, ZoneDelegate parent, Zone zone, String line) {
        // 延迟捕获 print，避免在 binding 初始化前访问 DevLogger
        Future.microtask(() {
          try {
            core.DevLogger.instance.info(line);
          } catch (_) {
            // 忽略早期的 print
          }
        });
        // 仍然输出到控制台
        parent.print(zone, line);
      };
    }
    
    // Timer 拦截处理器（用于 Performance 模块的自动追踪）
    Timer Function(Zone, ZoneDelegate, Zone, Duration, void Function())? createTimerHandler;
    Timer Function(Zone, ZoneDelegate, Zone, Duration, void Function(Timer))? createPeriodicTimerHandler;
    
    // 检查是否有 Performance 模块，如果有就启用 Timer 自动追踪
    try {
      // 查找 PerformanceModule（使用动态类型以避免硬依赖）
      final performanceModule = modules.firstWhere(
        (m) => m.id == 'performance',
        orElse: () => throw Exception('No performance module'),
      );
      
      // 通过反射检查是否是 PerformanceModule
      // 由于我们不能直接导入 PerformanceModule，使用动态方式
      final moduleType = performanceModule.runtimeType.toString();
      if (moduleType == 'PerformanceModule') {
        // Performance 模块现在总是启用自动追踪（只要在 Zone 中）
        dynamic dynModule = performanceModule;
        try {
          // 获取 API 实例来创建 Zone
          final api = dynModule.api;
          final zoneSpec = api.createZoneSpecification();
          if (zoneSpec != null) {
            createTimerHandler = zoneSpec.createTimer;
            createPeriodicTimerHandler = zoneSpec.createPeriodicTimer;
            if (kDebugMode) {
              debugPrint('DevPanel: Timer auto-tracking enabled via Zone');
            }
          }
        } catch (e) {
          // 如果无法访问 API，忽略
          if (kDebugMode) {
            debugPrint('DevPanel: Could not enable Timer auto-tracking: $e');
          }
        }
      }
    } catch (_) {
      // 没有 Performance 模块，忽略
    }
    
    // 合并所有处理器
    return ZoneSpecification(
      print: printHandler,
      createTimer: createTimerHandler,
      createPeriodicTimer: createPeriodicTimerHandler,
    );
  }
  
  /// 使用自动 print 拦截运行应用（向后兼容）
  ///
  /// @deprecated 请使用 DevPanel.init 代替
  static void runApp(
    Widget app, {
    DevPanelConfig config = const DevPanelConfig(),
    List<DevModule> modules = const [],
    bool enableLogCapture = true,
    void Function(Object error, StackTrace stack)? onError,
  }) {
    // 如果提供了 enableLogCapture 参数，更新 config
    final finalConfig = enableLogCapture != config.enableLogCapture
        ? config.copyWith(enableLogCapture: enableLogCapture)
        : config;

    init(
      () => runApp(app),
      config: finalConfig,
      modules: modules,
      onError: onError,
    );
  }

  /// 在 Zone 中运行代码并拦截 print
  ///
  /// 这个方法让你可以先完成所有初始化，然后再运行应用。
  ///
  /// 示例:
  /// ```dart
  /// void main() async {
  ///   await DevPanel.runWithZone(() async {
  ///     WidgetsFlutterBinding.ensureInitialized();
  ///
  ///     // 你的初始化代码...
  ///     await initHiveForFlutter();
  ///     await Get.putAsync(() => StorageService().init());
  ///
  ///     // 初始化 Dev Panel
  ///     DevPanel.initialize(
  ///       modules: [ConsoleModule()],
  ///     );
  ///
  ///     // 最后运行应用
  ///     runApp(const MyApp());
  ///   });
  /// }
  /// ```
  static Future<void> runWithZone(
    Future<void> Function() body, {
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    if (!(kDebugMode || _forceDevPanel)) {
      // 在 Release 模式下（且未强制启用），直接运行
      await body();
      return;
    }

    await runZonedGuarded(
      body,
      (error, stack) {
        // 捕获未处理的错误到 Dev Panel
        core.DevLogger.instance.error(
          'Uncaught Error',
          error: error.toString(),
          stackTrace: stack.toString(),
        );

        // 调用用户的错误处理器（如果提供）
        onError?.call(error, stack);
      },
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          // 捕获 print 到 Dev Panel
          core.DevLogger.instance.info(line);
          // 仍然输出到控制台
          parent.print(zone, line);
        },
      ),
    );
  }

  /// 创建一个用于 print 拦截的 ZoneSpecification
  ///
  /// 这个方法提供更灵活的集成方式，让用户可以自己控制 Zone。
  /// 适合与 Sentry、Firebase Crashlytics 等第三方库配合使用。
  ///
  /// 示例 1 - 与 runZonedGuarded 配合:
  /// ```dart
  /// void main() {
  ///   runZonedGuarded(() {
  ///     DevPanel.initialize(modules: [ConsoleModule()]);
  ///     runApp(MyApp());
  ///   }, (error, stack) {
  ///     // 你的错误处理
  ///     Sentry.captureException(error, stackTrace: stack);
  ///   }, zoneSpecification: DevPanel.createZoneSpecification());
  /// }
  /// ```
  ///
  /// 示例 2 - 合并多个 ZoneSpecification:
  /// ```dart
  /// void main() {
  ///   final devPanelSpec = DevPanel.createZoneSpecification();
  ///   final sentrySpec = Sentry.createZoneSpecification();
  ///
  ///   final mergedSpec = ZoneSpecification(
  ///     print: devPanelSpec.print ?? sentrySpec.print,
  ///     // 合并其他处理器...
  ///   );
  ///
  ///   runZonedGuarded(() {
  ///     runApp(MyApp());
  ///   }, handleError, zoneSpecification: mergedSpec);
  /// }
  /// ```
  static ZoneSpecification createZoneSpecification({
    bool enableLogCapture = true,
  }) {
    return ZoneSpecification(
      print: (kDebugMode || _forceDevPanel) && enableLogCapture
          ? (Zone self, ZoneDelegate parent, Zone zone, String line) {
              // 捕获 print 到 Dev Panel
              core.DevLogger.instance.info(line);
              // 继续传递给父 Zone
              parent.print(zone, line);
            }
          : null,
    );
  }

  /// 创建一个 print 拦截的钩子函数
  ///
  /// 这是最灵活的方式，可以在任何 Zone 设置中使用。
  ///
  /// 示例:
  /// ```dart
  /// void main() {
  ///   runZonedGuarded(() {
  ///     runApp(MyApp());
  ///   }, (error, stack) {
  ///     // 错误处理
  ///   }, zoneSpecification: ZoneSpecification(
  ///     print: (self, parent, zone, line) {
  ///       DevPanel.handlePrint(line); // 捕获到 Dev Panel
  ///       // 其他库的处理...
  ///       parent.print(zone, line); // 继续输出
  ///     },
  ///   ));
  /// ```
  static void handlePrint(String line) {
    if (kDebugMode || _forceDevPanel) {
      core.DevLogger.instance.info(line);
    }
  }

  /// 记录日志（统一的日志 API）
  ///
  /// 这些方法会尊重用户的配置：
  /// - 如果 enabled 为 null（默认）：仅在调试模式下记录
  /// - 如果 enabled 为 true：即使在生产环境也记录
  /// - 如果 enabled 为 false：不记录
  ///
  /// 示例:
  /// ```dart
  /// DevPanel.log('User logged in');
  /// DevPanel.logInfo('Request completed');
  /// DevPanel.logWarning('Low memory');
  /// DevPanel.logError('Failed to load', error: e, stackTrace: s);
  /// ```
  static void log(String message) => core.DevLogger.instance.info(message);
  static void logVerbose(String message) =>
      core.DevLogger.instance.verbose(message);
  static void logDebug(String message) =>
      core.DevLogger.instance.debug(message);
  static void logInfo(String message) => core.DevLogger.instance.info(message);
  static void logWarning(String message, {String? error}) =>
      core.DevLogger.instance.warning(message, error: error);
  static void logError(String message,
          {Object? error, StackTrace? stackTrace}) =>
      core.DevLogger.instance.error(
        message,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
      );
}

/// @deprecated 使用 DevPanel 代替
typedef FlutterDevPanel = DevPanel;
