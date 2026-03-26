import 'package:flutter/material.dart';
import '../../models/network_request.dart';

class RequestListItem extends StatelessWidget {
  final NetworkRequest request;
  final VoidCallback onTap;

  const RequestListItem({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildMethodChip(colorScheme),
                  const SizedBox(width: 8),
                  _buildStatusChip(colorScheme),
                  const Spacer(),
                  if (request.duration != null)
                    Text(
                      '${request.duration!.inMilliseconds}ms',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.url,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(request.startTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (request.responseSize != null) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.download,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatSize(request.responseSize!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodChip(ColorScheme colorScheme) {
    Color backgroundColor;
    Color foregroundColor;
    
    switch (request.method) {
      case RequestMethod.get:
        backgroundColor = Colors.blue.shade100;
        foregroundColor = Colors.blue.shade700;
        break;
      case RequestMethod.post:
        backgroundColor = Colors.green.shade100;
        foregroundColor = Colors.green.shade700;
        break;
      case RequestMethod.put:
        backgroundColor = Colors.orange.shade100;
        foregroundColor = Colors.orange.shade700;
        break;
      case RequestMethod.delete:
        backgroundColor = Colors.red.shade100;
        foregroundColor = Colors.red.shade700;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        foregroundColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        request.methodString,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: foregroundColor,
        ),
      ),
    );
  }

  Widget _buildStatusChip(ColorScheme colorScheme) {
    if (request.status == RequestStatus.pending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.amber.shade700),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Pending',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade700,
              ),
            ),
          ],
        ),
      );
    }

    // SSE streaming or completed SSE
    if (request.status == RequestStatus.streaming || request.isSSE) {
      final isStreaming = request.status == RequestStatus.streaming;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purple.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStreaming) ...[
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.purple.shade700),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              'SSE${request.sseEventCount > 0 ? ' ${request.sseEventCount}' : ''}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
            ),
          ],
        ),
      );
    }

    final statusCode = request.statusCode;
    if (statusCode == null) return const SizedBox.shrink();

    Color backgroundColor;
    Color foregroundColor;

    if (statusCode >= 200 && statusCode < 300) {
      backgroundColor = Colors.green.shade100;
      foregroundColor = Colors.green.shade700;
    } else if (statusCode >= 300 && statusCode < 400) {
      backgroundColor = Colors.blue.shade100;
      foregroundColor = Colors.blue.shade700;
    } else if (statusCode >= 400 && statusCode < 500) {
      backgroundColor = Colors.orange.shade100;
      foregroundColor = Colors.orange.shade700;
    } else {
      backgroundColor = Colors.red.shade100;
      foregroundColor = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusCode.toString(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: foregroundColor,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${(time.millisecond ~/ 10).toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}