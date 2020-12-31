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

  int toJSON();

  factory HTTPTransportType.fromJSON(int obj) {
    switch (obj) {
      case 0:
        return none;
      case 1:
        return webSockets;
      case 2:
        return serverSentEvents;
      case 4:
        return longPolling;
      default:
        throw ArgumentError.value(obj);
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
  int toJSON() {
    return value;
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

  int toJSON();

  factory TransferFormat.fromJSON(int obj) {
    switch (obj) {
      case 1:
        return text;
      case 2:
        return binary;
      default:
        throw ArgumentError.value(obj);
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
  int toJSON() {
    return value;
  }

  @override
  String toString() {
    return name;
  }
}
