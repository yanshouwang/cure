import 'exceptions.dart';
import 'http_client_stub.dart'
    if (dart.library.html) 'http_client_chromium.dart'
    if (dart.library.io) 'http_client_dartium.dart';
import 'http_client.dart';
import 'logger.dart';

/// Default implementation of [HttpClient].
class DefaultHttpClient extends HttpClient {
  final HttpClient _httpClient;

  /// Creates a new instance of the [HttpClient], using the provided [logger] to log messages.
  DefaultHttpClient(Logger logger) : _httpClient = createClient(logger);

  @override
  Future<HttpResponse> sendAsync(HttpRequest request) {
    if (request.abortSignal != null && request.abortSignal.aborted) {
      final error = AbortException();
      return Future.error(error);
    }
    if (request.method.isEmpty) {
      final error = Exception('No method defined.');
      return Future.error(error);
    }
    if (request.url.isEmpty) {
      final error = Exception('No url defined.');
      return Future.error(error);
    }
    return _httpClient.sendAsync(request);
  }

  @override
  String getCookieString(String url) {
    return _httpClient.getCookieString(url);
  }
}
