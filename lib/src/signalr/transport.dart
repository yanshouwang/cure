/// An abstraction over the behavior of transports. This is designed to support the framework and not intended for use by applications.
abstract class Transport {
  void Function(Object data)? onreceive;
  void Function(Object? error)? onclose;

  Future<void> connectAsync(String url, TransferFormat transferFormat);
  Future<void> sendAsync(Object data);
  Future<void> stopAsync();
}

/// Specifies a specific HTTP transport type.
class HttpTransportType {
  final String name;
  final int value;

  /// Specifies no transport preference.
  static const HttpTransportType none = HttpTransportType('None', 0);

  /// Specifies the WebSockets transport.
  static const HttpTransportType webSockets =
      HttpTransportType('WebSockets', 1);

  /// Specifies the Server-Sent Events transport.
  static const HttpTransportType serverSentEvents =
      HttpTransportType('ServerSentEvents', 2);

  /// Specifies the Long Polling transport.
  static const HttpTransportType longPolling =
      HttpTransportType('LongPolling', 4);

  const HttpTransportType(this.name, this.value);

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

  String toJSON() {
    return name;
  }

  @override
  String toString() {
    return name;
  }
}

/// Specifies the transfer format for a connection.
class TransferFormat {
  final String name;
  final int value;

  /// Specifies that only text data will be transmitted over the connection.
  static const TransferFormat text = TransferFormat('Text', 1);

  /// Specifies that binary data will be transmitted over the connection.
  static const TransferFormat binary = TransferFormat('Binary', 2);

  const TransferFormat(this.name, this.value);

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

  String toJSON() {
    return name;
  }

  @override
  String toString() {
    return name;
  }
}
