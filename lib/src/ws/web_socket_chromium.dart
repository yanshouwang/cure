import 'dart:html' as chromium;
import 'dart:typed_data';

import 'web_socket.dart';

WebSocket connectWebSocket(String url,
        {List<String>? protocols, Map<String, String>? headers}) =>
    _WebSocket.connect(url, protocols);

class _WebSocket implements WebSocket {
  final chromium.WebSocket _inner;

  @override
  String get url => _inner.url!;
  @override
  String? get binaryType => _inner.binaryType;
  @override
  set binaryType(String? value) => _inner.binaryType = value;
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

  _WebSocket._(this._inner) {
    _listen();
  }

  void _listen() {
    // The socket API guarantees that only a single open event will be
    // emitted.
    _inner.onOpen.first.then((_) {
      onopen?.call();
    });
    // The socket API guarantees that only a single error event will be emitted,
    // and that once it is no open or message events will be emitted.
    _inner.onError.first.then((event) {
      final error = event is chromium.ErrorEvent
          ? event.error
          : Exception('WebSocket error event: $event');
      onerror?.call(error);
    });
    _inner.onMessage.listen((event) {
      var data = event.data;
      if (data is ByteBuffer) {
        data = data.asUint8List();
      }
      ondata?.call(data);
    });
    _inner.onClose.first
        .then((event) => onclose?.call(event.code, event.reason));
  }

  factory _WebSocket.connect(String url, [List<String>? protocols]) {
    final inner = chromium.WebSocket(url, protocols);
    return _WebSocket._(inner);
  }

  @override
  void send(data) {
    if (data is List<int>) {
      data = Uint8List.fromList(data).buffer;
    }
    _inner.send(data);
  }

  @override
  void close([int? code, String? reason]) {
    if (code == null) {
      _inner.close();
    } else {
      _inner.close(code, reason);
    }
  }
}
