import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'models/network_request.dart';
import 'network_monitor_controller.dart';
import 'utils/sse_parser.dart';

class NetworkInterceptor extends Interceptor {
  final NetworkMonitorController controller;

  NetworkInterceptor(this.controller);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    
    final request = NetworkRequest(
      id: requestId,
      url: options.uri.toString(),
      method: _parseMethod(options.method),
      headers: options.headers.map((k, v) => MapEntry(k, v.toString())),
      requestBody: options.data,
      startTime: DateTime.now(),
      status: RequestStatus.pending,
      requestSize: _calculateSize(options.data),
    );

    options.extra['requestId'] = requestId;
    controller.addRequest(request);
    
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = response.requestOptions.extra['requestId'] as String?;

    if (requestId != null) {
      try {
        final isSSE = _isSSEResponse(response);

        if (isSSE && response.requestOptions.responseType == ResponseType.stream) {
          _handleStreamSSE(requestId, response);
        } else if (isSSE && response.data is String) {
          _handlePlainSSE(requestId, response);
        } else {
          controller.updateRequest(
            requestId,
            responseBody: response.data,
            statusCode: response.statusCode,
            statusMessage: response.statusMessage,
            endTime: DateTime.now(),
            status: RequestStatus.success,
            responseHeaders: response.headers.map.map((k, v) => MapEntry(k, v.join(', '))),
            responseSize: _calculateSize(response.data),
          );
        }
      } catch (e) {
        // Ensure request never stays stuck in pending
        controller.updateRequest(
          requestId,
          statusCode: response.statusCode,
          endTime: DateTime.now(),
          status: RequestStatus.success,
        );
      }
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.requestOptions.extra['requestId'] as String?;

    if (requestId != null) {
      try {
        controller.updateRequest(
          requestId,
          responseBody: err.response?.data,
          statusCode: err.response?.statusCode,
          statusMessage: err.response?.statusMessage ?? err.message,
          endTime: DateTime.now(),
          status: RequestStatus.error,
          error: err.toString(),
          responseHeaders: err.response?.headers.map.map((k, v) => MapEntry(k, v.join(', '))) ?? {},
          responseSize: _calculateSize(err.response?.data),
        );
      } catch (e) {
        // Ensure request never stays stuck in pending
        controller.updateRequest(
          requestId,
          statusCode: err.response?.statusCode,
          endTime: DateTime.now(),
          status: RequestStatus.error,
          error: err.toString(),
        );
      }
    }

    super.onError(err, handler);
  }

  RequestMethod _parseMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return RequestMethod.get;
      case 'POST':
        return RequestMethod.post;
      case 'PUT':
        return RequestMethod.put;
      case 'DELETE':
        return RequestMethod.delete;
      case 'PATCH':
        return RequestMethod.patch;
      case 'HEAD':
        return RequestMethod.head;
      case 'OPTIONS':
        return RequestMethod.options;
      default:
        return RequestMethod.get;
    }
  }

  /// Check if the response is an SSE stream based on Content-Type.
  bool _isSSEResponse(Response response) {
    final contentType = response.headers.value('content-type') ?? '';
    return contentType.contains('text/event-stream');
  }

  /// Scenario A: ResponseType.stream — wrap the stream to capture SSE events.
  void _handleStreamSSE(String requestId, Response response) {
    final responseBody = response.data;
    if (responseBody is! ResponseBody) return;

    final parser = SSEParser();
    final responseHeaders = response.headers.map.map(
      (k, v) => MapEntry(k, v.join(', ')),
    );
    final chunks = <String>[];

    // Update request status to streaming
    controller.updateRequest(
      requestId,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      status: RequestStatus.streaming,
      responseHeaders: responseHeaders,
    );

    // Create a transparent proxy stream that taps into the data
    final originalStream = responseBody.stream;
    final proxyController = StreamController<Uint8List>();

    originalStream.listen(
      (chunk) {
        // Forward to user
        proxyController.add(chunk);

        // Parse SSE events from this chunk
        final text = utf8.decode(chunk, allowMalformed: true);
        chunks.add(text);
        final events = parser.addChunk(text);
        if (events.isNotEmpty) {
          controller.appendSSEEvents(requestId, events);
        }
      },
      onError: (Object error) {
        proxyController.addError(error);
        controller.updateRequest(
          requestId,
          endTime: DateTime.now(),
          status: RequestStatus.error,
          error: error.toString(),
          responseBody: chunks.join(),
        );
      },
      onDone: () {
        proxyController.close();
        controller.endSSEStream(
          requestId,
          statusCode: response.statusCode,
          responseSize: _calculateSize(chunks.join()),
        );
      },
      cancelOnError: false,
    );

    // Replace the response stream with our proxy
    response.data = ResponseBody(
      proxyController.stream,
      responseBody.statusCode,
      headers: responseBody.headers,
      statusMessage: responseBody.statusMessage,
      isRedirect: responseBody.isRedirect,
    );
  }

  /// Scenario B: ResponseType.plain — Dio already read all data as String.
  void _handlePlainSSE(String requestId, Response response) {
    final raw = response.data as String;
    final events = SSEParser.parse(raw);

    if (events.isNotEmpty) {
      controller.appendSSEEvents(requestId, events);
    }

    controller.endSSEStream(
      requestId,
      statusCode: response.statusCode,
      responseSize: _calculateSize(raw),
    );

    // Also store the raw response body for the Response tab
    controller.updateRequest(
      requestId,
      responseBody: raw,
      responseHeaders: response.headers.map.map((k, v) => MapEntry(k, v.join(', '))),
    );
  }

  int? _calculateSize(dynamic data) {
    if (data == null) return null;
    if (data is String) return data.length;
    if (data is List) return data.toString().length;
    if (data is Map) return data.toString().length;
    return data.toString().length;
  }
}