import 'exceptions.dart';
import 'http_client_stub.dart'
    if (dart.library.html) 'http_client_html.dart'
    if (dart.library.io) 'http_client_io.dart';
import 'http_client.dart';
import 'logger.dart';

/// Default implementation of [HTTPClient].
class DefaultHTTPClient extends HTTPClient {
  final HTTPClient _httpClient;

  /// Creates a new instance of the [HTTPClient], using the provided [logger] to log messages.
  DefaultHTTPClient(Logger logger) : _httpClient = createClient(logger);

  @override
  Future<HTTPResponse> sendAsync(HTTPRequest request) {
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
