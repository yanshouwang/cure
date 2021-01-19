import 'web_socket.dart';

WebSocket connectWebSocket(String url,
        {List<String>? protocols, Map<String, String>? headers}) =>
    throw UnsupportedError(
        "Can't create a WebSocket without dart:html or dart:io.");
