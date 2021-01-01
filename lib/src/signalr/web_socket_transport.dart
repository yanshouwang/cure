import 'dart:async';

import 'package:cure/ws.dart';

import 'http_client.dart';
import 'logger.dart';
import 'transport.dart';
import 'utils.dart';

class WebSocketTransport implements Transport {
  final Logger _logger;
  final Future<String> Function() _accessTokenFactory;
  final bool _logMessageContent;
  final WebSocket Function(String url,
      {List<String> protocols,
      Map<String, String> headers}) _webSocketConstructor;
  final HTTPClient _httpClient;
  final Map<String, String> _headers;

  WebSocket _webSocket;

  @override
  void Function(Exception error) onclose;
  @override
  void Function(dynamic error) onreceive;

  WebSocketTransport(this._httpClient, this._accessTokenFactory, this._logger,
      this._logMessageContent, this._webSocketConstructor, this._headers)
      : onreceive = null,
        onclose = null;

  @override
  Future<void> connectAsync(String url, TransferFormat transferFormat) async {
    Arg.isRequired(url, 'url');
    Arg.isRequired(transferFormat, 'transferFormat');

    _logger.log(LogLevel.trace, '(WebSockets transport) Connecting.');

    if (_accessTokenFactory != null) {
      final token = await _accessTokenFactory();
      if (token != null) {
        url += (url.contains('?') ? '&' : '?') +
            'access_token=${Uri.encodeComponent(token)}';
      }
    }

    final completer = Completer<void>();
    final from = RegExp(r'^http');
    url = url.replaceFirst(from, 'ws');
    WebSocket ws;
    var opened = false;
    if (Platform.isVM) {
      final headers = <String, String>{};
      final userAgent = getUserAgentHeader();
      headers[userAgent.key] = userAgent.value;

      final cookies = _httpClient.getCookieString(url);
      if (cookies != null && cookies.isNotEmpty) {
        headers['Cookie'] = cookies;
      }

      if (_headers != null) {
        for (var header in _headers.entries) {
          headers[header.key] = header.value;
        }
      }

      // Only pass headers when in non-browser environments
      ws = _webSocketConstructor(url, headers: headers);
    }
    // Chrome is not happy with passing 'undefined' as protocol
    ws ??= _webSocketConstructor(url);
    if (transferFormat == TransferFormat.binary) {
      ws.binaryType = 'arraybuffer';
    }
    final fail = (Exception error) {
      if (completer.isCompleted) {
        return;
      }
      completer.completeError(error);
    };
    ws.onopen = () {
      _logger.log(LogLevel.information, 'WebSocket connected to $url.');
      _webSocket = ws;
      opened = true;
      completer.complete();
    };
    ws.onerror = (error) => fail(error);
    ws.ondata = (data) {
      _logger.log(LogLevel.trace,
          '(WebSockets transport) data received. ${getDataDetail(data, _logMessageContent)}.');
      try {
        onreceive?.call(data);
      } catch (error) {
        close(error);
      }
    };
    ws.onclose = (code, reason) {
      if (opened) {
        if (code != 1000) {
          final error =
              Exception('WebSocket closed with status code: $code ($reason).');
          close(error);
        } else {
          close();
        }
      } else {
        if (completer.isCompleted) {
          return;
        }
        final error = Exception('There was an error with the transport.');
        fail(error);
      }
    };

    await completer.future;
  }

  @override
  Future<void> sendAsync(data) {
    if (_webSocket != null && _webSocket.readyState == WebSocket.OPEN) {
      _logger.log(LogLevel.trace,
          '(WebSockets transport) sending data. ${getDataDetail(data, _logMessageContent)}.');
      _webSocket.send(data);
      return Future.value();
    }

    final error = Exception('WebSocket is not in the OPEN state');
    return Future.error(error);
  }

  @override
  Future<void> stopAsync() {
    if (_webSocket != null) {
      // Manually invoke onclose callback inline so we know the HTTPConnection was closed properly before returning
      // This also solves an issue where websocket.onclose could take 18+ seconds to trigger during network disconnects
      close();
    }

    return Future.value();
  }

  void close([dynamic error]) {
    // webSocket will be null if the transport did not start successfully
    if (_webSocket != null) {
      // Clear websocket handlers because we are considering the socket closed now
      _webSocket.onclose = (code, reason) => {};
      _webSocket.ondata = (data) => {};
      _webSocket.onerror = (error) => {};
      _webSocket.close();
      _webSocket = null;
    }

    _logger.log(LogLevel.trace, '(WebSockets transport) socket closed.');
    if (onclose != null) {
      if (error is Exception) {
        onclose(error);
      } else {
        onclose(null);
      }
    }
  }
}
