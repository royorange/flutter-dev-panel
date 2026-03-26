import '../models/sse_event.dart';

/// Zero-dependency SSE (Server-Sent Events) protocol parser.
///
/// Supports both one-shot parsing of complete responses and incremental
/// parsing for streaming scenarios.
///
/// SSE protocol reference: https://html.spec.whatwg.org/multipage/server-sent-events.html
class SSEParser {
  String _buffer = '';
  int _eventIndex = 0;

  /// Parse a complete SSE response text into a list of events.
  static List<SSEEvent> parse(String raw) {
    final parser = SSEParser();
    return parser.addChunk(raw);
  }

  /// Feed a new chunk of data and return any fully parsed events.
  ///
  /// Maintains an internal buffer for incomplete events across calls.
  /// Events are delimited by blank lines (`\n\n`).
  List<SSEEvent> addChunk(String chunk) {
    _buffer += chunk;
    final events = <SSEEvent>[];

    // Split on double-newline (event boundary).
    // Handle both \n\n and \r\n\r\n
    while (true) {
      final lfIndex = _buffer.indexOf('\n\n');
      final crlfIndex = _buffer.indexOf('\r\n\r\n');

      int splitIndex;
      int delimiterLength;

      if (lfIndex == -1 && crlfIndex == -1) break;

      if (lfIndex == -1) {
        splitIndex = crlfIndex;
        delimiterLength = 4;
      } else if (crlfIndex == -1) {
        splitIndex = lfIndex;
        delimiterLength = 2;
      } else if (lfIndex <= crlfIndex) {
        splitIndex = lfIndex;
        delimiterLength = 2;
      } else {
        splitIndex = crlfIndex;
        delimiterLength = 4;
      }

      final block = _buffer.substring(0, splitIndex);
      _buffer = _buffer.substring(splitIndex + delimiterLength);

      final event = _parseBlock(block);
      if (event != null) {
        events.add(event);
      }
    }

    return events;
  }

  /// Reset the parser state.
  void reset() {
    _buffer = '';
    _eventIndex = 0;
  }

  /// Parse a single event block (lines between blank-line delimiters).
  SSEEvent? _parseBlock(String block) {
    if (block.trim().isEmpty) return null;

    String? eventType;
    String? id;
    final dataLines = <String>[];

    final lines = block.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      // Lines starting with ':' are comments
      if (line.startsWith(':')) continue;

      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) {
        // Field with no value
        _processField(line, '', dataLines, (e) => eventType = e, (i) => id = i);
        continue;
      }

      final field = line.substring(0, colonIndex);
      // Strip single leading space after colon per spec
      var value = line.substring(colonIndex + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }

      _processField(field, value, dataLines, (e) => eventType = e, (i) => id = i);
    }

    if (dataLines.isEmpty) return null;

    final data = dataLines.join('\n');
    return SSEEvent(
      index: _eventIndex++,
      event: eventType,
      data: data,
      id: id,
      timestamp: DateTime.now(),
    );
  }

  void _processField(
    String field,
    String value,
    List<String> dataLines,
    void Function(String) setEvent,
    void Function(String) setId,
  ) {
    switch (field) {
      case 'data':
        dataLines.add(value);
        break;
      case 'event':
        setEvent(value);
        break;
      case 'id':
        setId(value);
        break;
      case 'retry':
        // retry is part of the spec but not relevant for monitoring
        break;
    }
  }
}
