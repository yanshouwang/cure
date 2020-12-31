import 'package:cure/sse.dart';
import 'package:cure/ws.dart';

import 'http_client.dart';

abstract class HTTPConnectionOptions {
  Map<String, String> headers;
  HTTPClient httpClient;
  dynamic transport;
  dynamic logger;
  Future<String> Function() accessTokenFactory;
  bool logMessageContent;
  bool skipNegotiation;
  WebSocket Function(String url,
      {List<String> protocols, Map<String, String> headers}) webSocket;
  EventSource Function(String url,
      {Map<String, String> headers, bool withCredentials}) eventSource;
  bool withCredentials;

  factory HTTPConnectionOptions(
          {Map<String, String> headers,
          HTTPClient httpClient,
          dynamic transport,
          dynamic logger,
          Future<String> Function() accessTokenFactory,
          bool logMessageContent,
          bool skipNegotiation,
          WebSocket Function(String url,
                  {List<String> protocols, Map<String, String> headers})
              webSocket,
          EventSource Function(String url,
                  {Map<String, String> headers, bool withCredentials})
              eventSource,
          bool withCredentials}) =>
      _HTTPConnectionOptions(
          headers,
          httpClient,
          transport,
          logger,
          accessTokenFactory,
          logMessageContent,
          skipNegotiation,
          webSocket,
          eventSource,
          withCredentials);
}

class _HTTPConnectionOptions implements HTTPConnectionOptions {
  @override
  Map<String, String> headers;
  @override
  HTTPClient httpClient;
  @override
  dynamic transport;
  @override
  dynamic logger;
  @override
  Future<String> Function() accessTokenFactory;
  @override
  bool logMessageContent;
  @override
  bool skipNegotiation;
  @override
  WebSocket Function(String url,
      {List<String> protocols, Map<String, String> headers}) webSocket;
  @override
  EventSource Function(String url,
      {Map<String, String> headers, bool withCredentials}) eventSource;
  @override
  bool withCredentials;

  _HTTPConnectionOptions(
      this.headers,
      this.httpClient,
      this.transport,
      this.logger,
      this.accessTokenFactory,
      this.logMessageContent,
      this.skipNegotiation,
      this.webSocket,
      this.eventSource,
      this.withCredentials);
}
