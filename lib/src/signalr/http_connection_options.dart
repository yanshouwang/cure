import 'http_client.dart';
import 'polyfills.dart';

class HttpConnectionOptions {
  Map<String, String>? headers;
  HttpClient? httpClient;
  Object? transport;
  Object? logger;
  String Function()? accessTokenBuilder;
  bool? logMessageContent;
  bool? skipNegotiation;
  WebSocketConstructor? webSocket;
  EventSourceConstructor? eventSource;
  bool? withCredentials;

  HttpConnectionOptions(
      {this.headers,
      this.httpClient,
      this.transport,
      this.logger,
      this.accessTokenBuilder,
      this.logMessageContent,
      this.skipNegotiation,
      this.webSocket,
      this.eventSource,
      this.withCredentials});
}
