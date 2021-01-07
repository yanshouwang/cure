import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'event_source.dart';

EventSource connectEventSource(String url,
        {Map<String, String> headers, bool withCredentials}) =>
    _EventSource.connect(url, headers: headers);

class _EventSource implements EventSource {
  HttpClient _client;
  String _event;
  String _data;
  String _id;
  int _retry;
  Timer _timer;
  int _readyState;

  @override
  final String url;
  @override
  int get readyState => _readyState;
  @override
  void Function() onopen;
  @override
  void Function(Exception data) onerror;
  @override
  void Function(String event, String data) ondata;

  _EventSource._(this.url, {Map<String, String> headers})
      : _readyState = EventSource.CLOSED {
    _connect(headers: headers);
  }

  void _connect({Map<String, String> headers}) async {
    if (readyState != EventSource.CLOSED) {
      return;
    }
    _readyState = EventSource.CONNECTING;
    final uri = Uri.parse(url);
    _client = HttpClient();
    final request = await _client.getUrl(uri);
    if (headers != null) {
      for (var header in headers.entries) {
        request.headers.set(header.key, header.value);
      }
    }
    request.headers.set('Accept', 'text/event-stream');
    if (_id != null) {
      request.headers.set('Last-Event-ID', _id);
    }
    final response = await request.close();
    if (response.statusCode == HttpStatus.ok) {
      _readyState = EventSource.OPEN;
      onopen?.call();
      final decoder = utf8.decoder;
      final splitter = LineSplitter();
      response
          .transform(decoder)
          .transform(splitter)
          .listen(_onData, onError: _onError, onDone: _reconnect);
    } else {
      _onError(response.reasonPhrase);
      _reconnect();
    }
  }

  void _onData(String data) {
    if (data.isEmpty) {
      if (_event == null && _data == null) {
        return;
      }
      _event ??= 'message';
      ondata?.call(_event, _data);
      _event = null;
      _data = null;
    } else if (data.startsWith(':')) {
      // This is a comment
      return;
    } else {
      final i = data.indexOf(':');
      if (i == -1) {
        // Wrong data format
        return;
      }
      final field = data.substring(0, i);
      final value = data.substring(i + 1).trimLeft();
      switch (field) {
        case 'event':
          _event = value;
          break;
        case 'data':
          _data = _data == null ? value : '$_data\n$value';
          break;
        case 'id':
          _id = value;
          break;
        case 'retry':
          _retry = int.parse(value);
          break;
        default:
          // Wrong field name
          break;
      }
    }
  }

  void _onError(Object error) {
    error = error is Exception ? error : Exception('EventSource error: $error');
    onerror?.call(error);
  }

  void _reconnect() {
    if (readyState == EventSource.CLOSED) {
      return;
    }
    close();
    final duration = Duration(milliseconds: _retry ?? 1000);
    _timer = Timer(duration, () {
      _timer = null;
      _connect();
    });
  }

  factory _EventSource.connect(String url, {Map<String, String> headers}) {
    return _EventSource._(url, headers: headers);
  }

  @override
  void close() {
    if (readyState == EventSource.CLOSED) {
      return;
    }
    if (_timer != null) {
      _timer.cancel();
      _timer == null;
    }
    if (_client != null) {
      _client.close(force: true);
      _client = null;
    }
    _readyState = EventSource.CLOSED;
  }
}
