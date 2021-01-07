import 'package:cure/sse.dart';
import 'package:cure/ws.dart';

import 'http_client.dart';

abstract class HttpConnectionOptions {
  Map<String, String> headers;
  HttpClient httpClient;
  dynamic transport;
  Object logger;
  Future<String> Function() accessTokenFactory;
  bool logMessageContent;
  bool skipNegotiation;
  WebSocket Function(String url,
      {List<String> protocols, Map<String, String> headers}) webSocket;
  EventSource Function(String url,
      {Map<String, String> headers, bool withCredentials}) eventSource;
  bool withCredentials;

  factory HttpConnectionOptions(
          {Map<String, String> headers,
          HttpClient httpClient,
          dynamic transport,
          Object logger,
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
      _HttpConnectionOptions(
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

class _HttpConnectionOptions implements HttpConnectionOptions {
  @override
  Map<String, String> headers;
  @override
  HttpClient httpClient;
  @override
  dynamic transport;
  @override
  Object logger;
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

  _HttpConnectionOptions(
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
