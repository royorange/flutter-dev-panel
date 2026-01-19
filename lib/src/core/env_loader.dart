import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'environment_manager.dart';

/// Utility class for loading environment configurations from .env files
class EnvLoader {
  /// Load environments from .env files in the project root
  /// 
  /// 自动扫描项目中的 .env 文件：
  /// - .env (生产环境/默认)
  /// - .env.xxx (xxx 作为环境名，如 .env.dev → "dev" 环境)
  /// 
  /// Returns null if no .env files are found
  static Future<List<EnvironmentConfig>?> loadFromEnvFiles() async {
    final environments = <EnvironmentConfig>[];
    
    // 生产模式只加载 .env 或 .env.production
    if (kReleaseMode) {
      // 优先尝试 .env.production
      var loaded = await _tryLoadEnvFile('.env.production');
      if (loaded != null) {
        environments.add(
          EnvironmentConfig(
            name: 'Production',
            variables: loaded,
            isDefault: true,
          ),
        );
      } else {
        // 回退到 .env
        loaded = await _tryLoadEnvFile('.env');
        if (loaded != null) {
          environments.add(
            EnvironmentConfig(
              name: 'Production',
              variables: loaded,
              isDefault: true,
            ),
          );
        }
      }
      return environments.isEmpty ? null : environments;
    }
    
    // 开发/调试模式：动态扫描所有 .env 文件
    
    // 通过 AssetManifest 获取所有声明的 assets
    try {
      // 获取 AssetManifest 来找出所有声明的 .env 文件
      final List<String> envFiles = await _getEnvFilesFromAssets();
      
      if (envFiles.isNotEmpty) {
        debugPrint('DevPanel: Found env files in assets: $envFiles');
        
        // 加载所有找到的 .env.* 文件
        for (final fileName in envFiles) {
          // 跳过基础 .env 文件（最后加载）
          if (fileName == '.env') continue;
          
          final loaded = await _tryLoadEnvFile(fileName);
          if (loaded != null) {
            final envName = _extractEnvNameFromFile(fileName);
            environments.add(
              EnvironmentConfig(
                name: envName,
                variables: loaded,
                isDefault: fileName.contains('dev'),
              ),
            );
          }
        }
        
        // 如果没有找到任何 .env.* 文件，尝试加载 .env
        if (environments.isEmpty && envFiles.contains('.env')) {
          final loaded = await _tryLoadEnvFile('.env');
          if (loaded != null) {
            environments.add(
              EnvironmentConfig(
                name: 'Default',
                variables: loaded,
                isDefault: true,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('DevPanel: Failed to get env files from assets: $e');
      
      // 回退方案：尝试常见的文件名
      final fallbackFiles = ['.env', '.env.production', '.env.dev', '.env.staging'];
      for (final fileName in fallbackFiles) {
        final loaded = await _tryLoadEnvFile(fileName);
        if (loaded != null) {
          final envName = fileName == '.env' ? 'Default' : _extractEnvNameFromFile(fileName);
          environments.add(
            EnvironmentConfig(
              name: envName,
              variables: loaded,
              isDefault: fileName == '.env' || fileName.contains('dev'),
            ),
          );
        }
      }
    }
    
    return environments.isEmpty ? null : environments;
  }
  
  /// 从 AssetManifest 获取所有 .env 文件
  static Future<List<String>> _getEnvFilesFromAssets() async {
    try {
      // 使用 rootBundle 获取 AssetManifest
      final String manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      
      // 筛选出所有 .env 文件
      final envFiles = <String>[];
      for (final String key in manifestMap.keys) {
        // 匹配 .env 或 .env.* 文件（在根目录）
        if (key.startsWith('.env') && !key.contains('/')) {
          envFiles.add(key);
        }
      }
      
      // 排序：.env.* 文件优先，.env 最后
      envFiles.sort((a, b) {
        if (a == '.env') return 1;
        if (b == '.env') return -1;
        return a.compareTo(b);
      });
      
      return envFiles;
    } catch (e) {
      // 如果无法读取 manifest，返回空列表
      return [];
    }
  }
  
  /// 从文件名提取环境名
  static String _extractEnvNameFromFile(String fileName) {
    // .env.dev → Dev
    // .env.development → Development
    // .env.staging → Staging
    if (!fileName.startsWith('.env.')) {
      return 'Default';
    }
    
    final suffix = fileName.substring(5); // Remove '.env.'
    
    // 首字母大写
    if (suffix.isEmpty) {
      return 'Default';
    }
    return suffix[0].toUpperCase() + suffix.substring(1).toLowerCase();
  }
  
  
  /// 静默尝试加载 .env 文件（不打印错误）
  static Future<Map<String, dynamic>?> _tryLoadEnvFile(String fileName) async {
    try {
      await dotenv.load(fileName: fileName);
      
      if (dotenv.env.isNotEmpty) {
        debugPrint('DevPanel: Loaded $fileName with ${dotenv.env.length} variables');
        return Map<String, dynamic>.from(dotenv.env);
      }
      
      return null;
    } catch (e) {
      // 完全静默，不打印任何错误
      return null;
    }
  }
  
  /// Create a sample .env file content
  static String generateSampleEnvFile({String environment = 'development'}) {
    return '''
# Environment: $environment
# Generated by Flutter Dev Panel

# API Configuration
API_URL=https://api.example.com
API_KEY=your_api_key_here
API_TIMEOUT=30000

# WebSocket Configuration  
SOCKET_URL=wss://socket.example.com
SOCKET_RECONNECT_INTERVAL=5000

# Feature Flags
DEBUG=true
ENABLE_LOGGING=true
ENABLE_CRASH_REPORTING=false

# App Configuration
APP_NAME=Flutter Dev Panel
APP_VERSION=1.0.0
BUILD_NUMBER=1

# Third-party Services
SENTRY_DSN=
FIREBASE_PROJECT_ID=
ANALYTICS_ID=

# Other Settings
MAX_CACHE_SIZE=104857600
SESSION_TIMEOUT=1800
DEFAULT_LANGUAGE=en
''';
  }
  
  /// Merge environments from different sources
  /// Priority: .env files > code configuration > saved configuration
  static List<EnvironmentConfig> mergeEnvironments({
    List<EnvironmentConfig>? fromEnvFiles,
    List<EnvironmentConfig>? fromCode,
    List<EnvironmentConfig>? fromStorage,
  }) {
    final merged = <String, EnvironmentConfig>{};
    
    // Start with saved configuration (lowest priority)
    if (fromStorage != null) {
      for (final env in fromStorage) {
        merged[env.name] = env;
      }
    }
    
    // Override with code configuration
    if (fromCode != null) {
      for (final env in fromCode) {
        merged[env.name] = env;
      }
    }
    
    // Override with .env files (highest priority)
    // .env files should completely replace the environment configuration
    // to ensure that changes in .env files take effect on restart
    if (fromEnvFiles != null) {
      for (final env in fromEnvFiles) {
        merged[env.name] = env;
      }
    }
    
    return merged.values.toList();
  }
  
  /// Validate environment configuration
  static bool validateEnvironment(EnvironmentConfig env) {
    // Check for required variables
    final requiredVars = ['API_URL']; // Add more as needed
    
    for (final varName in requiredVars) {
      if (!env.variables.containsKey(varName) || 
          env.variables[varName] == null ||
          env.variables[varName].toString().isEmpty) {
        debugPrint('Environment ${env.name} missing required variable: $varName');
        return false;
      }
    }
    
    return true;
  }
}