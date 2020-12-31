import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cure/utils.dart';

import 'exceptions.dart';
import 'http_client.dart';
import 'logger.dart';

HTTPClient createClient(Logger logger) => _HTTPClient(logger);

class _HTTPClient extends HTTPClient {
  final Logger _logger;

  _HTTPClient(this._logger);

  @override
  Future<HTTPResponse> sendAsync(HTTPRequest request) async {
    // Check that abort was not signaled before calling send
    if (request.abortSignal != null && request.abortSignal.aborted) {
      throw AbortException();
    }
    if (request.method == null) {
      throw Exception('No method defined.');
    }
    if (request.url == null) {
      throw Exception('No url defined.');
    }
    final client = HttpClient();
    Timer timer;
    try {
      final url = Uri.parse(request.url);
      final hcr = await client.openUrl(request.method, url)
        ..followRedirects = false;
      if (request.abortSignal != null) {
        request.abortSignal.onabort = () {
          final error = AbortException();
          hcr.abort(error);
        };
      }
      if (request.timeout != null) {
        final duration = Duration(milliseconds: request.timeout);
        timer = Timer(duration, () {
          _logger.log(LogLevel.warning, 'Timeout from HTTP request');
          final error = TimeoutException();
          hcr.abort(error);
        });
      }
      hcr.headers.set('X-Requested-With', 'XMLHttpRequest');
      // Explicitly setting the Content-Type header for React Native on Android platform.
      hcr.headers.set('Content-Type', 'text/plain;charset=UTF-8');
      for (var entry in request.headers.entries) {
        hcr.headers.set(entry.key, entry.value);
      }
      hcr.write(request.content);
      final response = await hcr.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final content =
            await _deserializeContentAsync(response, request.responseType);
        return HTTPResponse(
            response.statusCode, response.reasonPhrase, content);
      } else {
        throw HTTPException(response.reasonPhrase, response.statusCode);
      }
    } catch (e) {
      _logger.log(LogLevel.warning, 'Error from HTTP request. $e.');
      rethrow;
    } finally {
      if (timer != null) {
        timer.cancel();
        timer = null;
      }
      if (request.abortSignal != null) {
        request.abortSignal.onabort = null;
      }
      client.close();
    }
  }

  Future<dynamic> _deserializeContentAsync(
      HttpClientResponse response, String responseType) {
    dynamic content;
    switch (responseType) {
      case 'arraybuffer':
        content = response.extractAsync();
        break;
      case 'blob':
      case 'document':
      case 'json':
        throw Exception('$responseType is not supported.');
        break;
      case 'text':
      default:
        final charset = response.headers.contentType?.charset;
        final encoding = charset == null ? utf8 : Encoding.getByName(charset);
        content = encoding.decodeStream(response);
        break;
    }
    return content;
  }
}
