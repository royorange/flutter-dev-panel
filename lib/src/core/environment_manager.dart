import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'env_loader.dart';

/// Environment configuration
class EnvironmentConfig {
  final String name;
  final Map<String, dynamic> variables;
  final bool isDefault;

  const EnvironmentConfig({
    required this.name,
    required this.variables,
    this.isDefault = false,
  });

  factory EnvironmentConfig.fromJson(Map<String, dynamic> json) {
    return EnvironmentConfig(
      name: json['name'] as String,
      variables: Map<String, dynamic>.from(json['variables'] as Map),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'variables': variables,
      'isDefault': isDefault,
    };
  }

  EnvironmentConfig copyWith({
    String? name,
    Map<String, dynamic>? variables,
    bool? isDefault,
  }) {
    return EnvironmentConfig(
      name: name ?? this.name,
      variables: variables ?? this.variables,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// Environment manager singleton
class EnvironmentManager extends ChangeNotifier {
  static EnvironmentManager? _instance;
  static EnvironmentManager get instance {
    _instance ??= EnvironmentManager._();
    return _instance!;
  }

  EnvironmentManager._() {
    _loadEnvironments();
  }

  // Whether initialize() has been called
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Current environment
  EnvironmentConfig? _currentEnvironment;
  EnvironmentConfig? get currentEnvironment => _currentEnvironment;

  // Available environments
  final List<EnvironmentConfig> _environments = [];
  List<EnvironmentConfig> get environments => List.unmodifiable(_environments);

  // Storage key
  static const String _storageKey = 'dev_panel_environments';
  static const String _currentEnvKey = 'dev_panel_current_env';

  /// Initialize with environments from multiple sources
  /// Priority: --dart-define > .env files > code configuration > saved configuration
  Future<void> initialize({
    List<EnvironmentConfig>? environments,
    String? defaultEnvironment,
    bool loadFromEnvFiles = true,
  }) async {
    // Prevent duplicate initialization
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Load from .env files first
    List<EnvironmentConfig>? envFileConfigs;
    if (loadFromEnvFiles) {
      try {
        envFileConfigs = await EnvLoader.loadFromEnvFiles();
        if (envFileConfigs != null && envFileConfigs.isNotEmpty) {
          debugPrint('Loaded ${envFileConfigs.length} environments from .env files');
        }
      } catch (e) {
        debugPrint('Failed to load .env files: $e');
      }
    }
    
    // Load saved configuration
    List<EnvironmentConfig>? savedConfigs;
    try {
      final prefs = await SharedPreferences.getInstance();
      final envsJson = prefs.getString(_storageKey);
      if (envsJson != null) {
        final List<dynamic> envsList = jsonDecode(envsJson) as List<dynamic>;
        savedConfigs = envsList
            .map((json) => EnvironmentConfig.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to load saved environments: $e');
    }
    
    // Merge environments from all sources
    final baseEnvs = EnvLoader.mergeEnvironments(
      fromEnvFiles: envFileConfigs,
      fromCode: environments,
      fromStorage: savedConfigs,
    );
    
    // Collect all unique keys from all merged environments
    final allKeys = <String>{};
    for (final env in baseEnvs) {
      allKeys.addAll(env.variables.keys);
    }
    
    // Load from --dart-define (highest priority) using discovered keys
    final dartDefineVars = _loadFromDartDefine(allKeys.toList());
    if (dartDefineVars.isNotEmpty) {
      debugPrint('Loaded ${dartDefineVars.length} variables from --dart-define');
    }
    
    // Apply dart-define overrides
    final mergedEnvs = _mergeWithDartDefine(baseEnvs, dartDefineVars);
    
    if (mergedEnvs.isNotEmpty) {
      _environments.clear();
      _environments.addAll(mergedEnvs);
      
      // Set default environment
      if (defaultEnvironment != null) {
        final env = _environments.firstWhere(
          (e) => e.name == defaultEnvironment,
          orElse: () => _environments.first,
        );
        _currentEnvironment = env;
      } else {
        // Try to restore previously selected environment
        final prefs = await SharedPreferences.getInstance();
        final lastEnvName = prefs.getString(_currentEnvKey);
        if (lastEnvName != null) {
          final lastEnv = _environments.firstWhere(
            (e) => e.name == lastEnvName,
            orElse: () => _environments.firstWhere(
              (e) => e.isDefault,
              orElse: () => _environments.first,
            ),
          );
          _currentEnvironment = lastEnv;
        } else {
          // Use the one marked as default or the first one
          _currentEnvironment = _environments.firstWhere(
            (e) => e.isDefault,
            orElse: () => _environments.first,
          );
        }
      }
      
      _saveEnvironments();
      notifyListeners();
    } else if (environments == null || environments.isEmpty) {
      // No environments provided, try to create from .env files only
      debugPrint('No environments configured. Please provide environments or create .env files.');
    }
  }


  /// Load environments from storage
  Future<void> _loadEnvironments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load environments
      final envsJson = prefs.getString(_storageKey);
      if (envsJson != null) {
        final List<dynamic> envsList = jsonDecode(envsJson) as List<dynamic>;
        _environments.clear();
        for (final json in envsList) {
          _environments.add(
            EnvironmentConfig.fromJson(json as Map<String, dynamic>),
          );
        }
      }

      // Load current environment
      final currentEnvName = prefs.getString(_currentEnvKey);
      if (currentEnvName != null && _environments.isNotEmpty) {
        _currentEnvironment = _environments.firstWhere(
          (e) => e.name == currentEnvName,
          orElse: () => _environments.first,
        );
      }

      // If no environments loaded, leave empty
      // User should initialize with their own environments

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load environments: $e');
      // Leave empty on error
      // User should initialize with their own environments
    }
  }

  /// Save environments to storage
  Future<void> _saveEnvironments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save environments
      final envsList = _environments.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(envsList));

      // Save current environment
      if (_currentEnvironment != null) {
        await prefs.setString(_currentEnvKey, _currentEnvironment!.name);
      }
    } catch (e) {
      debugPrint('Failed to save environments: $e');
    }
  }

