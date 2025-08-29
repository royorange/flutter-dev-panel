# Configuration Guide

## Environment Management

### Configuration Priority

Environment variables are loaded in the following priority order (highest to lowest):
1. **--dart-define** - Command line arguments (automatically detected)
2. **.env files** - Environment-specific files (if present)
3. **Code configuration** - Defaults in `initialize()`
4. **Saved configuration** - Previous runtime values

**How it works:**
- The system automatically discovers all keys from your configurations
- Any matching key passed via --dart-define will override other sources
- Keys are matched case-insensitively and with format variations (snake_case, dash-case)

### Recommended Setup

1. **Create environment files:**
```bash
# .env.example (commit to git - template)
API_URL=https://api.example.com
API_KEY=your-key-here
ENABLE_ANALYTICS=false

# .env.development (commit to git - safe defaults)
API_URL=https://dev.api.example.com
ENABLE_ANALYTICS=false

# .env.production (commit to git - non-sensitive configs)
API_URL=https://api.example.com
ENABLE_ANALYTICS=true
# Sensitive values injected via --dart-define in CI/CD
```

2. **Add to pubspec.yaml (for production builds):**
```yaml
flutter:
  assets:
    - .env.production  # Required for release builds
```

3. **Add to .gitignore (only local overrides):**
```gitignore
.env
.env.local
.env.*.local
!.env.example
!.env.development
!.env.production
```

4. **Build commands:**
```bash
# Development (uses .env.development)
flutter run

# Production with secrets from CI/CD
flutter build apk \
  --dart-define=API_KEY=$SECRET_API_KEY \
  --dart-define=DB_PASSWORD=$SECRET_DB_PASSWORD

# CI/CD example
flutter build ios \
  --dart-define=API_KEY=${{ secrets.API_KEY }} \
  --dart-define=SENTRY_DSN=${{ secrets.SENTRY_DSN }}
```

### Configuration Strategy

**Commit to Git:**
- `.env.development` - Development URLs and non-sensitive configs
- `.env.production` - Production URLs and non-sensitive configs
- `.env.example` - Template with all variables documented

**Inject via CI/CD (--dart-define):**
- API keys, tokens, passwords
- Third-party service credentials
- Any sensitive configuration
- Environment-specific overrides

**Benefits:**
- Non-sensitive configs are version controlled
- Sensitive data never touches the repository
- CI/CD can override any value defined in your config
- Developers can run the app without manual setup
- No need to maintain a hardcoded list of keys

### How --dart-define Works

1. **Define keys in your environment config** with default values:
```dart
const EnvironmentConfig(
  name: 'Production',
  variables: {
    'api_url': 'https://api.example.com',
    'api_key': '',  // Empty default, will be injected
    'sentry_dsn': '',  // Empty default, will be injected
  },
)
```

2. **Override via --dart-define** in CI/CD:
```bash
flutter build apk \
  --dart-define=api_key=${{ secrets.API_KEY }} \
  --dart-define=sentry_dsn=${{ secrets.SENTRY_DSN }}
```

The system automatically detects and applies these overrides.

## Module Configuration

### Console Module
```dart
// Configure via module initialization
ConsoleModule(
  logConfig: const LogCaptureConfig(
    maxLogs: 1000,              // Maximum logs to keep (default: 1000)
    autoScroll: true,           // Auto-scroll to latest log (default: true)
    combineLoggerOutput: true,  // Merge Logger package multi-line output (default: true)
  ),
)

// Default configuration is usually sufficient
ConsoleModule()  // Uses default: maxLogs=1000, autoScroll=true, combineLoggerOutput=true
```

### Network Module

#### Quick Integration
```dart
// Dio
NetworkModule.attachToDio(dio);

// HTTP Package
final client = NetworkModule.createHttpClient();

// GraphQL
final link = NetworkModule.createGraphQLLink(httpLink, endpoint: endpoint);
```

#### Key Features
- **Multi-library Support**: Works with Dio, http package, and GraphQL
- **Real-time Monitoring**: Live stats in FAB (e.g., `5req/315K 300ms`)
- **GraphQL Support**: Operation name detection, query inspection
- **Smart JSON Viewer**: Collapsible tree view for complex data
- **Environment Integration**: Dynamic endpoint switching

#### GraphQL with Environment Switching
```dart
// Automatically recreate GraphQL client when environment changes
final endpoint = DevPanel.environment.getStringOr('GRAPHQL_ENDPOINT', defaultUrl);
final link = NetworkModule.createGraphQLLink(HttpLink(endpoint), endpoint: endpoint);
```

📖 [View Network Module Documentation →](../packages/flutter_dev_panel_network/) for GraphQL integration, environment switching, and advanced usage.

### Performance Module

#### Automatic Monitoring
When using `DevPanel.init()` (Method 1), the module automatically:
- Tracks all Timers via Zone interception
- Monitors FPS and memory usage
- Detects frame drops and jank
- Analyzes memory growth patterns
- Identifies resource leaks

#### Key Features
- **Timer Tracking**: View all active Timers with source location
- **Memory Analysis**: Detect leaks with growth rate calculation  
- **Resource Monitoring**: Track Timers and StreamSubscriptions
- **Interactive UI**: Expandable lists with detailed stack traces
- **Smart Detection**: Automatic identification of potential issues

**Note**: Automatic Timer tracking requires Zone setup (Method 1 or 2). With Method 3, only manual tracking is available.

📖 [View Performance Module Documentation →](../packages/flutter_dev_panel_performance/) for detailed API usage, Timer tracking examples, and memory analysis features.

## Production Safety

The dev panel has multiple layers of protection for production builds:

### 1. Default Behavior
- **Debug mode**: Automatically enabled
- **Release mode**: Automatically disabled (code removed by tree shaking)

### 2. Force Enable in Production
For internal testing builds, you can enable the panel in release mode:

```bash
# Build with dev panel enabled in release mode
flutter build apk --release --dart-define=FORCE_DEV_PANEL=true

# CI/CD example
flutter build ios --release \
  --dart-define=FORCE_DEV_PANEL=true \
  --dart-define=API_KEY=${{ secrets.API_KEY }}
```

### 3. API Protection
All public APIs check compile-time constants:
- APIs become no-op in release mode (unless `FORCE_DEV_PANEL=true`)
- Tree-shaking removes unused code automatically
- Zero runtime overhead in production

### 4. Zero Overhead in Production
When not forced in release builds:
- No UI components are rendered
- No logs are captured  
- No performance monitoring
- Code is completely removed by tree-shaking
- No impact on app size or performance