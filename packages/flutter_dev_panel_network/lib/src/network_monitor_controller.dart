import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dev_panel/flutter_dev_panel.dart' show MonitoringDataProvider;
import 'models/network_request.dart';
import 'models/network_filter.dart';
import 'models/sse_event.dart';
import 'storage/network_storage.dart';

class NetworkMonitorController extends ChangeNotifier {
  final List<NetworkRequest> _requests = [];
  NetworkFilter _filter = const NetworkFilter();
  int _maxRequests;
  bool _isPaused = false;
  bool _isInitialized = false;

  // 缓存统计值，避免每次 getter 都 O(n) 遍历
  int _cachedSuccessCount = 0;
  int _cachedErrorCount = 0;
  int _cachedPendingCount = 0;

  // 当前会话的统计（不包括历史记录）
  int _sessionRequestCount = 0;
  int _sessionSuccessCount = 0;
  int _sessionErrorCount = 0;
  int _sessionPendingCount = 0;

  // 防抖保存：避免每个请求都立即写磁盘
  Timer? _saveDebounceTimer;
  static const _saveDebounceDuration = Duration(milliseconds: 500);
  bool _hasPendingSave = false;

  // SSE 防抖：合并短时间内的多次 SSE event 追加为一次 UI 更新
  Timer? _sseDebounceTimer;
  static const _sseDebounceDuration = Duration(milliseconds: 100);

  /// Maximum SSE events kept per request (FIFO eviction).
  static const maxSSEEventsPerRequest = 500;

  NetworkMonitorController({int maxRequests = 100}) : _maxRequests = maxRequests {
    _initialize();
  }

  /// 初始化，加载历史记录
  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 加载保存的最大请求数
    _maxRequests = await NetworkStorage.loadMaxRequests();

    // 加载历史请求记录
    final savedRequests = await NetworkStorage.loadRequests();
    if (savedRequests.isNotEmpty) {
      // 过滤掉pending/streaming状态的请求（这些是异常中断的）
      final completedRequests = savedRequests
          .where((r) => r.status != RequestStatus.pending && r.status != RequestStatus.streaming)
          .take(_maxRequests)
          .toList();

      if (completedRequests.isNotEmpty) {
        _requests.addAll(completedRequests);
        _rebuildCachedStats();
        notifyListeners();
      }
    }

