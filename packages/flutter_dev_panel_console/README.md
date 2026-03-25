# Flutter Dev Panel - Console Module

[![pub package](https://img.shields.io/pub/v/flutter_dev_panel_console.svg)](https://pub.dev/packages/flutter_dev_panel_console)

Console/Logs monitoring module for Flutter Dev Panel.

## Features

- Automatic capture of print, debugPrint, and Logger package output
- Log level filtering (verbose, debug, info, warning, error)
- Search and filter capabilities
- Smart multi-line log merging for Logger package
- Configurable log retention and auto-scroll
- FAB display with error/warning count

## Installation

[![flutter_dev_panel version](https://img.shields.io/pub/v/flutter_dev_panel.svg?label=flutter_dev_panel)](https://pub.dev/packages/flutter_dev_panel)

```yaml
dependencies:
  flutter_dev_panel: ^latest_version  # Replace with latest version from badges above
  flutter_dev_panel_console: ^latest_version
```

## Usage

```dart
import 'package:flutter_dev_panel/flutter_dev_panel.dart';
import 'package:flutter_dev_panel_console/flutter_dev_panel_console.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Your initialization code...
  
  // Use DevPanel.init for automatic print interception
  await DevPanel.init(
    () => runApp(const MyApp()),
    modules: [
      ConsoleModule(
        logConfig: const LogCaptureConfig(
          maxLogs: 1000,              // Optional: customize log settings
          autoScroll: true,
          combineLoggerOutput: true,
        ),
      ),
      // Other modules...
    ],
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return DevPanelWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: MyHomePage(),
    );
  }
}
```

## Log Capture

The console module automatically captures:
- Standard `print()` statements
- `debugPrint()` output
- Logger package logs (with smart multi-line merging)
- Flutter framework errors

## Logger Package Integration

Flutter Dev Panel automatically captures output from the [logger](https://pub.dev/packages/logger) package when using `ConsoleOutput`!

### Automatic Capture with DevPanel.init (Simplest)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use DevPanel.init to automatically set up Zone
  await DevPanel.init(
    () => runApp(const MyApp()),
    modules: [
      ConsoleModule(), // Use default config
      // Or with custom config:
      // ConsoleModule(
      //   logConfig: const LogCaptureConfig(maxLogs: 500),
      // ),
    ],
  );
}

// Then Logger output is automatically captured:
final logger = Logger(
  printer: PrettyPrinter(),
  // output: ConsoleOutput(), // Default, uses print() internally
);

logger.i("Info message"); // Automatically captured!
logger.e("Error message"); // Automatically captured!
```

### Manual Zone Setup (Alternative)

If you prefer to set up the Zone manually:

```dart
void main() {
  runZonedGuarded(() {
    // Initialize Dev Panel first
    DevPanel.initialize(
      modules: [
        ConsoleModule(
          logConfig: const LogCaptureConfig(
            maxLogs: 1000,
            autoScroll: true,
          ),
        ),
      ],
    );
    
    // Your app initialization
    runApp(MyApp());
  }, (error, stack) {
    // Error handling
    DevPanel.logError('Uncaught error', error: error, stackTrace: stack);
  }, zoneSpecification: ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      DevPanel.log(line); // Use the unified API
      parent.print(zone, line); // Still print to console
    },
  ));
}
```

### Why it works

- `ConsoleOutput` (Logger's default) uses `print()` internally
- Dev Panel intercepts `print()` statements via Zone
- Logger's formatted output is automatically captured and displayed

### Advanced: Custom capture for other LogOutputs

If you use `FileOutput` or custom LogOutput, you can manually capture:

```dart
import 'package:logger/logger.dart';
import 'package:flutter_dev_panel_console/flutter_dev_panel_console.dart';

class DevPanelLogOutput extends LogOutput {
  final LogOutput baseOutput;
  
  DevPanelLogOutput({LogOutput? baseOutput}) 
    : baseOutput = baseOutput ?? ConsoleOutput();
  
  @override
  void output(OutputEvent event) {
    baseOutput.output(event);
    DevPanelLogger.capture(event); // Manual capture
  }
  
  @override
  Future<void> destroy() async {
    await baseOutput.destroy();
  }
}


Features:
- **No dependency**: Console module doesn't depend on logger package
- **No version conflicts**: Works with any logger version
- **Zero overhead**: No extra packages for non-logger users
- **Debug mode**: Logs appear in both console AND Dev Panel
- **Release mode**: Only outputs to console (zero overhead)
- **Customizable**: Can pass any LogOutput as base

## Configuration

```dart
// Configure via ConsoleModule initialization
await DevPanel.init(
  () => runApp(MyApp()),
  modules: [
    ConsoleModule(
      logConfig: const LogCaptureConfig(
        maxLogs: 1000,              // Maximum logs to keep (default: 1000)
        autoScroll: true,           // Auto-scroll to latest log (default: true)
        combineLoggerOutput: true,  // Combine Logger package multi-line output (default: true)
      ),
    ),
  ],
  config: const DevPanelConfig(
    enableLogCapture: true,  // Enable print interception (default: true)
  ),
);

// Or simply use defaults
ConsoleModule()  // Default: maxLogs=1000, autoScroll=true, combineLoggerOutput=true
```

## License

MIT