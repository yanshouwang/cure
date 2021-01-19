import 'dart:async';

import 'package:cure/ws.dart';

class TestWebSocket implements WebSocket {
  @override
  String? binaryType;
  int bufferedAmount;
  @override
  String extensions;
  @override
  void Function(Object? error)? onerror;
  @override
  void Function(Object? data)? ondata;
  @override
  String protocol;
  @override
  int readyState;
  @override
  String url;
  Map<String, String>? headers;
  bool closed;

  static Completer<void>? wsSet;
  static late TestWebSocket ws;
  List<Object> receivedData;

  void Function()? _onopen;
  var openSet = Completer<void>();
  @override
  void Function() get onopen {
    return () {
      _onopen!.call();
      readyState = WebSocket.OPEN;
    };
  }

  @override
  set onopen(void Function()? value) {
    _onopen = value;
    // Call complete twice will throw an error.
    if (!openSet.isCompleted) {
      openSet.complete();
    }
  }

  void Function(int? code, String? reason)? _onclose;
  var closeSet = Completer<void>();
  @override
  void Function(int? code, String? reason) get onclose {
    return (code, reason) {
      _onclose!.call(code, reason);
      readyState = WebSocket.CLOSED;
    };
  }

  @override
  set onclose(void Function(int? code, String? reason)? value) {
    _onclose = value;
    if (!closeSet.isCompleted) {
      closeSet.complete();
    }
  }

  @override
  void close([int? code, String? reason]) {
    closed = true;
    code ??= 1000;
    readyState = WebSocket.CLOSED;
    onclose(code, reason);
  }

  @override
  void send(Object data) {
    if (closed) {
      throw Exception("cannot send from a closed transport: '$data'");
    }
    receivedData.add(data);
  }

  TestWebSocket(this.url, {List<String>? protocols, this.headers})
      : binaryType = 'blob',
        bufferedAmount = 0,
        extensions = '',
        readyState = WebSocket.CLOSED,
        closed = false,
        protocol = protocols?.first ?? '',
        receivedData = [] {
    TestWebSocket.ws = this;
    TestWebSocket.wsSet?.complete();
  }
}
