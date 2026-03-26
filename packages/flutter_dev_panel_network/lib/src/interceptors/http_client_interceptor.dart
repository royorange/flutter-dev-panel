import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_interceptor.dart';
import '../network_monitor_controller.dart';

/// BaseNetworkInterceptor的HTTP实现
class _HttpInterceptor extends BaseNetworkInterceptor {
  _HttpInterceptor(super.controller);
}

/// 用于http包的拦截器客户端
class MonitoredHttpClient extends http.BaseClient {
  final http.Client _inner;
  final BaseNetworkInterceptor _interceptor;
  
  MonitoredHttpClient({
    http.Client? client,
    NetworkMonitorController? controller,
  }) : _inner = client ?? http.Client(),
       _interceptor = _HttpInterceptor(controller ?? NetworkMonitorController());
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 记录请求开始
    final requestBody = await _getRequestBody(request);
    final requestId = _interceptor.recordRequest(
      url: request.url.toString(),
      method: request.method,
      headers: request.headers,
      body: requestBody,
      requestSize: request.contentLength,
    );
    
    try {
      // 发送请求
      final response = await _inner.send(request);
      
      // 读取响应流
      final responseBytes = await response.stream.toBytes();
      final responseBody = _tryDecodeResponse(responseBytes, response.headers);
      
      // 记录响应
      _interceptor.recordResponse(
        requestId: requestId,
        statusCode: response.statusCode,
        statusMessage: response.reasonPhrase,
        headers: response.headers,
        body: responseBody,
        responseSize: responseBytes.length,
      );
      
      // 返回新的响应流
      return http.StreamedResponse(
        Stream.fromIterable([responseBytes]),
        response.statusCode,
        contentLength: responseBytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      // 记录错误
      _interceptor.recordError(
        requestId: requestId,
        error: e.toString(),
      );
      rethrow;
    }
  }
  
  /// 获取请求体内容
  Future<dynamic> _getRequestBody(http.BaseRequest request) async {
    if (request is http.Request) {
      return request.body;
    } else if (request is http.MultipartRequest) {
      return {
        'fields': request.fields,
        'files': request.files.map((f) => f.filename).toList(),
      };
    }
    return null;
  }
  
  /// 尝试解码响应体
  dynamic _tryDecodeResponse(List<int> bytes, Map<String, String> headers) {
    try {
      final contentType = headers['content-type'] ?? '';
      final responseString = utf8.decode(bytes);
      
      if (contentType.contains('application/json')) {
        return json.decode(responseString);
      }
      return responseString;
    } catch (e) {
      // 如果解码失败，返回原始字节长度信息
      return '<Binary data: ${bytes.length} bytes>';
    }
  }
  
  @override
  void close() {
    _inner.close();
  }
}

/// 便捷方法：包装现有的http.Client
http.Client wrapHttpClient({
  http.Client? client,
  NetworkMonitorController? controller,
}) {
  return MonitoredHttpClient(
    client: client,
    controller: controller,
  );
}