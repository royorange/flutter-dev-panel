import 'dart:convert';

enum RequestStatus {
  pending,
  success,
  error,
  cancelled,
}

enum RequestMethod {
  get,
  post,
  put,
  delete,
  patch,
  head,
  options,
}

class NetworkRequest {
  final String id;
  final String url;
  final RequestMethod method;
  final Map<String, dynamic> headers;
  final dynamic requestBody;
  final dynamic responseBody;
  final int? statusCode;
  final String? statusMessage;
  final DateTime startTime;
  final DateTime? endTime;
  final RequestStatus status;
  final String? error;
  final Map<String, dynamic> responseHeaders;
  final int? responseSize;
  final int? requestSize;

  NetworkRequest({
    required this.id,
    required this.url,
    required this.method,
    required this.headers,
    this.requestBody,
    this.responseBody,
    this.statusCode,
    this.statusMessage,
    required this.startTime,
    this.endTime,
    required this.status,
    this.error,
    this.responseHeaders = const {},
    this.responseSize,
    this.requestSize,
  });

  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  String get methodString {
    return method.name.toUpperCase();
  }

  bool get isSuccess {
    return statusCode != null && statusCode! >= 200 && statusCode! < 300;
  }

  bool get isError {
    return status == RequestStatus.error || (statusCode != null && statusCode! >= 400);
  }

  String get formattedRequestBody {
    if (requestBody == null) return '';
    if (requestBody is String) return requestBody;
    try {
      return const JsonEncoder.withIndent('  ').convert(requestBody);
    } catch (_) {
      return requestBody.toString();
    }
  }

  String get formattedResponseBody {
    if (responseBody == null) return '';
    if (responseBody is String) return responseBody;
    try {
      return const JsonEncoder.withIndent('  ').convert(responseBody);
    } catch (_) {
      return responseBody.toString();
    }
  }

  NetworkRequest copyWith({
    String? id,
    String? url,
    RequestMethod? method,
    Map<String, dynamic>? headers,
    dynamic requestBody,
    dynamic responseBody,
    int? statusCode,
    String? statusMessage,
    DateTime? startTime,
    DateTime? endTime,
    RequestStatus? status,
    String? error,
    Map<String, dynamic>? responseHeaders,
    int? responseSize,
    int? requestSize,
  }) {
    return NetworkRequest(
      id: id ?? this.id,
      url: url ?? this.url,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      requestBody: requestBody ?? this.requestBody,
      responseBody: responseBody ?? this.responseBody,
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      error: error ?? this.error,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseSize: responseSize ?? this.responseSize,
      requestSize: requestSize ?? this.requestSize,
    );
  }
}