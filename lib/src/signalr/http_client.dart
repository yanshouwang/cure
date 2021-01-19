import 'abort_signal.dart';
import 'errors.dart';
import 'http_client_stub.dart'
    if (dart.library.html) 'http_client_chromium.dart'
    if (dart.library.io) 'http_client_dartium.dart';
import 'logger.dart';

/// Abstraction over an HTTP client.
///
/// This class provides an abstraction over an HTTP client so that a different implementation can be provided on different platforms.
abstract class HttpClient {
  /// Issues an HTTP GET request to the specified URL, returning a [Future] that resolves with an [HttpResponse] representing the result.
  ///
  /// [url] The URL for the request.
  /// [options] Additional options to configure the request. The 'url' field in this object will be overridden by the [url] parameter.
  /// Returns a [Future] that resolves with an [HttpResponse] describing the response, or rejects with an Error indicating a failure.
  Future<HttpResponse> getAsync(String url, [HttpRequest? options]) {
    options ??= HttpRequest();
    options.method = 'GET';
    options.url = url;
    return sendAsync(options);
  }

  /// Issues an HTTP POST request to the specified URL, returning a [Future] that resolves with an [HttpResponse] representing the result.
  ///
  /// [url] The URL for the request.
  /// [options] Additional options to configure the request. The 'url' field in this object will be overridden by the [url] parameter.
  /// Returns a [Future] that resolves with an [HttpResponse] describing the response, or rejects with an Error indicating a failure.
  Future<HttpResponse> postAsync(String url, [HttpRequest? options]) {
    options ??= HttpRequest();
    options.method = 'POST';
    options.url = url;
    return sendAsync(options);
  }

  /// Issues an HTTP DELETE request to the specified URL, returning a [Future] that resolves with an [HttpResponse] representing the result.
  ///
  /// [url] The URL for the request.
  /// [options] Additional options to configure the request. The 'url' field in this object will be overridden by the [url] parameter.
  /// Returns a [Future] that resolves with an [HttpResponse] describing the response, or rejects with an Error indicating a failure.
  Future<HttpResponse> deleteAsync(String url, [HttpRequest? options]) {
    options ??= HttpRequest();
    options.method = 'DELETE';
    options.url = url;
    return sendAsync(options);
  }

  /// Issues an HTTP request to the specified URL, returning a [Future] that resolves with an [HttpResponse] representing the result.
  ///
  /// [request] An [HttpRequest] describing the request to send.
  /// Returns a [Future] that resolves with an HttpResponse describing the response, or rejects with an Error indicating a failure.
  Future<HttpResponse> sendAsync(HttpRequest request);

  /// Gets all cookies that apply to the specified URL.
  ///
  /// [url] The URL that the cookies are valid for.
  /// Returns a string containing all the key-value cookie pairs for the specified URL.
  String getCookieString(String url) {
    return '';
  }

  HttpClient();

  factory HttpClient.withLogger(Logger logger) => _HttpClient(logger);
}

/// Default implementation of [HttpClient].
class _HttpClient extends HttpClient {
  final HttpClient _httpClient;

  /// Creates a new instance of the [HttpClient], using the provided [logger] to log messages.
  _HttpClient(Logger logger) : _httpClient = createClient(logger);

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
    return _httpClient.sendAsync(request);
  }

  @override
  String getCookieString(String url) {
    return _httpClient.getCookieString(url);
  }
}

/// Represents an HTTP request.
class HttpRequest {
  /// The HTTP method to use for the request.
  String? method;

  /// The URL for the request.
  String? url;

  /// The body content for the request. May be a string or an ArrayBuffer (for binary data).
  Object? content;

  /// An object describing headers to apply to the request.
  Map<String, String>? headers;

  /// The XMLHTTPRequestResponseType to apply to the request.
  String? responseType;

  /// An AbortSignal that can be monitored for cancellation.
  AbortSignal? abortSignal;

  /// The time to wait for the request to complete before throwing a TimeoutError. Measured in milliseconds.
  int? timeout;

  /// This controls whether credentials such as cookies are sent in cross-site requests.
  bool? withCredentials;

  HttpRequest(
      {this.method,
      this.url,
      this.content,
      this.headers,
      this.responseType,
      this.abortSignal,
      this.timeout,
      this.withCredentials});
}

/// Represents an HTTP response.
class HttpResponse {
  /// The status code of the response.
  final int statusCode;

  /// The status message of the response.
  final String? statusText;

  /// The content of the response.
  final Object? content;

  /// Constructs a new instance of [HttpResponse] with the specified status code, message and binary content.
  ///
  /// [statusCode] The status code of the response.
  ///
  /// [statusText] The status message of the response.
  ///
  /// [content] The content of the response.
  HttpResponse(this.statusCode, [this.statusText, this.content]);
}
