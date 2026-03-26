import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/network_request.dart';
import '../../models/sse_event.dart';

/// Tab showing SSE events in a Chrome DevTools EventStream style.
class SSEEventsTab extends StatelessWidget {
  final NetworkRequest request;

  const SSEEventsTab({
    super.key,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = request.sseEvents;

    return Column(
      children: [
        _buildStatsBar(context, theme),
        const Divider(height: 1),
        Expanded(
          child: events.isEmpty
              ? _buildEmptyState(context, theme)
              : _buildEventList(context, theme, events),
        ),
        _buildBottomBar(context, theme, events),
      ],
    );
  }

  Widget _buildStatsBar(BuildContext context, ThemeData theme) {
    final isStreaming = request.status == RequestStatus.streaming;
    final eventCount = request.sseEventCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text(
            '$eventCount event${eventCount == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isStreaming
                  ? Colors.purple.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isStreaming ? 'Streaming...' : 'Completed',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isStreaming
                    ? Colors.purple.shade700
                    : Colors.green.shade700,
              ),
            ),
          ),
          const Spacer(),
          if (request.duration != null)
            Text(
              '${request.duration!.inMilliseconds}ms',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    final isStreaming = request.status == RequestStatus.streaming;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isStreaming ? Icons.stream : Icons.inbox,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isStreaming ? 'Waiting for events...' : 'No events received',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(
    BuildContext context,
    ThemeData theme,
    List<SSEEvent> events,
  ) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        return _SSEEventCard(event: events[index]);
      },
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    ThemeData theme,
    List<SSEEvent> events,
  ) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: () {
              final allData = events.map((e) => e.toString()).join('\n');
              Clipboard.setData(ClipboardData(text: allData));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All events copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy All'),
          ),
        ],
      ),
    );
  }
}

class _SSEEventCard extends StatefulWidget {
  final SSEEvent event;

  const _SSEEventCard({required this.event});

  @override
  State<_SSEEventCard> createState() => _SSEEventCardState();
}

class _SSEEventCardState extends State<_SSEEventCard> {
  bool _expanded = false;

  /// Whether data content is long enough to warrant collapsing.
  bool get _isCollapsible => widget.event.data.length > 200;

  @override
  void initState() {
    super.initState();
    _expanded = !_isCollapsible;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event;

    return InkWell(
      onTap: _isCollapsible ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: index, event type, timestamp
            Row(
              children: [
                Text(
                  '#${event.index}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                    fontFamily: 'monospace',
                  ),
                ),
                if (event.event != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.purple.shade200,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      event.event!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (event.id != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'id: ${event.id}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatTimestamp(event.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
                if (_isCollapsible) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            // Data content
            Text(
              _expanded ? _formatData(event.data) : _truncateData(event.data),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Try to pretty-print JSON data, otherwise return as-is.
  String _formatData(String data) {
    try {
      final parsed = json.decode(data);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (_) {
      return data;
    }
  }

  /// Truncate long data for collapsed view.
  String _truncateData(String data) {
    if (data.length <= 200) return data;
    return '${data.substring(0, 200)}...';
  }

  String _formatTimestamp(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }
}
