import 'dart:async';
import 'dart:html' as chromium;

import 'errors.dart';
import 'http_client.dart';
import 'logger.dart';

HttpClient createClient(Logger logger) => _HttpClient(logger);

class _HttpClient extends HttpClient {
  final Logger _logger;

  _HttpClient(this._logger);

  @override
  Future<HttpResponse> sendAsync(HttpRequest request) {
    if (request.abortSignal != null && request.abortSignal!.aborted) {
      final error = AbortException();
      return Future.error(error);
    }
    if (request.method == null) {
      final error = Exception('No method defined.');
      return Future.error(error);
    }
    if (request.url == null) {
      final error = Exception('No url defined.');
      return Future.error(error);
    }

    final completer = Completer<HttpResponse>();

    final xhr = chromium.HttpRequest();

    xhr.open(request.method!, request.url!, async: true);
    xhr.withCredentials = request.withCredentials ?? true;
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
    // Explicitly setting the Content-Type header for React Native on Android platform.
    xhr.setRequestHeader('Content-Type', 'text/plain;charset=UTF-8');

    final headers = request.headers;
    if (headers != null) {
      for (var entry in headers.entries) {
        xhr.setRequestHeader(entry.key, entry.value);
      }
    }

    if (request.responseType != null) {
      xhr.responseType = request.responseType!;
    }

    if (request.abortSignal != null) {
      request.abortSignal!.onabort = () {
        xhr.abort();
        final error = AbortException();
        completer.completeError(error);
      };
    }

    if (request.timeout != null) {
      xhr.timeout = request.timeout;
    }

    xhr.onLoad.first.then((_) {
      if (request.abortSignal != null) {
        request.abortSignal!.onabort = null;
      }

      if (xhr.status! >= 200 && xhr.status! < 300) {
        final response = HttpResponse(
            xhr.status!, xhr.statusText, xhr.response ?? xhr.responseText);
        completer.complete(response);
      } else {
        final error = HttpException(xhr.statusText!, xhr.status!);
        completer.completeError(error);
      }
    });

    xhr.onError.first.then((_) {
      _logger.log(LogLevel.warning,
          'Error from HTTP request. ${xhr.status}: ${xhr.statusText}.');
      final error = HttpException(xhr.statusText!, xhr.status!);
      completer.completeError(error);
    });

    xhr.onTimeout.first.then((_) {
      _logger.log(LogLevel.warning, 'Timeout from HTTP request.');
      final error = TimeoutException();
      completer.completeError(error);
    });

    xhr.send(request.content ?? '');

    return completer.future;
  }
}