    // 初始化时不更新MonitoringDataProvider，因为这些都是历史数据
  }

  List<NetworkRequest> get requests => _filteredRequests;

  List<NetworkRequest> get _filteredRequests {
    return _requests.where((request) => _filter.matches(request)).toList();
  }

  List<NetworkRequest> get allRequests => List.unmodifiable(_requests);

  NetworkFilter get filter => _filter;

  bool get isPaused => _isPaused;

  int get maxRequests => _maxRequests;

  int get totalRequests => _requests.length;

  int get successCount => _cachedSuccessCount;

  int get errorCount => _cachedErrorCount;

  int get pendingCount => _cachedPendingCount;

  // 当前会话的统计（用于FAB显示）
  int get sessionRequestCount => _sessionRequestCount;
  int get sessionSuccessCount => _sessionSuccessCount;
  int get sessionErrorCount => _sessionErrorCount;
  int get sessionPendingCount => _sessionPendingCount;
  bool get hasSessionActivity => _sessionRequestCount > 0 || _sessionPendingCount > 0;

  void addRequest(NetworkRequest request) {
    if (_isPaused) return;

    _requests.insert(0, request);

    if (_requests.length > _maxRequests) {
      final evicted = _requests.removeLast();
      // 扣减被驱逐请求的缓存统计
      switch (evicted.status) {
        case RequestStatus.success: _cachedSuccessCount--; break;
        case RequestStatus.error: case RequestStatus.cancelled: _cachedErrorCount--; break;
        case RequestStatus.pending: case RequestStatus.streaming: _cachedPendingCount--; break;
      }
    }

    // 增量更新缓存统计
    _cachedPendingCount++;

    // 更新会话统计
    _sessionRequestCount++;
    _sessionPendingCount++;

    // 防抖保存到本地存储
    _debounceSave();

    // 更新全局监控数据
    MonitoringDataProvider.instance.onRequestStart();

    notifyListeners();
  }

  /// 防抖保存：合并短时间内的多次写入为一次磁盘 I/O
  void _debounceSave() {
    _hasPendingSave = true;
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(_saveDebounceDuration, () {
      if (_hasPendingSave) {
        _hasPendingSave = false;
        _saveRequestsNow();
      }
    });
  }

  /// 立即保存到本地存储
  Future<void> _saveRequestsNow() async {
    try {
      await NetworkStorage.saveRequests(_requests);
    } catch (e) {
      debugPrint('NetworkMonitorController: failed to save requests: $e');
    }
  }

  /// 重建缓存统计（仅在初始化或批量操作时调用）
  void _rebuildCachedStats() {
    int success = 0;
    int error = 0;
    int pending = 0;
    for (final r in _requests) {
      switch (r.status) {
        case RequestStatus.success:
          success++;
          break;
        case RequestStatus.error:
        case RequestStatus.cancelled:
          error++;
          break;
        case RequestStatus.pending:
        case RequestStatus.streaming:
          pending++;
          break;
      }
    }
    _cachedSuccessCount = success;
    _cachedErrorCount = error;
    _cachedPendingCount = pending;
  }

  void updateRequest(
    String id, {
    dynamic responseBody,
    int? statusCode,
    String? statusMessage,
    DateTime? endTime,
    RequestStatus? status,
    String? error,
    Map<String, dynamic>? responseHeaders,
    int? responseSize,
  }) {
    if (_isPaused) return;

    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      final oldStatus = _requests[index].status;

      _requests[index] = _requests[index].copyWith(
        responseBody: responseBody,
        statusCode: statusCode,
        statusMessage: statusMessage,
        endTime: endTime,
        status: status,
        error: error,
        responseHeaders: responseHeaders,
        responseSize: responseSize,
      );

      // 增量更新缓存统计
      if (status != null && status != oldStatus) {
        // 减去旧状态
        switch (oldStatus) {
          case RequestStatus.success: _cachedSuccessCount--; break;
          case RequestStatus.error: case RequestStatus.cancelled: _cachedErrorCount--; break;
          case RequestStatus.pending: case RequestStatus.streaming: _cachedPendingCount--; break;
        }
        // 加上新状态
        switch (status) {
          case RequestStatus.success: _cachedSuccessCount++; break;
          case RequestStatus.error: case RequestStatus.cancelled: _cachedErrorCount++; break;
          case RequestStatus.pending: case RequestStatus.streaming: _cachedPendingCount++; break;
        }
      }

      // 更新会话统计
      if (status == RequestStatus.success) {
        if (_sessionPendingCount > 0) _sessionPendingCount--;
        _sessionSuccessCount++;
      } else if (status == RequestStatus.error || status == RequestStatus.cancelled) {
        if (_sessionPendingCount > 0) _sessionPendingCount--;
        _sessionErrorCount++;
      }

      // 防抖保存到本地存储
      _debounceSave();

      // 更新全局监控数据
      if (status == RequestStatus.success || status == RequestStatus.error) {
        MonitoringDataProvider.instance.onRequestComplete(status == RequestStatus.error || error != null);
      }

      // 更新统计 - 使用会话统计
      MonitoringDataProvider.instance.updateNetworkData(
        totalRequests: _sessionRequestCount,
        errorRequests: _sessionErrorCount,
        pendingRequests: _sessionPendingCount,
      );

      notifyListeners();
    }
  }

  /// Append SSE events to a streaming request.
  ///
  /// Uses debounced [notifyListeners] (100ms) to batch rapid event arrivals.
  /// Events beyond [maxSSEEventsPerRequest] are evicted FIFO.
  /// SSE events are NOT persisted to storage.
  void appendSSEEvents(String requestId, List<SSEEvent> events) {
    if (_isPaused || events.isEmpty) return;

    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;

    final request = _requests[index];
    final updatedEvents = List<SSEEvent>.from(request.sseEvents)..addAll(events);

    // FIFO eviction
    if (updatedEvents.length > maxSSEEventsPerRequest) {
      updatedEvents.removeRange(0, updatedEvents.length - maxSSEEventsPerRequest);
    }

    _requests[index] = request.copyWith(
      isSSE: true,
      sseEvents: updatedEvents,
      status: RequestStatus.streaming,
    );

    // Debounced UI update — no persistence for SSE events
    _sseDebounceTimer?.cancel();
    _sseDebounceTimer = Timer(_sseDebounceDuration, () {
      notifyListeners();
    });
  }

  /// Mark an SSE stream as completed.
  void endSSEStream(String requestId, {int? statusCode, int? responseSize}) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;

    final request = _requests[index];
    final oldStatus = request.status;

    _requests[index] = request.copyWith(
      status: RequestStatus.success,
      statusCode: statusCode,
      endTime: DateTime.now(),
      responseSize: responseSize,
    );

    // Update cached stats: streaming -> success
    if (oldStatus == RequestStatus.streaming || oldStatus == RequestStatus.pending) {
      _cachedPendingCount--;
      _cachedSuccessCount++;
    }

    // Update session stats
    if (_sessionPendingCount > 0) _sessionPendingCount--;
    _sessionSuccessCount++;

    // Persist the final state (without SSE events — handled by NetworkStorage)
    _debounceSave();

    MonitoringDataProvider.instance.onRequestComplete(false);
    MonitoringDataProvider.instance.updateNetworkData(
      totalRequests: _sessionRequestCount,
      errorRequests: _sessionErrorCount,
      pendingRequests: _sessionPendingCount,
    );

    notifyListeners();
  }

  void clearRequests() {
    _requests.clear();
    // 重置缓存统计
    _cachedSuccessCount = 0;
    _cachedErrorCount = 0;
    _cachedPendingCount = 0;
    // 重置会话统计
    _sessionRequestCount = 0;
    _sessionSuccessCount = 0;
    _sessionErrorCount = 0;
    _sessionPendingCount = 0;
    NetworkStorage.clearRequests(); // 清除本地存储
    notifyListeners();
  }

  void removeRequest(String id) {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      // 增量更新缓存统计
      switch (_requests[index].status) {
        case RequestStatus.success: _cachedSuccessCount--; break;
        case RequestStatus.error: case RequestStatus.cancelled: _cachedErrorCount--; break;
        case RequestStatus.pending: case RequestStatus.streaming: _cachedPendingCount--; break;
      }
      _requests.removeAt(index);
      notifyListeners();
    }
  }

  void setFilter(NetworkFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _filter = _filter.copyWith(searchQuery: query);
    notifyListeners();
  }

  void setMethodFilter(RequestMethod? method) {
    _filter = _filter.copyWith(method: method);
    notifyListeners();
  }

  void setStatusFilter(RequestStatus? status) {
    _filter = _filter.copyWith(status: status);
    notifyListeners();
  }

  void setShowOnlyErrors(bool showOnlyErrors) {
    _filter = _filter.copyWith(showOnlyErrors: showOnlyErrors);
    notifyListeners();
  }

  void clearFilters() {
    _filter = _filter.clearFilters();
    notifyListeners();
  }

  void setPaused(bool paused) {
    _isPaused = paused;
    notifyListeners();
  }

  void togglePause() {
    _isPaused = !_isPaused;
    notifyListeners();
  }

  void setMaxRequests(int max) {
    _maxRequests = max;
    while (_requests.length > _maxRequests) {
      _requests.removeLast();
    }
    _rebuildCachedStats();
    NetworkStorage.saveMaxRequests(max); // 保存设置
    _debounceSave(); // 保存调整后的请求列表
    notifyListeners();
  }

  NetworkRequest? getRequestById(String id) {
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    _sseDebounceTimer?.cancel();
    if (_hasPendingSave) {
      // 快照当前数据后再保存，避免 clear 后保存空列表
      final snapshot = List<NetworkRequest>.from(_requests);
      NetworkStorage.saveRequests(snapshot);
    }
    _requests.clear();
    super.dispose();
  }
}