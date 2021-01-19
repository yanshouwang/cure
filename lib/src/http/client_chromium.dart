import 'dart:async';
import 'dart:html';

import 'package:pedantic/pedantic.dart';

import 'base_client.dart';
import 'client.dart';
import 'errors.dart';
import 'request.dart';
import 'response.dart';

Client createClient() => _Client();

class _Client extends BaseClient {
  final _xhrs = <HttpRequest>{};

  bool _closed;

  _Client() : _closed = false;

  @override
  Future<Response> sendAsync(Request request) async {
    if (_closed) {
      throw ClientException(
          "Can't send request when Client is closed", request.url);
    }

    final xhr = HttpRequest();
    _xhrs.add(xhr);
    xhr.open(request.method, '${request.url}', async: true);
    for (var entry in request.headers.entries) {
      xhr.setRequestHeader(entry.key, entry.value);
    }

    final completer = Completer<Response>();

    unawaited(xhr.onLoad.first.then((_) {
      final response = Response(
          xhr.status!, xhr.statusText, xhr.response, xhr.responseHeaders);
      completer.complete(response);
    }));

    unawaited(xhr.onError.first.then((_) {
      final error = ClientException('XMLHttpRequest error.', request.url);
      completer.completeError(error, StackTrace.current);
    }));

    final data = request.encode();
    xhr.send(data);

    try {
      return await completer.future;
    } finally {
      _xhrs.remove(xhr);
    }
  }

  @override
  void close([bool force = false]) {
    if (force) {
      for (var xhr in _xhrs) {
        xhr.abort();
      }
    }
    _closed = true;
  }
}
