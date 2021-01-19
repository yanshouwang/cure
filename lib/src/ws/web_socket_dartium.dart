import 'dart:io' as dartium;

import 'web_socket.dart';

WebSocket connectWebSocket(String url,
        {List<String>? protocols, Map<String, String>? headers}) =>
    _WebSocket.connect(url, protocols: protocols, headers: headers);

class _WebSocket implements WebSocket {
  late dartium.WebSocket _inner;

  @override
  final String url;
  @override
  String? binaryType;
  @override
  String? get extensions => _inner.extensions;
  @override
  String? get protocol => _inner.protocol;
  @override
  int get readyState => _inner.readyState;
  @override
  void Function()? onopen;
  @override
  void Function(Object? error)? onerror;
  @override
  void Function(Object? data)? ondata;
  @override
  void Function(int? code, String? reason)? onclose;

  _WebSocket._(this.url,
      {List<String>? protocols, Map<String, String>? headers}) {
    _connect(protocols: protocols, headers: headers);
  }

  void _connect({List<String>? protocols, Map<String, String>? headers}) async {
    try {
      _inner = await dartium.WebSocket.connect(url,
          protocols: protocols, headers: headers);
      onopen?.call();
      _listen();
    } catch (e) {
      final error =
          e is Exception ? e : Exception('WebSocket connect error: $e');
      onerror?.call(error);
    }
  }

  void _listen() {
    _inner.listen((data) => ondata?.call(data),
        onError: (e) {
          final error =
              e is Exception ? e : Exception('WebSocket connect error: $e');
          onerror?.call(error);
        },
        onDone: () => onclose?.call(_inner.closeCode, _inner.closeReason));
  }

  factory _WebSocket.connect(String url,
      {List<String>? protocols, Map<String, String>? headers}) {
    return _WebSocket._(url, protocols: protocols, headers: headers);
  }

  @override
  void send(Object data) {
    _inner.add(data);
  }

  @override
  void close([int? code, String? reason]) async {
    await _inner.close(code, reason);
  }
}
