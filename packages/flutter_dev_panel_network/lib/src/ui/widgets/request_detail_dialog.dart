import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/network_request.dart';

class RequestDetailDialog extends StatefulWidget {
  final NetworkRequest request;

  const RequestDetailDialog({
    super.key,
    required this.request,
  });

  @override
  State<RequestDetailDialog> createState() => _RequestDetailDialogState();
}

class _RequestDetailDialogState extends State<RequestDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 24,
        vertical: isSmallScreen ? 16 : 32,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: screenSize.height * (isSmallScreen ? 0.95 : 0.85),
          ),
          child: Scaffold(
            body: Column(
              children: [
                _buildHeader(context, colorScheme),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: isSmallScreen,
                    labelStyle: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Request'),
                      Tab(text: 'Response'),
                      Tab(text: 'Headers'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildRequestTab(),
                      _buildResponseTab(),
                      _buildHeadersTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
      ),
      child: Row(
        children: [
          _buildMethodBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.url,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (widget.request.statusCode != null) ...[
                      Icon(
                        widget.request.isError ? Icons.error : Icons.check_circle,
                        size: 14,
                        color: widget.request.isError ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.request.statusCode} ${widget.request.statusMessage ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (widget.request.duration != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.timer, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.request.duration!.inMilliseconds}ms',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            iconSize: isSmallScreen ? 20 : 24,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodBadge() {
    Color backgroundColor;
    Color foregroundColor = Colors.white;
    
    switch (widget.request.method) {
      case RequestMethod.get:
        backgroundColor = Colors.blue;
        break;
      case RequestMethod.post:
        backgroundColor = Colors.green;
        break;
      case RequestMethod.put:
        backgroundColor = Colors.orange;
        break;
      case RequestMethod.delete:
        backgroundColor = Colors.red;
        break;
      case RequestMethod.patch:
        backgroundColor = Colors.purple;
        break;
      case RequestMethod.head:
        backgroundColor = Colors.teal;
        break;
      case RequestMethod.options:
        backgroundColor = Colors.indigo;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        widget.request.method.name.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: foregroundColor,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final theme = Theme.of(context);
    final items = <_InfoItem>[
      _InfoItem('URL', widget.request.url),
      _InfoItem('Method', widget.request.method.name.toUpperCase()),
      if (widget.request.statusCode != null)
        _InfoItem('Status Code', '${widget.request.statusCode}'),
      if (widget.request.statusMessage != null)
        _InfoItem('Status Message', widget.request.statusMessage!),
      _InfoItem('Start Time', _formatDateTime(widget.request.startTime)),
      if (widget.request.endTime != null)
        _InfoItem('End Time', _formatDateTime(widget.request.endTime!)),
      if (widget.request.duration != null)
        _InfoItem('Duration', '${widget.request.duration!.inMilliseconds}ms'),
      if (widget.request.requestBody != null)
        _InfoItem('Request Size', _formatSize(_calculateSize(widget.request.requestBody))),
      if (widget.request.responseBody != null)
        _InfoItem('Response Size', _formatSize(_calculateSize(widget.request.responseBody))),
      if (widget.request.error != null)
        _InfoItem('Error', widget.request.error!),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.map((item) => _buildInfoRow(item)).toList(),
    );
  }

  Widget _buildRequestTab() {
    final requestBody = widget.request.formattedRequestBody;
    
    if (requestBody.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No request body',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    return _buildCodeViewer(requestBody);
  }

  Widget _buildResponseTab() {
    final responseBody = widget.request.formattedResponseBody;
    
    if (responseBody.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              widget.request.status == RequestStatus.pending 
                  ? 'Waiting for response...' 
                  : 'No response body',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    return _buildCodeViewer(responseBody);
  }

  Widget _buildHeadersTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: const TabBar(
              tabs: [
                Tab(text: 'Request Headers'),
                Tab(text: 'Response Headers'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildHeadersList(widget.request.headers),
                _buildHeadersList(widget.request.responseHeaders ?? {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadersList(Map<String, dynamic> headers) {
    if (headers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No headers available',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final sortedKeys = headers.keys.toList()..sort();
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final value = headers[key];
        return _buildInfoRow(_InfoItem(key, value.toString()));
      },
    );
  }

  Widget _buildInfoRow(_InfoItem item) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 100 : 150,
            child: Text(
              item.label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
                fontSize: isSmallScreen ? 11 : 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              item.value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: isSmallScreen ? 11 : 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: item.value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied ${item.label}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeViewer(String code) {
    final theme = Theme.of(context);
    
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}:'
           '${dateTime.second.toString().padLeft(2, '0')}.'
           '${dateTime.millisecond.toString().padLeft(3, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int _calculateSize(dynamic data) {
    if (data == null) return 0;
    return data.toString().length;
  }
}

class _InfoItem {
  final String label;
  final String value;

  _InfoItem(this.label, this.value);
}