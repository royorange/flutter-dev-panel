# Network Integration Guide

## Quick Setup

### For Dio (Recommended)
```dart
final dio = Dio();
NetworkModule.attachToDio(dio);  // Modifies dio directly
// Use dio as normal
```

### For GraphQL

#### Method 1 - Create with monitoring (Recommended):
```dart
// Add monitoring when creating the client
final link = NetworkModule.createGraphQLLink(
  HttpLink('https://api.example.com/graphql'),
  endpoint: 'https://api.example.com/graphql',
);

final graphQLClient = GraphQLClient(
  link: link,
  cache: GraphQLCache(),
);

// Use graphQLClient directly - no need to wrap
```

#### Method 2 - Wrap existing client:
```dart
// If you already have a client
GraphQLClient client = GraphQLClient(...);

// Note: GraphQL clients are immutable, so you must reassign
client = NetworkModule.wrapGraphQLClient(client);

// Now use the wrapped client
```

### For HTTP Package (Alternative)
```dart
// Using interceptor pattern
final client = NetworkInterceptor.http(http.Client());
```

## Dynamic Endpoint Switching

### For Dio (Simple - can modify directly)
```dart
class ApiService {
  final dio = Dio();
  
  ApiService() {
    NetworkModule.attachToDio(dio); // Only once
    _updateConfig();
    DevPanel.environment.addListener(_updateConfig);
  }
  
  void _updateConfig() {
    // Directly modify options
    dio.options.baseUrl = DevPanel.environment.getString('api_url') ?? '';
  }
}
```

### For GraphQL (Requires recreating client)
```dart
class GraphQLService extends ChangeNotifier {
  GraphQLClient? _client;
  GraphQLClient get client => _client ?? _createClient();
  
  void initialize() {
    _client = _createClient();
    DevPanel.environment.addListener(_onEnvironmentChanged);
  }
  
  void _onEnvironmentChanged() {
    _client = _createClient(); // Recreate with new endpoint
    notifyListeners();
  }
  
  GraphQLClient _createClient() {
    final endpoint = DevPanel.environment.getString('graphql_endpoint') 
        ?? 'https://api.example.com/graphql';
    
    final httpLink = HttpLink(endpoint);
    final authLink = AuthLink(getToken: () async => 'Bearer $token');
    
    // Chain links: Auth → Monitor → HTTP
    final link = NetworkModule.createGraphQLLink(
      Link.from([authLink, httpLink]),
      endpoint: endpoint,
    );
    
    return GraphQLClient(link: link, cache: GraphQLCache());
  }
}
```

## Working with Multiple GraphQL Links

GraphQL supports chaining multiple Links for authentication, error handling, etc:

### Example 1: With Authentication
```dart
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

### Example 2: Complex Link Chain
```dart
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

### Example 3: With WebSocket for Subscriptions
```dart
final httpLink = HttpLink('https://api.example.com/graphql');
final wsLink = WebSocketLink('wss://api.example.com/graphql');

// Split between HTTP and WebSocket based on operation type
final link = Link.split(
  (request) => request.isSubscription,
  wsLink,  // Use WebSocket for subscriptions
  NetworkModule.createGraphQLLink(httpLink), // Monitor HTTP requests
);
```

## Environment Variables

### Get Environment Variables
```dart
// Using convenience methods (recommended)
final apiUrl = DevPanel.environment.getString('api_url');
final isDebug = DevPanel.environment.getBool('debug');
final timeout = DevPanel.environment.getInt('timeout');

// Listen to environment changes
ListenableBuilder(
  listenable: DevPanel.environment,
  builder: (context, _) {
    final apiUrl = DevPanel.environment.getString('api_url');
    // UI updates automatically when environment switches
    return Text('API: $apiUrl');
  },
);
```

## See Also

- [GraphQL Environment Switching Guide](graphql_environment_switching.md)
- [Environment Usage Guide](environment_usage.md)
- [Network Module Documentation](../packages/flutter_dev_panel_network/)