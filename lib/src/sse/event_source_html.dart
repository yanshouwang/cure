import 'dart:html' as html;

import 'event_source.dart';

EventSource connectEventSource(String url,
        {Map<String, String> headers, bool withCredentials}) =>
    _EventSource.connect(url, withCrendentials: withCredentials);

class _EventSource implements EventSource {
  final html.EventSource _inner;

  @override
  String get url => _inner.url;
  @override
  int get readyState => _inner.readyState;
  @override
  void Function() onopen;
  @override
  void Function(Exception error) onerror;
  @override
  void Function(String event, String data) ondata;

  _EventSource._(this._inner) {
    _listen();
  }

  void _listen() {
    _inner.onOpen.first.then((_) => onopen?.call());
    _inner.onError.first.then((event) {
      final error = event is html.ErrorEvent
          ? event.error
          : Exception('EventSource error event: $event');
      onerror?.call(error);
    });
    _inner.onMessage.listen((event) => ondata?.call(event.type, event.data));
  }

  @override
  void close() {
    _inner.close();
  }

  factory _EventSource.connect(String url, {bool withCrendentials}) {
    final inner = html.EventSource(url, withCredentials: withCrendentials);
    return _EventSource._(inner);
  }
}
