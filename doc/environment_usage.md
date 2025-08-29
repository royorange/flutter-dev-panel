# Environment Variables Usage Guide

Flutter Dev Panel provides powerful environment management capabilities, supporting various ways to get and listen to environment variables.

## Convenience Methods (Recommended)

No need to specify generics, cleaner code:

```dart
// Get string
final apiUrl = DevPanel.environment.getString('api_url');
final apiUrl = DevPanel.environment.getString('api_url', defaultValue: 'https://api.example.com');

// Get boolean
final isDebug = DevPanel.environment.getBool('debug');
final isDebug = DevPanel.environment.getBool('debug', defaultValue: false);

// Get integer (supports parsing from string)
final timeout = DevPanel.environment.getInt('timeout');
final timeout = DevPanel.environment.getInt('timeout', defaultValue: 30000);

// Get double (supports conversion from integer)
final version = DevPanel.environment.getDouble('version');
final version = DevPanel.environment.getDouble('version', defaultValue: 1.0);

// Get list
final servers = DevPanel.environment.getList<String>('servers');
final servers = DevPanel.environment.getList<String>('servers', defaultValue: ['server1']);

// Get Map
final config = DevPanel.environment.getMap('database');
final config = DevPanel.environment.getMap('database', defaultValue: {'host': 'localhost'});
```

## Generic Methods (Flexible)

Use when you need to get special types:

```dart
// Generic method
final apiUrl = DevPanel.environment.getVariable<String>('api_url');
final timeout = DevPanel.environment.getVariable<int>('timeout', defaultValue: 10000);
final customObject = DevPanel.environment.getVariable<MyConfig>('config');
```

## Listen to Environment Changes

### Method 1: Using addListener

```dart
class _MyScreenState extends State<MyScreen> {
  String _apiUrl = '';
  
  @override
  void initState() {
    super.initState();
    _updateConfig();
    DevPanel.environment.addListener(_updateConfig);
  }
  
  void _updateConfig() {
    setState(() {
      _apiUrl = DevPanel.environment.getString('api_url') ?? '';
    });
  }
  
  @override
  void dispose() {
    DevPanel.environment.removeListener(_updateConfig);
    super.dispose();
  }
}
```

### Method 2: Using ListenableBuilder

```dart
@override
Widget build(BuildContext context) {
  return ListenableBuilder(
    listenable: DevPanel.environment,
    builder: (context, _) {
      final apiUrl = DevPanel.environment.getString('api_url');
      final isDebug = DevPanel.environment.getBool('debug') ?? false;
      
      return Column(
        children: [
          Text('API: $apiUrl'),
          if (isDebug) Text('Debug Mode'),
        ],
      );
    },
  );
}
```

## Practical Usage Examples

### Configuration Service

```dart
class AppConfig {
  // Using convenience methods for cleaner code
  static String get apiUrl => 
    DevPanel.environment.getString('api_url') ?? 'https://api.example.com';
  
  static String get apiKey => 
    DevPanel.environment.getString('api_key') ?? '';
  
  static bool get isDebugMode => 
    DevPanel.environment.getBool('debug') ?? false;
  
  static int get requestTimeout => 
    DevPanel.environment.getInt('timeout') ?? 10000;
  
  static List<String> get servers => 
    DevPanel.environment.getList<String>('servers') ?? [];
  
  static Map<String, dynamic> get databaseConfig => 
    DevPanel.environment.getMap('database') ?? {
      'host': 'localhost',
      'port': 5432,
      'name': 'default_db',
    };
}
```

### Dio Configuration Example

```dart
class ApiService {
  late Dio _dio;
  
  ApiService() {
    _dio = Dio();
    _updateDioConfig();
    
    // Listen to environment changes, automatically update configuration
    DevPanel.environment.addListener(_updateDioConfig);
  }
  
  void _updateDioConfig() {
    final apiUrl = DevPanel.environment.getString('api_url');
    final timeout = DevPanel.environment.getInt('timeout') ?? 10000;
    final apiKey = DevPanel.environment.getString('api_key');
    
    _dio.options = BaseOptions(
      baseUrl: apiUrl ?? 'https://api.example.com',
      connectTimeout: Duration(milliseconds: timeout),
      headers: {
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
      },
    );
  }
}
```