  /// Switch to a different environment
  void switchEnvironment(String name) {
    // Handle case where saved environment no longer exists
    EnvironmentConfig? env;
    try {
      env = _environments.firstWhere((e) => e.name == name);
    } catch (e) {
      debugPrint('Environment "$name" not found, falling back to first available');
      if (_environments.isNotEmpty) {
        env = _environments.first;
      }
    }
    
    if (env != null && _currentEnvironment != env) {
      _currentEnvironment = env;
      _saveEnvironments();
      notifyListeners();
    }
  }

  /// Add a new environment
  void addEnvironment(EnvironmentConfig environment) {
    // Check if name already exists
    if (_environments.any((e) => e.name == environment.name)) {
      throw Exception('Environment with name ${environment.name} already exists');
    }
    
    _environments.add(environment);
    _saveEnvironments();
    notifyListeners();
  }

  /// Update an existing environment
  void updateEnvironment(String name, EnvironmentConfig newConfig) {
    final index = _environments.indexWhere((e) => e.name == name);
    if (index != -1) {
      _environments[index] = newConfig;
      
      // Update current if it's the same
      if (_currentEnvironment?.name == name) {
        _currentEnvironment = newConfig;
      }
      
      _saveEnvironments();
      notifyListeners();
    }
  }

  /// Remove an environment
  void removeEnvironment(String name) {
    // Can't remove if it's the only one
    if (_environments.length <= 1) {
      throw Exception('Cannot remove the last environment');
    }
    
    _environments.removeWhere((e) => e.name == name);
    
    // If current was removed, switch to first
    if (_currentEnvironment?.name == name) {
      _currentEnvironment = _environments.first;
    }
    
    _saveEnvironments();
    notifyListeners();
  }

  /// Get a variable from current environment with optional default value
  /// 
  /// Example:
  /// ```dart
  /// // Without default value (returns null if not found)
  /// final apiUrl = EnvironmentManager.instance.getVariable<String>('API_URL');
  /// 
  /// // With default value
  /// final apiUrl = EnvironmentManager.instance.getVariable<String>(
  ///   'API_URL', 
  ///   defaultValue: 'https://api.example.com'
  /// );
  /// ```
  T? getVariable<T>(String key, {T? defaultValue}) {
    final value = _currentEnvironment?.variables[key];
    if (value != null) {
      return value as T;
    }
    return defaultValue;
  }

  /// Get a variable with a required default value (deprecated, use getVariable with defaultValue)
  @Deprecated('Use getVariable with defaultValue parameter instead')
  T getVariableOrDefault<T>(String key, T defaultValue) {
    return getVariable<T>(key, defaultValue: defaultValue) ?? defaultValue;
  }
  
  /// Convenience methods for common types without generics
  
  /// Get a String variable (nullable)
  /// 
  /// Example:
  /// ```dart
  /// final apiUrl = DevPanel.environment.getString('api_url');
  /// ```
  String? getString(String key) {
    return getVariable<String>(key);
  }
  
  /// Get a String variable with default value (non-null)
  /// 
  /// Example:
  /// ```dart
  /// final apiUrl = DevPanel.environment.getStringOr('api_url', 'https://api.example.com');
  /// ```
  String getStringOr(String key, String defaultValue) {
    return getVariable<String>(key) ?? defaultValue;
  }
  
  /// Get a bool variable (nullable)
  /// 
  /// Example:
  /// ```dart
  /// final isDebug = DevPanel.environment.getBool('debug');
  /// ```
  bool? getBool(String key) {
    return getVariable<bool>(key);
  }
  
  /// Get a bool variable with default value (non-null)
  /// 
  /// Example:
  /// ```dart
  /// final isDebug = DevPanel.environment.getBoolOr('debug', false);
  /// ```
  bool getBoolOr(String key, bool defaultValue) {
    return getVariable<bool>(key) ?? defaultValue;
  }
  
