# GraphQL Endpoint Environment Switching Guide

How to dynamically switch GraphQL endpoints when using Flutter Dev Panel's environment management feature?

## Core Concept

GraphQL client's `link` is immutable, so switching endpoints requires recreating the client.

## Solutions

### Solution 1: Service Pattern (Recommended)

Create a Service to manage the GraphQL client:

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
    // Get endpoint from environment variables
    final endpoint = DevPanel.environment.getString('graphql_endpoint') 
        ?? 'https://api.example.com/graphql';
    
    // Create monitored Link using NetworkModule
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

Usage:

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

### Solution 2: Direct Widget Handling

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DevPanel.environment,
      builder: (context, _) {
        // Recreate client on each environment change
        final endpoint = DevPanel.environment.getString('graphql_endpoint') 
            ?? 'https://api.example.com/graphql';
        
        final link = NetworkModule.createGraphQLLink(
          HttpLink(endpoint),
          endpoint: endpoint,
        );
        
        final client = GraphQLClient(
          link: link,
          cache: GraphQLCache(),
        );
        
        return GraphQLProvider(
          client: ValueNotifier(client),
          child: MaterialApp(...),
        );
      },
    );
  }
}
```

### Solution 3: Using Provider

```dart
class GraphQLClientProvider extends ChangeNotifier {
  late GraphQLClient _client;
  GraphQLClient get client => _client;
  
  GraphQLClientProvider() {
    _updateClient();
    DevPanel.environment.addListener(_updateClient);
  }
  
  void _updateClient() {
    final endpoint = DevPanel.environment.getString('graphql_endpoint') 
        ?? 'https://api.example.com/graphql';
    
    final link = NetworkModule.createGraphQLLink(
      HttpLink(endpoint),
      endpoint: endpoint,
    );
    
    _client = GraphQLClient(
      link: link,
      cache: GraphQLCache(),
    );
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    DevPanel.environment.removeListener(_updateClient);
    super.dispose();
  }
}

// Usage
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => GraphQLClientProvider()),
  ],
  child: MyApp(),
);
```

## Environment Configuration Example

```dart
await DevPanel.environment.initialize(
  environments: [
    const EnvironmentConfig(
      name: 'Development',
      variables: {
        'graphql_endpoint': 'https://dev-api.example.com/graphql',
        'api_key': 'dev-key',
      },
      isDefault: true,
    ),
    const EnvironmentConfig(
      name: 'Staging',
      variables: {
        'graphql_endpoint': 'https://staging-api.example.com/graphql',
        'api_key': 'staging-key',
      },
    ),
    const EnvironmentConfig(
      name: 'Production',
      variables: {
        'graphql_endpoint': 'https://api.example.com/graphql',
        'api_key': '', // Inject via --dart-define
      },
    ),
  ],
);
```

## Comparison with Dio

Dio handling is simpler because you can directly modify `BaseOptions`:

```dart
class ApiService {
  final dio = Dio();
  
  ApiService() {
    NetworkModule.attachToDio(dio); // Only needed once
    _updateConfig();
    DevPanel.environment.addListener(_updateConfig);
  }
  
  void _updateConfig() {
    // Directly modify configuration, no need to recreate
    dio.options.baseUrl = DevPanel.environment.getString('api_url') ?? '';
    dio.options.headers['Authorization'] = 'Bearer ${DevPanel.environment.getString('api_key')}';
  }
}
```

## Key Points

1. **GraphQL requires recreating the client**: Because `link` is immutable
2. **Dio can directly modify configuration**: Because `options` is mutable
3. **Use ListenableBuilder**: Automatically respond to environment changes
4. **Remember to clean up listeners**: Remove listeners in `dispose`

## Best Practices

- ✅ Use Service pattern to manage GraphQL client
- ✅ Listen to environment changes for automatic updates
- ✅ Use `NetworkModule.createGraphQLLink` to ensure monitoring works
- ✅ Define all endpoints in environment configuration
- ❌ Avoid hardcoding endpoints