import 'web_socket_stub.dart'
    if (dart.library.html) 'web_socket_chromium.dart'
    if (dart.library.io) 'web_socket_dartium.dart';

/// WebSocket
abstract class WebSocket {
  /// CONNECTING = 0
  static const int CONNECTING = 0;

  /// OPEN = 1
  static const int OPEN = 1;

  /// CLOSING = 2
  static const int CLOSING = 2;

  /// CLOSED = 3
  static const int CLOSED = 3;

  /// url
  String get url;

  /// binaryType
  String? get binaryType;

  /// value
  set binaryType(String? value);

  /// extensions
  String? get extensions;

  /// protocol
  String? get protocol;

  /// readyState
  int get readyState;

  /// onopen
  void Function()? onopen;

  /// onerror
  void Function(Object? error)? onerror;

  /// ondata
  void Function(Object? data)? ondata;

  /// onclose
  void Function(int? code, String? reason)? onclose;

  /// Send [data] to the remote.
  void send(Object data);

  /// Close the WebSocket with [code] and [reason].
  void close([int? code, String? reason]);

  /// Connect to the [url].
  factory WebSocket.connect(String url,
          {List<String>? protocols, Map<String, String>? headers}) =>
      connectWebSocket(url, protocols: protocols, headers: headers);
}
