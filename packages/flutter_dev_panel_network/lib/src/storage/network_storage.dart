import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_request.dart';

/// 网络请求持久化存储
class NetworkStorage {
  static const String _storageKey = 'flutter_dev_panel_network_requests';
  static const String _maxRequestsKey = 'flutter_dev_panel_network_max_requests';
  
  /// 保存请求列表到本地存储
  static Future<void> saveRequests(List<NetworkRequest> requests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 转换为可序列化的格式
      final List<Map<String, dynamic>> jsonList = requests.map((request) {
        return _requestToJson(request);
      }).toList();
      
      final String jsonString = json.encode(jsonList);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      // 忽略存储错误，避免影响主功能
      debugPrint('Failed to save network requests: $e');
    }
  }
  
  /// 从本地存储加载请求列表
  static Future<List<NetworkRequest>> loadRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) {
        return _requestFromJson(json as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      debugPrint('Failed to load network requests: $e');
      return [];
    }
  }
  
  /// 清除存储的请求
  static Future<void> clearRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('Failed to clear network requests: $e');
    }
  }
  
  /// 保存最大请求数设置
  static Future<void> saveMaxRequests(int maxRequests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_maxRequestsKey, maxRequests);
    } catch (e) {
      debugPrint('Failed to save max requests: $e');
    }
  }
  
  /// 加载最大请求数设置
  static Future<int> loadMaxRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_maxRequestsKey) ?? 100;
    } catch (e) {
      debugPrint('Failed to load max requests: $e');
      return 100;
    }
  }
  
  /// 将NetworkRequest转换为JSON
  static Map<String, dynamic> _requestToJson(NetworkRequest request) {
    return {
      'id': request.id,
      'url': request.url,
      'method': request.method.index,
      'headers': request.headers,
      'requestBody': _encodeBody(request.requestBody),
      'responseBody': _encodeBody(request.responseBody),
      'statusCode': request.statusCode,
      'statusMessage': request.statusMessage,
      'startTime': request.startTime.toIso8601String(),
      'endTime': request.endTime?.toIso8601String(),
      'status': request.status.index,
      'error': request.error,
      'responseHeaders': request.responseHeaders,
      'responseSize': request.responseSize,
      'requestSize': request.requestSize,
    };
  }
  
  /// 从JSON创建NetworkRequest
  static NetworkRequest _requestFromJson(Map<String, dynamic> json) {
    return NetworkRequest(
      id: json['id'] as String,
      url: json['url'] as String,
      method: RequestMethod.values[json['method'] as int],
      headers: Map<String, dynamic>.from(json['headers'] ?? {}),
      requestBody: _decodeBody(json['requestBody']),
      responseBody: _decodeBody(json['responseBody']),
      statusCode: json['statusCode'] as int?,
      statusMessage: json['statusMessage'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      status: RequestStatus.values[json['status'] as int],
      error: json['error'] as String?,
      responseHeaders: Map<String, dynamic>.from(json['responseHeaders'] ?? {}),
      responseSize: json['responseSize'] as int?,
      requestSize: json['requestSize'] as int?,
    );
  }
  
  /// 编码请求/响应体
  static dynamic _encodeBody(dynamic body) {
    if (body == null) return null;
    if (body is String) return body;
    try {
      // 尝试将对象转换为JSON字符串
      return json.encode(body);
    } catch (e) {
      // 如果无法序列化，返回toString结果
      return body.toString();
    }
  }
  
  /// 解码请求/响应体
  static dynamic _decodeBody(dynamic body) {
    if (body == null) return null;
    if (body is! String) return body;
    
    try {
      // 尝试解析JSON
      return json.decode(body);
    } catch (e) {
      // 如果不是有效的JSON，返回原字符串
      return body;
    }
  }
}