/// An abstraction over the behavior of transports. This is designed to support the framework and not intended for use by applications.
abstract class Transport {
  void Function(dynamic data) onreceive;
  void Function(Exception error) onclose;

  Future<void> connectAsync(String url, TransferFormat transferFormat);
  Future<void> sendAsync(dynamic data);
  Future<void> stopAsync();
}

/// Specifies a specific HTTP transport type.
abstract class HTTPTransportType {
  String get name;
  int get value;

  String toJSON();

  /// Specifies no transport preference.
  static const HTTPTransportType none = _HTTPTransportType('None', 0);

  /// Specifies the WebSockets transport.
  static const HTTPTransportType webSockets =
      _HTTPTransportType('WebSockets', 1);

  /// Specifies the Server-Sent Events transport.
  static const HTTPTransportType serverSentEvents =
      _HTTPTransportType('ServerSentEvents', 2);

  /// Specifies the Long Polling transport.
  static const HTTPTransportType longPolling =
      _HTTPTransportType('LongPolling', 4);

  factory HTTPTransportType.fromJSON(String name) {
    switch (name) {
      case 'None':
        return none;
      case 'WebSockets':
        return webSockets;
      case 'ServerSentEvents':
        return serverSentEvents;
      case 'LongPolling':
        return longPolling;
      default:
        throw ArgumentError.value(name);
    }
  }
}

class _HTTPTransportType implements HTTPTransportType {
  @override
  final String name;
  @override
  final int value;

  const _HTTPTransportType(this.name, this.value);

  @override
  String toJSON() {
    return name;
  }

  @override
  String toString() {
    return name;
  }
}

/// Specifies the transfer format for a connection.
abstract class TransferFormat {
  String get name;
  int get value;

  /// Specifies that only text data will be transmitted over the connection.
  static const TransferFormat text = _TransferFormat('Text', 1);

  /// Specifies that binary data will be transmitted over the connection.
  static const TransferFormat binary = _TransferFormat('Binary', 2);

  String toJSON();

  factory TransferFormat.fromJSON(String name) {
    switch (name) {
      case 'Text':
        return text;
      case 'Binary':
        return binary;
      default:
        throw ArgumentError.value(name);
    }
  }
}

class _TransferFormat implements TransferFormat {
  @override
  final String name;
  @override
  final int value;

  const _TransferFormat(this.name, this.value);

  @override
  String toJSON() {
    return name;
  }

  @override
  String toString() {
    return name;
  }
}
