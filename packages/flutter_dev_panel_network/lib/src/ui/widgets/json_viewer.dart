import 'dart:convert';
import 'package:flutter/material.dart';

/// 优化版的JSON查看器，使用懒加载和虚拟化提升性能
class JsonViewer extends StatefulWidget {
  final String jsonString;
  final TextStyle? style;
  
  const JsonViewer({
    super.key,
    required this.jsonString,
    this.style,
  });
  
  @override
  State<JsonViewer> createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer> {
  dynamic _jsonData;
  String? _errorMessage;
  final Set<String> _expandedKeys = {};
  
  // 缓存已构建的节点，避免重复构建
  final Map<String, Widget> _widgetCache = {};
  
  @override
  void initState() {
    super.initState();
    _parseJson();
    // 默认展开第一层
    _expandedKeys.add('root');
  }
  
  @override
  void didUpdateWidget(JsonViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jsonString != widget.jsonString) {
      _widgetCache.clear(); // 清除缓存
      _parseJson();
    }
  }
  
  void _parseJson() {
    try {
      _jsonData = json.decode(widget.jsonString);
      _errorMessage = null;
    } catch (e) {
      _jsonData = null;
      _errorMessage = 'Invalid JSON format';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_jsonData == null) {
      // 不是JSON，显示原始文本
      return SelectableText(
        _errorMessage ?? widget.jsonString,
        style: widget.style ?? TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    
    // 直接构建树，不使用横向滚动
    return SingleChildScrollView(
      child: _buildJsonTree(_jsonData, 'root', 0),
    );
  }
  
  Widget _buildJsonTree(dynamic data, String path, int depth) {
    // 深度限制，防止过深的嵌套
    if (depth > 10) {
      return _buildPrimitiveValue('...', Colors.grey);
    }
    
    // 尝试从缓存获取 - 但不缓存可折叠的容器
    final cacheKey = '$path:${data.hashCode}:${_expandedKeys.contains(path)}';
    final isCollapsible = data is List || data is Map;
    if (_widgetCache.containsKey(cacheKey) && depth > 2 && !isCollapsible) {
      return _widgetCache[cacheKey]!;
    }
    
    Widget widget;
    
    if (data == null) {
      widget = _buildPrimitiveValue('null', Colors.grey);
    } else if (data is bool) {
      widget = _buildPrimitiveValue(data.toString(), Colors.blue);
    } else if (data is num) {
      widget = _buildPrimitiveValue(data.toString(), Colors.purple);
    } else if (data is String) {
      widget = _buildStringValue(data);
    } else if (data is List) {
      widget = _buildOptimizedListView(data, path, depth);
    } else if (data is Map) {
      widget = _buildOptimizedMapView(data, path, depth);
    } else {
      widget = _buildPrimitiveValue(data.toString(), null);
    }
    
    // 缓存深层节点 - 但不缓存可折叠的容器
    if (depth > 2 && !isCollapsible) {
      _widgetCache[cacheKey] = widget;
    }
    
    return widget;
  }
  
  Widget _buildPrimitiveValue(String value, Color? color) {
    return Text(
      value,
      style: widget.style?.copyWith(color: color) ?? 
             TextStyle(
               fontFamily: 'monospace',
               fontSize: 12,
               color: color ?? Theme.of(context).colorScheme.onSurface,
             ),
    );
  }
  
  Widget _buildStringValue(String value) {
    // 对于长字符串，使用省略而不是全部显示
    const maxLength = 200;
    final needsTruncate = value.length > maxLength;
    final displayValue = needsTruncate 
        ? '"${value.substring(0, maxLength)}..."' 
        : '"$value"';
    
    final textWidget = Text(
      displayValue,
      style: widget.style?.copyWith(color: Colors.green) ?? 
             const TextStyle(
               fontFamily: 'monospace',
               fontSize: 12,
               color: Colors.green,
             ),
      softWrap: true,
    );
    
    if (!needsTruncate) {
      return textWidget;
    }
    
    // 长字符串可点击查看完整内容
    return GestureDetector(
      onTap: () {
        _showFullContent(context, value);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: textWidget,
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.open_in_new,
            size: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
  
  Widget _buildOptimizedListView(List list, String path, int depth) {
    if (list.isEmpty) {
      return _buildPrimitiveValue('[]', null);
    }
    
    final isExpanded = _expandedKeys.contains(path);
    
    // 简单值的列表可以内联显示
    final hasOnlyPrimitives = list.every((item) => 
      item == null || item is bool || item is num || 
      (item is String && item.length < 50));
    
    if (hasOnlyPrimitives && list.length <= 5 && !isExpanded) {
      // 内联显示简单列表
      final items = list.take(5).map((item) => _formatPrimitive(item)).join(', ');
      final suffix = list.length > 5 ? ', ...' : '';
      return _buildPrimitiveValue('[$items$suffix]', null);
    }
    
    // 对于大列表，使用懒加载
    return _buildCollapsibleContainer(
      path: path,
      isExpanded: isExpanded,
      header: '[',
      footer: ']',
      itemCount: list.length,
      itemBuilder: (index) {
        if (index >= list.length) return const SizedBox.shrink();
        
        final item = list[index];
        final isLast = index == list.length - 1;
        
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '$index:',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Flexible(
                child: _buildJsonTree(item, '$path[$index]', depth + 1),
              ),
              if (!isLast)
                _buildPrimitiveValue(',', null),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildOptimizedMapView(Map map, String path, int depth) {
    if (map.isEmpty) {
      return _buildPrimitiveValue('{}', null);
    }
    
    final isExpanded = _expandedKeys.contains(path);
    final entries = map.entries.toList();
    
    return _buildCollapsibleContainer(
      path: path,
      isExpanded: isExpanded,
      header: '{',
      footer: '}',
      itemCount: entries.length,
      isMap: true,  // 添加标志来区分 Map 和 List
      itemBuilder: (index) {
        if (index >= entries.length) return const SizedBox.shrink();
        
        final entry = entries[index];
        final key = entry.key;
        final value = entry.value;
        final isLast = index == entries.length - 1;
        final fieldPath = '$path.$key';
        
        // 内联显示所有值，不再区分简单复杂
        
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPrimitiveValue('"$key": ', Colors.blue),
              Flexible(
                child: _buildJsonTree(value, fieldPath, depth + 1),
              ),
              if (!isLast)
                _buildPrimitiveValue(',', null),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildCollapsibleContainer({
    required String path,
    required bool isExpanded,
    required String header,
    required String footer,
    required int itemCount,
    required Widget Function(int) itemBuilder,
    bool isMap = false,  // 添加参数来区分 Map 和 List
  }) {
    // 对于超大列表，限制显示数量
    const maxVisibleItems = 100;
    final showMore = itemCount > maxVisibleItems;
    final visibleCount = showMore ? maxVisibleItems : itemCount;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedKeys.remove(path);
                  // 清除该路径下的缓存
                  _widgetCache.removeWhere((key, value) => key.startsWith(path));
                } else {
                  _expandedKeys.add(path);
                }
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _buildPrimitiveValue(header, null),
                  if (!isExpanded)
                    Text(
                      ' $itemCount ${isMap ? (itemCount == 1 ? 'field' : 'fields') : (itemCount == 1 ? 'item' : 'items')} $footer',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) ...[
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 使用ListView.builder进行懒加载
                for (int i = 0; i < visibleCount; i++)
                  itemBuilder(i),
                if (showMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(
                      onPressed: () {
                        // 可以在这里实现加载更多
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Showing first $maxVisibleItems of $itemCount items'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text(
                        '... and ${itemCount - maxVisibleItems} more items',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildPrimitiveValue(footer, null),
        ],
      ],
    );
  }
  
  String _formatPrimitive(dynamic value) {
    if (value == null) return 'null';
    if (value is String) {
      if (value.length > 30) {
        return '"${value.substring(0, 30)}..."';
      }
      return '"$value"';
    }
    return value.toString();
  }
  
  void _showFullContent(BuildContext context, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Full Content'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _widgetCache.clear();
    super.dispose();
  }
}