### Complete Application Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dev_panel/flutter_dev_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize environment configuration
  await DevPanel.environment.initialize(
    environments: [
      const EnvironmentConfig(
        name: 'Development',
        variables: {
          'api_url': 'https://dev-api.example.com',
          'api_key': 'dev-key-123',
          'debug': true,
          'timeout': 30000,
          'theme_mode': 'dark',
        },
        isDefault: true,
      ),
      const EnvironmentConfig(
        name: 'Production',
        variables: {
          'api_url': 'https://api.example.com',
          'api_key': '', // Inject via --dart-define
          'debug': false,
          'timeout': 10000,
          'theme_mode': 'light',
        },
      ),
    ],
  );
  
  DevPanel.initialize(modules: []);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DevPanel.environment,
      builder: (context, _) {
        // Dynamically adjust app behavior based on environment variables
        final isDarkMode = DevPanel.environment.getString('theme_mode') == 'dark';
        final appTitle = DevPanel.environment.currentEnvironment?.name ?? 'App';
        
        return MaterialApp(
          title: appTitle,
          theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
          home: DevPanelWrapper(child: HomePage()),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Environment Demo'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => DevPanel.open(context),
          ),
        ],
      ),
      body: Center(
        child: ListenableBuilder(
          listenable: DevPanel.environment,
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Environment: ${DevPanel.environment.currentEnvironment?.name}'),
                Text('API: ${DevPanel.environment.getString('api_url')}'),
                Text('Debug: ${DevPanel.environment.getBool('debug')}'),
                Text('Timeout: ${DevPanel.environment.getInt('timeout')}ms'),
                
                SizedBox(height: 20),
                
                ElevatedButton(
                  onPressed: () {
                    // Switch environment
                    final current = DevPanel.environment.currentEnvironment?.name;
                    final newEnv = current == 'Development' ? 'Production' : 'Development';
                    DevPanel.environment.switchEnvironment(newEnv);
                  },
                  child: Text('Switch Environment'),
                ),
                
                if (DevPanel.environment.getBool('debug') ?? false)
                  Container(
                    margin: EdgeInsets.only(top: 20),
                    padding: EdgeInsets.all(10),
                    color: Colors.yellow.withOpacity(0.3),
                    child: Text('Debug Mode Enabled'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

## Type Conversion

Convenience methods support intelligent type conversion:

### getInt Conversion Rules
- `int` → Returns directly
- `String` → Attempts to parse ("123" → 123)
- `double` → Converts to integer (10.5 → 10)

### getDouble Conversion Rules
- `double` → Returns directly
- `int` → Converts to double (10 → 10.0)
- `String` → Attempts to parse ("10.5" → 10.5)

### getBool Conversion Rules
- `bool` → Returns directly
- Other types → Returns default value

## API Reference

### Convenience Methods
```dart
String? getString(String key, {String? defaultValue})
bool? getBool(String key, {bool? defaultValue})
int? getInt(String key, {int? defaultValue})
double? getDouble(String key, {double? defaultValue})
List<T>? getList<T>(String key, {List<T>? defaultValue})
Map<String, dynamic>? getMap(String key, {Map<String, dynamic>? defaultValue})
```

### Generic Methods
```dart
T? getVariable<T>(String key, {T? defaultValue})
```

### Environment Management
```dart
// Get current environment
EnvironmentConfig? get currentEnvironment

// Switch environment
void switchEnvironment(String name)

// Update variable
void updateVariable(String key, dynamic value)

// Listen to changes
void addListener(VoidCallback listener)
void removeListener(VoidCallback listener)
```

## Best Practices

1. **Use convenience methods**: Prefer `getString`, `getBool` and other convenience methods for cleaner code
2. **Provide default values**: Always provide reasonable default values to avoid null exceptions
3. **Listen to changes**: Use `ListenableBuilder` to automatically respond to environment changes
4. **Lifecycle management**: Remember to remove listeners in `dispose()`
5. **Type safety**: Use specific type methods instead of `dynamic`