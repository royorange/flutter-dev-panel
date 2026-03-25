import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dev_panel/flutter_dev_panel.dart';

/// Console 模块的状态管理
class ConsoleProvider extends ChangeNotifier {
  /// 日志列表
  List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  /// 过滤后的日志列表
  List<LogEntry> _filteredLogs = [];
  List<LogEntry> get filteredLogs => List.unmodifiable(_filteredLogs);

  /// 缓存的日志级别统计（避免每次 O(n) 遍历）
  final Map<LogLevel, int> _cachedStats = {
    for (final level in LogLevel.values) level: 0,
  };

  /// 当前选中的日志级别过滤
  LogLevel? _selectedLevel;
  LogLevel? get selectedLevel => _selectedLevel;

  /// 搜索关键词
  String _searchText = '';
  String get searchText => _searchText;
  
  /// 是否自动滚动到底部
  bool _autoScroll = true;
  bool get autoScroll => _autoScroll;
  
  /// 是否暂停接收新日志 - 从 DevLogger 获取状态
  bool get isPaused => DevLogger.instance.isPaused;
  
  /// 日志流订阅
  StreamSubscription<LogEntry>? _logSubscription;
  
  /// ScrollController for auto-scroll
  final ScrollController scrollController = ScrollController();
  
  /// 搜索防抖定时器
  Timer? _searchDebounceTimer;
  
  /// 批量更新定时器（性能优化）
  Timer? _batchUpdateTimer;
  final List<LogEntry> _pendingLogs = [];
  
  ConsoleProvider() {
    _initialize();
  }
  
  void _initialize() {
    // Sync auto-scroll setting from DevLogger config
    _autoScroll = DevLogger.instance.config.autoScroll;
    _loadExistingLogs();
    _startListening();
  }
  
  @override
  void dispose() {
    _logSubscription?.cancel();
    _searchDebounceTimer?.cancel();
    _batchUpdateTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }
  
  /// 加载已存在的日志
  void _loadExistingLogs() {
    final existingLogs = DevLogger.instance.logs;
    _logs = existingLogs.toList();
    _rebuildCachedStats();
    _applyFilters();

    // 加载完成后如果启用了自动滚动，延迟滚动到底部
    if (_autoScroll && _logs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }
  
  /// 开始监听新日志
  void _startListening() {
    _logSubscription = DevLogger.instance.logStream.listen((log) {
      // 日志已经在 DevLogger 中被过滤了，这里直接添加
      _addLogWithBatch(log);
    });
  }
  
  /// 批量添加日志（性能优化）
  void _addLogWithBatch(LogEntry log) {
    _pendingLogs.add(log);
    
    // 取消之前的批量更新定时器
    _batchUpdateTimer?.cancel();
    
    // 如果积累的日志超过10条，立即更新
    if (_pendingLogs.length >= 10) {
      _processPendingLogs();
    } else {
      // 否则等待50ms再更新，避免频繁更新UI
      _batchUpdateTimer = Timer(const Duration(milliseconds: 50), () {
        _processPendingLogs();
      });
    }
  }
  
  /// 处理待添加的日志
  void _processPendingLogs() {
    if (_pendingLogs.isEmpty) return;

    // 增量更新缓存统计
    for (final log in _pendingLogs) {
      _cachedStats[log.level] = (_cachedStats[log.level] ?? 0) + 1;
    }

    _logs.addAll(_pendingLogs);

    // 使用配置中的最大日志数量
    final maxLogs = DevLogger.instance.config.maxLogs;
    if (_logs.length > maxLogs) {
      // 扣减被驱逐日志的缓存统计
      final evicted = _logs.sublist(0, _logs.length - maxLogs);
      for (final log in evicted) {
        _cachedStats[log.level] = (_cachedStats[log.level] ?? 1) - 1;
      }
      _logs = _logs.sublist(_logs.length - maxLogs);
    }

    _pendingLogs.clear();
    _applyFilters();

    // 仅在启用自动滚动时滚动到底部
    if (_autoScroll) {
      _scrollToBottom();
    }
  }
  
  /// 应用过滤器
  void _applyFilters() {
    var filtered = _logs;
    
    // 按日志级别过滤 - 只显示选中的级别
    if (_selectedLevel != null) {
      filtered = filtered.where((log) => 
        log.level == _selectedLevel
      ).toList();
    }
    
    // 按搜索文本过滤
    if (_searchText.isNotEmpty) {
      final search = _searchText.toLowerCase();
      filtered = filtered.where((log) =>
        log.message.toLowerCase().contains(search) ||
        (log.error?.toLowerCase().contains(search) ?? false)
      ).toList();
    }
    
    _filteredLogs = filtered;
    notifyListeners();
  }
  
  /// 滚动到底部
  void _scrollToBottom() {
    if (_autoScroll && scrollController.hasClients) {
      // 使用 post frame callback 确保在UI更新后滚动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          // 使用 jumpTo 立即跳转到底部
          scrollController.jumpTo(
            scrollController.position.maxScrollExtent,
          );
        }
      });
    }
  }
  
  /// 立即滚动到底部（用于页面打开时）
  void scrollToBottomNow() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(
        scrollController.position.maxScrollExtent,
      );
    }
  }
  
  /// 清空日志
  void clearLogs() {
    _logs.clear();
    _filteredLogs.clear();
    _pendingLogs.clear();
    for (final level in LogLevel.values) {
      _cachedStats[level] = 0;
    }
    DevLogger.instance.clear();
    notifyListeners();
  }
  
  /// 切换暂停状态
  void togglePause() {
    DevLogger.instance.togglePause();
    notifyListeners();
  }
  
  /// 切换自动滚动
  void toggleAutoScroll() {
    _autoScroll = !_autoScroll;
    // Update config in DevLogger
    DevLogger.instance.updateConfig(
      DevLogger.instance.config.copyWith(autoScroll: _autoScroll),
    );
    if (_autoScroll) {
      _scrollToBottom();
    }
    notifyListeners();
  }
  
  /// 设置日志级别过滤
  void setLevelFilter(LogLevel? level) {
    if (_selectedLevel != level) {
      _selectedLevel = level;
      _applyFilters();
    }
  }
  
  /// 设置搜索文本（带防抖）
  void setSearchText(String text) {
    _searchText = text;
    
    // 取消之前的防抖定时器
    _searchDebounceTimer?.cancel();
    
    // 设置新的防抖定时器
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
    });
  }
  
  /// 获取日志级别的颜色
  Color getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return Colors.grey;
      case LogLevel.debug:
        return Colors.blue;
      case LogLevel.info:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }
  
  /// 获取日志级别的图标
  IconData getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return Icons.chat_bubble_outline;
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.warning:
        return Icons.warning_amber;
      case LogLevel.error:
        return Icons.error_outline;
    }
  }
  
  /// 获取日志统计信息（O(1)，使用缓存）
  Map<LogLevel, int> getLogStatistics() => Map.unmodifiable(_cachedStats);

  /// 快捷获取错误数（FAB 使用）
  int get errorCount => _cachedStats[LogLevel.error] ?? 0;

  /// 快捷获取警告数（FAB 使用）
  int get warningCount => _cachedStats[LogLevel.warning] ?? 0;

  /// 重建缓存统计（仅在初始化或批量操作时调用）
  void _rebuildCachedStats() {
    for (final level in LogLevel.values) {
      _cachedStats[level] = 0;
    }
    for (final log in _logs) {
      _cachedStats[log.level] = (_cachedStats[log.level] ?? 0) + 1;
    }
  }
}