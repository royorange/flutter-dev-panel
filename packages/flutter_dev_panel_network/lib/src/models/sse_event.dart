/// Represents a single Server-Sent Event received from an SSE stream.
class SSEEvent {
  /// Sequential index of this event in the stream.
  final int index;

  /// Event type (e.g., "message"). Null if not specified.
  final String? event;

  /// Event data payload.
  final String data;

  /// Event ID. Null if not specified.
  final String? id;

  /// Timestamp when this event was received.
  final DateTime timestamp;

  const SSEEvent({
    required this.index,
    this.event,
    required this.data,
    this.id,
    required this.timestamp,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    if (event != null) buffer.writeln('event: $event');
    if (id != null) buffer.writeln('id: $id');
    buffer.writeln('data: $data');
    return buffer.toString();
  }
}