  /// Get an int variable (nullable)
  /// 
  /// Example:
  /// ```dart
  /// final timeout = DevPanel.environment.getInt('timeout');
  /// ```
  int? getInt(String key) {
    final value = _currentEnvironment?.variables[key];
    if (value != null) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
    }
    return null;
  }
  
  /// Get an int variable with default value (non-null)
  /// 
  /// Example:
  /// ```dart
  /// final timeout = DevPanel.environment.getIntOr('timeout', 30000);
  /// ```
  int getIntOr(String key, int defaultValue) {
    final value = _currentEnvironment?.variables[key];
    if (value != null) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      if (value is double) return value.toInt();
    }
    return defaultValue;
  }
  
  /// Get a double variable (nullable)
  /// 
  /// Example:
  /// ```dart
  /// final version = DevPanel.environment.getDouble('version');
  /// ```
  double? getDouble(String key) {
    final value = _currentEnvironment?.variables[key];
    if (value != null) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }
  
  /// Get a double variable with default value (non-null)
  /// 
  /// Example:
  /// ```dart
  /// final version = DevPanel.environment.getDoubleOr('version', 1.0);
  /// ```
  double getDoubleOr(String key, double defaultValue) {
    final value = _currentEnvironment?.variables[key];
    if (value != null) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }
  
  /// Get a List variable (nullable)
  /// 
  /// Example:
  /// ```dart
  /// final servers = DevPanel.environment.getList<String>('servers');
  /// ```
  List<T>? getList<T>(String key) {
    final value = _currentEnvironment?.variables[key];
    if (value != null && value is List) {
      return value.cast<T>();
    }
    return null;
  }
  
  /// Get a List variable with default value (non-null)
  /// 
  /// Example:
  /// ```dart
  /// final servers = DevPanel.environment.getListOr<String>('servers', ['server1']);
  /// ```
  List<T> getListOr<T>(String key, List<T> defaultValue) {
    final value = _currentEnvironment?.variables[key];
    if (value != null && value is List) {
      return value.cast<T>();
    }
    return defaultValue;
  }
  
  /// Get a Map variable
  /// 
  /// Example:
  /// ```dart
  /// final config = DevPanel.environment.getMap('config');
  /// final config = DevPanel.environment.getMap('config', defaultValue: {'key': 'value'});
  /// ```
  Map<String, dynamic>? getMap(String key, {Map<String, dynamic>? defaultValue}) {
    final value = _currentEnvironment?.variables[key];
    if (value != null && value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return defaultValue;
  }

  /// Update a variable in current environment
  void updateVariable(String key, dynamic value) {
    if (_currentEnvironment != null) {
      final newVars = Map<String, dynamic>.from(_currentEnvironment!.variables);
      newVars[key] = value;
      
      final newEnv = _currentEnvironment!.copyWith(variables: newVars);
      updateEnvironment(_currentEnvironment!.name, newEnv);
    }
  }

  /// Clear all environments
  void clear() {
    _environments.clear();
    _currentEnvironment = null;
    _isInitialized = false;
    _saveEnvironments();
    notifyListeners();
  }
  
  /// Load variables from --dart-define
  /// 
  /// Due to Dart's compile-time constant limitation, we must know
  /// the key names in advance. We check all keys defined in your
  /// environment configurations.
  Map<String, dynamic> _loadFromDartDefine(List<String> keysToCheck) {
    final vars = <String, dynamic>{};
    
    // Check each key from the environment configurations
    for (final key in keysToCheck) {
      // Try multiple variations of the key
      final variations = [
        key,  // Original key
        key.toUpperCase(),  // UPPERCASE
        key.toLowerCase(),  // lowercase
        key.replaceAll('_', '-'),  // dash-case
        key.replaceAll('-', '_'),  // snake_case
      ];
      
      for (final variant in variations) {
        final value = String.fromEnvironment(variant, defaultValue: '');
        if (value.isNotEmpty) {
          // Store with the original key name from config
          vars[key] = _parseValue(value);
          // Also store with lowercase for case-insensitive access
          vars[key.toLowerCase()] = _parseValue(value);
          break;  // Found a value, stop checking variations
        }
      }
    }
    
    return vars;
  }
  
  /// Parse string value to appropriate type
  dynamic _parseValue(String value) {
    // Try to parse as bool
    if (value.toLowerCase() == 'true' || value == '1' || value.toLowerCase() == 'yes') {
      return true;
    }
    if (value.toLowerCase() == 'false' || value == '0' || value.toLowerCase() == 'no') {
      return false;
    }
    
    // Try to parse as number
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;
    
    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue;
    
    // Return as string
    return value;
  }
  
  /// Merge environments with dart-define overrides
  List<EnvironmentConfig> _mergeWithDartDefine(
    List<EnvironmentConfig> environments,
    Map<String, dynamic>? dartDefineVars,
  ) {
    if (dartDefineVars == null || dartDefineVars.isEmpty) {
      return environments;
    }
    
    // Apply dart-define overrides to all environments
    return environments.map((env) {
      final mergedVars = Map<String, dynamic>.from(env.variables);
      
      // Override with dart-define values (highest priority)
      dartDefineVars.forEach((key, value) {
        // Use both lowercase and original case for flexibility
        mergedVars[key] = value;
        mergedVars[key.toLowerCase()] = value;
      });
      
      return env.copyWith(variables: mergedVars);
    }).toList();
  }
}