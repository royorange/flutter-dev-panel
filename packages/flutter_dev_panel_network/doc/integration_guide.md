# Network Module Integration Guide

## 集成方式对比

### Dio 集成

✅ **直接修改原客户端**

```dart
final dio = Dio();
NetworkModule.attachToDio(dio);  // 直接添加拦截器到 dio
// 继续使用原 dio 对象
```

**优点**：
- 简单直接
- 不需要改变变量引用
- Dio 支持动态添加拦截器

### GraphQL 集成

由于 GraphQL 客户端的 `link` 属性是 immutable（不可变）的，我们提供两种方式：

#### 方式 1：创建时集成（推荐）✅

```dart
// 在创建客户端时就加入监控
final link = NetworkModule.createGraphQLLink(
  HttpLink('https://api.example.com/graphql'),
  endpoint: 'https://api.example.com/graphql',
);

final client = GraphQLClient(
  link: link,
  cache: GraphQLCache(),
);
// 直接使用 client，无需额外步骤
```

**优点**：
- 最清晰的方式
- 避免混淆
- 性能最优

#### 方式 2：包装现有客户端 ⚠️

```dart
// 已有客户端
GraphQLClient client = GraphQLClient(
  link: HttpLink('https://api.example.com/graphql'),
  cache: GraphQLCache(),
);

// 必须重新赋值（因为返回新客户端）
client = NetworkModule.wrapGraphQLClient(client);
```

**注意事项**：
- 返回新客户端，不是修改原客户端
- 必须重新赋值
- 如果忘记重新赋值，监控不会生效

### HTTP 包集成

```dart
// 方式 1：创建新客户端
final client = NetworkModule.createHttpClient();

// 方式 2：包装现有客户端
final wrappedClient = NetworkModule.wrapHttpClient(existingClient);
```

## 为什么 GraphQL 不能像 Dio 一样直接修改？

### Dio 的设计

```dart
class Dio {
  final interceptors = <Interceptor>[];  // 可变列表
  // 可以动态添加拦截器
}
```

### GraphQL 的设计

```dart
class GraphQLClient {
  final Link link;  // final 不可变
  final GraphQLCache cache;  // final 不可变
  
  // 构造函数创建后无法修改
  GraphQLClient({required this.link, required this.cache});
}
```

## 最佳实践

### ✅ 推荐方式

1. **Dio**：使用 `attachToDio` 直接修改
2. **GraphQL**：使用 `createGraphQLLink` 在创建时集成
3. **HTTP**：使用 `createHttpClient` 创建带监控的客户端

### ⚠️ 注意事项

1. **GraphQL 重新赋值**：如果使用 `wrapGraphQLClient`，必须重新赋值
   ```dart
   // ❌ 错误：忘记重新赋值
   NetworkModule.wrapGraphQLClient(client);
   
   // ✅ 正确：重新赋值
   client = NetworkModule.wrapGraphQLClient(client);
   ```

2. **生产环境**：所有方法在生产环境自动禁用，返回原始客户端/链接

3. **性能影响**：在调试模式下，拦截器会略微增加延迟（通常 < 1ms）

## 迁移指南

### 从 `attachToGraphQL` 迁移

旧代码：
```dart
final client = GraphQLClient(...);
final monitoredClient = NetworkModule.attachToGraphQL(client);
// 使用 monitoredClient
```

新代码（推荐）：
```dart
final link = NetworkModule.createGraphQLLink(HttpLink(...));
final client = GraphQLClient(link: link, cache: GraphQLCache());
// 直接使用 client
```

或者：
```dart
GraphQLClient client = GraphQLClient(...);
client = NetworkModule.wrapGraphQLClient(client);  // 重新赋值
// 使用 client
```

## API 参考

### Dio
- `attachToDio(Dio dio)` - 直接修改 dio 实例
- `attachToMultipleDio(List<Dio> dios)` - 批量添加到多个 dio 实例

### GraphQL
- `createGraphQLLink(Link link)` - 创建带监控的 Link（推荐）
- `wrapGraphQLClient(GraphQLClient client)` - 包装现有客户端（返回新实例）
- `attachToGraphQL(GraphQLClient client)` - 已废弃，使用 wrapGraphQLClient

### HTTP
- `createHttpClient({Client? innerClient})` - 创建带监控的 HTTP 客户端
- `wrapHttpClient(Client client)` - 包装现有 HTTP 客户端