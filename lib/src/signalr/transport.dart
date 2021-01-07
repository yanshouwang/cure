/// An abstraction over the behavior of transports. This is designed to support the framework and not intended for use by applications.
abstract class Transport {
  void Function(Object data) onreceive;
  void Function(Exception error) onclose;

  Future<void> connectAsync(String url, TransferFormat transferFormat);
  Future<void> sendAsync(Object data);
  Future<void> stopAsync();
}

/// Specifies a specific HTTP transport type.
abstract class HttpTransportType {
  String get name;
  int get value;

  String toJSON();

  /// Specifies no transport preference.
  static const HttpTransportType none = _HttpTransportType('None', 0);

  /// Specifies the WebSockets transport.
  static const HttpTransportType webSockets =
      _HttpTransportType('WebSockets', 1);

  /// Specifies the Server-Sent Events transport.
  static const HttpTransportType serverSentEvents =
      _HttpTransportType('ServerSentEvents', 2);

  /// Specifies the Long Polling transport.
  static const HttpTransportType longPolling =
      _HttpTransportType('LongPolling', 4);

  factory HttpTransportType.fromJSON(String name) {
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

class _HttpTransportType implements HttpTransportType {
  @override
  final String name;
  @override
  final int value;

  const _HttpTransportType(this.name, this.value);

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
