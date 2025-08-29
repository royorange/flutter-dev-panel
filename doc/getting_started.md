# Getting Started

## Installation

### Option 1: Core Package Only (Minimal)

```yaml
dependencies:
  flutter_dev_panel: ^1.0.1
```

### Option 2: With Specific Modules (Recommended)

```yaml
dependencies:
  flutter_dev_panel: ^1.0.1
  flutter_dev_panel_console: ^1.0.1    # Logging features
  flutter_dev_panel_network: ^1.0.1    # Network monitoring
  # Add only the modules you need
```

### Option 3: All Modules

```yaml
dependencies:
  flutter_dev_panel: ^1.0.1
  flutter_dev_panel_console: ^1.0.1
  flutter_dev_panel_network: ^1.0.1
  flutter_dev_panel_device: ^1.0.1
  flutter_dev_panel_performance: ^1.0.1
```

## Quick Start

> **Important**: Choose the right initialization method based on your needs:
> - **Method 1**: Automatic setup with full features ✅ (Recommended)
>   - Auto-captures print/debugPrint for Console module
>   - Auto-tracks Timers for Performance module
>   - Handles all Zone setup automatically
> - **Method 2**: Custom Zone setup for integration with other tools 🔧
>   - Use when integrating with Sentry/Crashlytics
>   - Requires manual Zone configuration
> - **Method 3**: Traditional initialization with limited features ⚠️
>   - No automatic print capture
>   - No automatic Timer tracking
>   - Only for compatibility with existing codebases

### Method 1: Using DevPanel.init (Recommended)

Automatically sets up Zone to intercept print statements and handles all initialization properly. **No need to call `WidgetsFlutterBinding.ensureInitialized()` manually**.

```dart
import 'package:flutter_dev_panel/flutter_dev_panel.dart';
// Import the modules you need
import 'package:flutter_dev_panel_console/flutter_dev_panel_console.dart';
import 'package:flutter_dev_panel_network/flutter_dev_panel_network.dart';

void main() async {
  await DevPanel.init(
    () => runApp(const MyApp()),
    modules: [
      const ConsoleModule(),
      NetworkModule(),
      const DeviceModule(),
      const PerformanceModule(),  // Automatically tracks Timers when in Zone
    ],
  );
}

// Or with custom initialization
void main() async {
  await DevPanel.init(
    () async {
      // DevPanel.init automatically calls WidgetsFlutterBinding.ensureInitialized()
      // You don't need to call it manually
      
      // Your initialization code
      await initServices();
      await setupDependencies();
      
      // Listen to environment changes
      DevPanel.environment.addListener(() {
        final apiUrl = DevPanel.environment.getString('API_URL');
        // Update your services with new URL
      });
      
      runApp(const MyApp());
    },
    config: const DevPanelConfig(
      triggerModes: {TriggerMode.fab, TriggerMode.shake},
      loadFromEnvFiles: true,  // Auto-load .env files (default: true)
    ),
    modules: [
      const ConsoleModule(),
      NetworkModule(),
    ],
  );
}
```

### Method 2: Custom Zone Setup (With Sentry/Crashlytics)

For integration with error tracking services like Sentry or Firebase Crashlytics.

```dart
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize your services
    await initServices();
    
    // Initialize Dev Panel
    DevPanel.initialize(
      modules: [ConsoleModule(), NetworkModule()],
    );
    
    runApp(const MyApp());
  }, (error, stack) {
    // Send to multiple services
    DevPanel.logError('Uncaught error', error: error, stackTrace: stack);
    Sentry.captureException(error, stackTrace: stack);
  }, zoneSpecification: ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      DevPanel.log(line);  // Capture to Dev Panel
      parent.print(zone, line);    // Still print to console
    },
  ));
}
```

### Method 3: Traditional Initialization (Limited Features)

**⚠️ Warning**: This method has significant limitations:
- ❌ Does NOT capture print/debugPrint statements (Console module)
- ❌ Does NOT auto-track Timers (Performance module)
- ❌ Requires manual Zone setup for full functionality
- ⚠️ Only use if you cannot modify your app's entry point

**Note**: Console module will only show logs from direct `DevPanel.log()` calls, and Performance module cannot auto-track Timers.

```dart
import 'package:flutter_dev_panel/flutter_dev_panel.dart';
// Import the modules you need
import 'package:flutter_dev_panel_console/flutter_dev_panel_console.dart';
import 'package:flutter_dev_panel_network/flutter_dev_panel_network.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dev panel with selected modules
  DevPanel.initialize(
    modules: [
      const ConsoleModule(),
      NetworkModule(),
      // Add more modules as needed
    ],
  );
  
  runApp(MyApp());
}
```

## Integration with App

### Using Builder Pattern (Recommended)

```dart
// Works with MaterialApp, GetMaterialApp, etc.
MaterialApp(
  builder: (context, child) {
    return DevPanelWrapper(
      child: child ?? const SizedBox.shrink(),
    );
  },
  home: MyHomePage(),
)
```

The builder pattern works with:
- GetX (`GetMaterialApp`)
- Auto Route navigation
- Apps with complex navigation setup
- Global overlay requirements

### Access the Panel

- **Floating Button**: Tap the FAB (default)
- **Shake Gesture**: Shake the device (mobile only)  
- **Programmatic**: `DevPanel.open(context)`

## Theme Integration

If your app already has theme management, you can sync it with the dev panel:

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;
  
  @override
  void initState() {
    super.initState();
    // Load your app's saved theme preference
    _themeMode = MyThemePreferences.getThemeMode();
    
    // Sync dev panel with your app's theme
    ThemeManager.instance.setThemeMode(_themeMode);
    
    // Listen to dev panel theme changes
    ThemeManager.instance.themeMode.addListener(_onThemeChanged);
  }
  
  void _onThemeChanged() {
    setState(() {
      _themeMode = ThemeManager.instance.themeMode.value;
      // Save to your app's preferences
      MyThemePreferences.saveThemeMode(_themeMode);
    });
  }
  
  @override
  void dispose() {
    ThemeManager.instance.themeMode.removeListener(_onThemeChanged);
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: MyHomePage(),
    );
  }
}
```

This approach:
- Loads your existing theme preference on startup
- Syncs the dev panel with your app's current theme
- Updates your app's preferences when changed via dev panel
- Maintains consistency between your app and dev panel themes