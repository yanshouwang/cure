import 'dart:async';
import 'dart:convert';
import 'dart:io' as dartium;

import 'package:cure/core.dart';

import 'errors.dart';
import 'http_client.dart';
import 'logger.dart';

HttpClient createClient(Logger logger) => _HttpClient(logger);

class _HttpClient extends HttpClient {
  final Logger _logger;

  _HttpClient(this._logger);

  @override
  Future<HttpResponse> sendAsync(HttpRequest request) async {
    // Check that abort was not signaled before calling send
    if (request.abortSignal != null && request.abortSignal!.aborted) {
      throw AbortException();
    }
    if (request.method == null) {
      throw Exception('No method defined.');
    }
    if (request.url == null) {
      throw Exception('No url defined.');
    }
    final client = dartium.HttpClient();
    Timer? timer;
    try {
      final url = Uri.parse(request.url!);
      final hcr = await client.openUrl(request.method!, url);
      if (request.abortSignal != null) {
        request.abortSignal!.onabort = () {
          final error = AbortException();
          hcr.abort(error);
        };
      }
      if (request.timeout != null) {
        final duration = Duration(milliseconds: request.timeout!);
        timer = Timer(duration, () {
          _logger.log(LogLevel.warning, 'Timeout from HTTP request');
          final error = TimeoutException();
          hcr.abort(error);
        });
      }
      hcr.headers.set('X-Requested-With', 'XMLHttpRequest');
      // Explicitly setting the Content-Type header for React Native on Android platform.
      hcr.headers.set('Content-Type', 'text/plain;charset=UTF-8');
      for (var entry in request.headers!.entries) {
        hcr.headers.set(entry.key, entry.value);
      }
      hcr.write(request.content);
      final response = await hcr.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final content =
            await _deserializeContentAsync(response, request.responseType);
        return HttpResponse(
            response.statusCode, response.reasonPhrase, content);
      } else {
        throw HttpException(response.reasonPhrase, response.statusCode);
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
        request.abortSignal!.onabort = null;
      }
      client.close();
    }
  }

  Future<Object> _deserializeContentAsync(
      dartium.HttpClientResponse response, String? responseType) async {
    Object content;
    switch (responseType) {
      case 'arraybuffer':
        content = await response.extractAsync();
        break;
      case 'blob':
      case 'document':
      case 'json':
        throw Exception('$responseType is not supported.');
      case 'text':
      default:
        final charset = response.headers.contentType?.charset;
        final encoding = charset == null ? utf8 : Encoding.getByName(charset)!;
        content = await encoding.decodeStream(response);
        break;
    }
    return content;
  }
}
