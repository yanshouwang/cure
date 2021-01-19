import 'dart:async';

import 'package:cure/sse.dart';

import 'http_client.dart';
import 'logger.dart';
import 'polyfills.dart';
import 'transport.dart';
import 'utils.dart';

class ServerSentEventsTransport implements Transport {
  final HttpClient _httpClient;
  final String Function()? _accessTokenBuilder;
  final Logger _logger;
  final bool _logMessageContent;
  final EventSourceConstructor _eventSourceConstructor;
  final bool _withCredentials;
  final Map<String, String> _headers;
  EventSource? _eventSource;
  String? url;

  @override
  void Function(Object data)? onreceive;
  @override
  void Function(Object? error)? onclose;

  ServerSentEventsTransport(
      this._httpClient,
      this._accessTokenBuilder,
      this._logger,
      this._logMessageContent,
      this._eventSourceConstructor,
      this._withCredentials,
      this._headers);

  @override
  Future<void> connectAsync(String url, TransferFormat transferFormat) async {
    _logger.log(LogLevel.trace, '(SSE transport) Connecting.');
    // set url before accessTokenFactory because this.url is only for send and we set the auth header instead of the query string for send
    this.url = url;
    final token = _accessTokenBuilder?.call();
    if (token != null) {
      url += (url.contains('?') ? '&' : '?') +
          'access_token=${Uri.encodeComponent(token)}';
    }
    final completer = Completer<void>();
    var opened = false;
    if (transferFormat != TransferFormat.text) {
      final error = Exception(
          "The Server-Sent Events transport only supports the 'Text' transfer format");
      completer.completeError(error);
      return completer.future;
    }

    EventSource eventSource;
    if (Platform.isChromium) {
      eventSource = _eventSourceConstructor(url, null, null);
    } else {
      final headers = <String, String>{};
      final cookies = _httpClient.getCookieString(url);
      if (cookies.isNotEmpty) {
        headers['Cookie'] = cookies;
      }
      final userAgent = getUserAgentHeader();
      headers[userAgent.key] = userAgent.value;
      for (var header in _headers.entries) {
        headers[header.key] = header.value;
      }
      eventSource = _eventSourceConstructor(url, headers, _withCredentials);
    }

    try {
      eventSource.ondata = (event, data) {
        if (onreceive != null) {
          try {
            _logger.log(LogLevel.trace,
                '(SSE transport) data received. ${getDataDetail(data, _logMessageContent)}.');
            onreceive!.call(data!);
          } catch (error) {
            _close(error);
          }
        }
      };
      eventSource.onerror = (error) {
        error ??= Exception('Error occurred');
        if (opened) {
          _close(error as Exception?);
        } else {
          completer.completeError(error);
        }
      };
      eventSource.onopen = () {
        _logger.log(LogLevel.information, 'SSE connected to ${this.url}');
        _eventSource = eventSource;
        opened = true;
        completer.complete();
      };
    } catch (e) {
      completer.completeError(e);
    } finally {
      return completer.future;
    }
  }

  @override
  Future<void> sendAsync(Object data) {
    if (_eventSource == null) {
      final error = Exception('Cannot send until the transport is connected');
      return Future.error(error);
    }
    return sendMessageAsync(
        _logger,
        'SSE',
        _httpClient,
        url!,
        _accessTokenBuilder,
        data,
        _logMessageContent,
        _withCredentials,
        _headers);
  }

  @override
  Future<void> stopAsync() {
    _close();
    return Future.value();
  }

  void _close([Object? error]) {
    if (_eventSource != null) {
      _eventSource!.close();
      _eventSource = null;
      onclose?.call(error);
    }
  }
}
