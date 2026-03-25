# Flutter Dev Panel - Network Module

[![pub package](https://img.shields.io/pub/v/flutter_dev_panel_network.svg)](https://pub.dev/packages/flutter_dev_panel_network)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.13.0-blue)](https://flutter.dev)

Network monitoring module for Flutter Dev Panel that provides unified request tracking across Dio, http package, and GraphQL.

## Features

- **Multi-library support** - Works with Dio, http package, and graphql_flutter
- **Persistent storage** - Request history survives app restarts  
- **Real-time monitoring** - Live network activity in floating action button
- **Request/Response inspection** - View headers, body, timing, and size
- **GraphQL support** - Operation type detection and query inspection
- **Advanced filtering** - Search by URL, status code, method, and more
- **Smart JSON viewer** - Collapsible tree view for complex nested data

## Installation

[![flutter_dev_panel version](https://img.shields.io/pub/v/flutter_dev_panel.svg?label=flutter_dev_panel)](https://pub.dev/packages/flutter_dev_panel)

```yaml
dependencies:
  flutter_dev_panel: ^latest_version  # Replace with latest version from badges above
  flutter_dev_panel_network: ^latest_version
```

## Basic Usage

### Dio Integration

```dart
import 'package:flutter_dev_panel_network/flutter_dev_panel_network.dart';
import 'package:dio/dio.dart';

// Simple integration
final dio = Dio();
NetworkModule.attachToDio(dio);

// Multiple Dio instances
NetworkModule.attachToMultipleDio([dio1, dio2, dio3]);
```

### HTTP Package Integration

```dart
import 'package:http/http.dart' as http;

// Create monitored client
final client = NetworkModule.createHttpClient();

// Or wrap existing client
final wrappedClient = NetworkModule.wrapHttpClient(existingClient);
```

### GraphQL Integration

#### Basic Setup

```dart
import 'package:graphql_flutter/graphql_flutter.dart';

// Method 1: Create monitored Link (Recommended)
final httpLink = HttpLink('https://api.example.com/graphql');
final link = NetworkModule.createGraphQLLink(httpLink, endpoint: endpoint);

final client = GraphQLClient(
  link: link,
  cache: GraphQLCache(),
);

// Method 2: Wrap existing client
final monitoredClient = NetworkModule.wrapGraphQLClient(
  existingClient,
  endpoint: 'https://api.example.com/graphql',
);
```

#### Working with Multiple Links

GraphQL supports chaining multiple Links for authentication, error handling, etc:

```dart
// Example 1: With Authentication
final httpLink = HttpLink('https://api.example.com/graphql');
final authLink = AuthLink(getToken: () async => 'Bearer $token');

// Option A: Monitor all requests (including auth headers)
final link = NetworkModule.createGraphQLLink(
  Link.from([authLink, httpLink]),
  endpoint: 'https://api.example.com/graphql',
);

// Option B: Monitor only HTTP requests (after auth)
final monitoredHttpLink = NetworkModule.createGraphQLLink(httpLink);
final link = Link.from([authLink, monitoredHttpLink]);
```

```dart
// Example 2: Complex Link Chain
final httpLink = HttpLink('https://api.example.com/graphql');
final authLink = AuthLink(getToken: () async => await getToken());
final errorLink = ErrorLink(
  onGraphQLError: (request, forward, response) {
    // Handle GraphQL errors
  },
);

// Build the chain: Error → Auth → Monitor → HTTP
final link = Link.from([
  errorLink,
  authLink,
  NetworkModule.createGraphQLInterceptor(
    endpoint: 'https://api.example.com/graphql',
  ),
  httpLink,
]);

final client = GraphQLClient(link: link, cache: GraphQLCache());
```

```dart
// Example 3: With WebSocket for Subscriptions
final httpLink = HttpLink('https://api.example.com/graphql');
final wsLink = WebSocketLink('wss://api.example.com/graphql');

// Split between HTTP and WebSocket based on operation type
final link = Link.split(
  (request) => request.isSubscription,
  wsLink,  // Use WebSocket for subscriptions
  NetworkModule.createGraphQLLink(httpLink), // Monitor HTTP requests
);
```

## Advanced Usage

### GraphQL with Environment Switching

When using Flutter Dev Panel's environment management, you can dynamically switch GraphQL endpoints:

```dart
class GraphQLService extends ChangeNotifier {
  static final instance = GraphQLService._();
  GraphQLService._();
  
  GraphQLClient? _client;
  GraphQLClient get client => _client ?? _createClient();
  
  void initialize() {
    _client = _createClient();
    // Listen to environment changes
    DevPanel.environment.addListener(_onEnvironmentChanged);
  }
  
  void _onEnvironmentChanged() {
    // Recreate client when environment changes
    _client = _createClient();
    notifyListeners();
  }
  
  GraphQLClient _createClient() {
    // Get endpoint from environment
    final endpoint = DevPanel.environment.getStringOr(
      'GRAPHQL_ENDPOINT',
      'https://api.example.com/graphql'
    );
    
    // Create monitored Link
    final link = NetworkModule.createGraphQLLink(
      HttpLink(endpoint),
      endpoint: endpoint,
    );
    
    return GraphQLClient(
      link: link,
      cache: GraphQLCache(),
    );
  }
  
  @override
  void dispose() {
    DevPanel.environment.removeListener(_onEnvironmentChanged);
    super.dispose();
  }
}
```

Usage in your app:

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GraphQLService.instance,
      builder: (context, _) {
        return GraphQLProvider(
          client: ValueNotifier(GraphQLService.instance.client),
          child: MaterialApp(...),
        );
      },
    );
  }
}
```

### Environment Configuration

```dart
await DevPanel.environment.initialize(
  environments: [
    const EnvironmentConfig(
      name: 'Development',
      variables: {
        'GRAPHQL_ENDPOINT': 'https://dev-api.example.com/graphql',
        'API_KEY': 'dev-key',
      },
      isDefault: true,
    ),
    const EnvironmentConfig(
      name: 'Production',
      variables: {
        'GRAPHQL_ENDPOINT': 'https://api.example.com/graphql',
        'API_KEY': '', // Injected via --dart-define
      },
    ),
  ],
);
```

## Features in Detail

### Real-time FAB Display

The network module shows real-time statistics in the FAB:
- Request count and status (✓ for success, ⚠ for errors)
- Recent batch statistics: `5req/315K 300ms`
  - Number of requests in the last batch
  - Total data transferred
  - Average response time

### Request Details

Each request shows:
- Method and URL
- Status code and timing
- Request/Response headers
- Request/Response body with JSON viewer
- Size information

### GraphQL Specifics

- Operation name in URL (e.g., `#GetUsers`)
- Query/Mutation detection
- Variables inspection
- Smart JSON viewer for nested responses

### JSON Viewer Features

The enhanced JSON viewer provides:
- 🎯 Smart folding based on depth and complexity
- 📊 Type-based color highlighting
- 🔍 Content preview for long strings and arrays
- 💡 Tooltips showing full content on hover
- 🎨 Clean indentation and alignment

## Best Practices

### GraphQL Integration

✅ **DO:**
- Specify endpoint explicitly for accurate display
- Use `NetworkModule.createGraphQLLink` for monitoring
- Handle environment switching with listeners

❌ **DON'T:**
- Hardcode endpoints
- Create new clients without cleanup
- Forget to dispose listeners

### General Tips

1. **Initialize early**: Attach interceptors before making requests
2. **Use environment variables**: Leverage DevPanel's environment management
3. **Monitor production carefully**: The module is automatically disabled in release mode

## Comparison: Dio vs GraphQL

### Dio (Mutable Configuration)
```dart
// Can modify options directly
dio.options.baseUrl = newUrl;
dio.options.headers['Authorization'] = newToken;
```

### GraphQL (Immutable Link)
```dart
// Must recreate client for new endpoint
final newLink = NetworkModule.createGraphQLLink(
  HttpLink(newEndpoint),
  endpoint: newEndpoint,
);
final newClient = GraphQLClient(link: newLink, cache: cache);
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.