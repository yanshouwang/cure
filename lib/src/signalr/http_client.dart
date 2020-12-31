import 'abort_controller.dart';

/// Abstraction over an HTTP client.
///
/// This class provides an abstraction over an HTTP client so that a different implementation can be provided on different platforms.
abstract class HTTPClient {
  /// Issues an HTTP GET request to the specified URL, returning a [Future] that resolves with an [HTTPResponse] representing the result.
  ///
  /// [url] The URL for the request.
  /// [options] Additional options to configure the request. The 'url' field in this object will be overridden by the [url] parameter.
  /// Returns a [Future] that resolves with an [HTTPResponse] describing the response, or rejects with an Error indicating a failure.
  Future<HTTPResponse> getAsync(String url, [HTTPRequest options]) {
    options ??= HTTPRequest();
    options.method = 'GET';
    options.url = url;
    return sendAsync(options);
  }

  /// Issues an HTTP POST request to the specified URL, returning a [Future] that resolves with an [HTTPResponse] representing the result.
  ///
  /// [url] The URL for the request.
  /// [options] Additional options to configure the request. The 'url' field in this object will be overridden by the [url] parameter.
  /// Returns a [Future] that resolves with an [HTTPResponse] describing the response, or rejects with an Error indicating a failure.
  Future<HTTPResponse> postAsync(String url, [HTTPRequest options]) {
    options ??= HTTPRequest();
    options.method = 'POST';
    options.url = url;
    return sendAsync(options);
  }

  /// Issues an HTTP DELETE request to the specified URL, returning a [Future] that resolves with an [HTTPResponse] representing the result.
  ///
  /// [url] The URL for the request.
  /// [options] Additional options to configure the request. The 'url' field in this object will be overridden by the [url] parameter.
  /// Returns a [Future] that resolves with an [HTTPResponse] describing the response, or rejects with an Error indicating a failure.
  Future<HTTPResponse> deleteAsync(String url, [HTTPRequest options]) {
    options ??= HTTPRequest();
    options.method = 'DELETE';
    options.url = url;
    return sendAsync(options);
  }

  /// Issues an HTTP request to the specified URL, returning a [Future] that resolves with an [HTTPResponse] representing the result.
  ///
  /// [request] An [HTTPRequest] describing the request to send.
  /// Returns a [Future] that resolves with an HttpResponse describing the response, or rejects with an Error indicating a failure.
  Future<HTTPResponse> sendAsync(HTTPRequest request);

  /// Gets all cookies that apply to the specified URL.
  ///
  /// [url] The URL that the cookies are valid for.
  /// Returns a string containing all the key-value cookie pairs for the specified URL.
  String getCookieString(String url) {
    return '';
  }
}

/// Represents an HTTP request.
abstract class HTTPRequest {
  /// The HTTP method to use for the request.
  String method;

  /// The URL for the request.
  String url;

  /// The body content for the request. May be a string or an ArrayBuffer (for binary data).
  dynamic content;

  /// An object describing headers to apply to the request.
  Map<String, String> headers;

  /// The XMLHttpRequestResponseType to apply to the request.
  String responseType;

  /// An AbortSignal that can be monitored for cancellation.
  AbortSignal abortSignal;

  /// The time to wait for the request to complete before throwing a TimeoutError. Measured in milliseconds.
  int timeout;

  /// This controls whether credentials such as cookies are sent in cross-site requests.
  bool withCredentials;

  factory HTTPRequest(
          {String method,
          String url,
          dynamic content,
          Map<String, String> headers,
          String responseType,
          AbortSignal abortSignal,
          int timeout,
          bool withCredentials}) =>
      _HTTPRequest(method, url, content, headers, responseType, abortSignal,
          timeout, withCredentials);
}

class _HTTPRequest implements HTTPRequest {
  @override
  AbortSignal abortSignal;
  @override
  var content;
  @override
  Map<String, String> headers;
  @override
  String method;
  @override
  String responseType;
  @override
  int timeout;
  @override
  String url;
  @override
  bool withCredentials;

  _HTTPRequest(this.method, this.url, this.content, this.headers,
      this.responseType, this.abortSignal, this.timeout, this.withCredentials);
}

/// Represents an HTTP response.
abstract class HTTPResponse {
  /// The status code of the response.
  final int statusCode;

  /// The status message of the response.
  final String statusText;

  /// The content of the response.
  final dynamic content;

  /// Constructs a new instance of [HTTPResponse] with the specified status code, message and binary content.
  ///
  /// [statusCode] The status code of the response.
  ///
  /// [statusText] The status message of the response.
  ///
  /// [content] The content of the response.
  factory HTTPResponse(int statusCode, [String statusText, dynamic content]) =>
      _HTTPResponse(statusCode, statusText, content);
}

class _HTTPResponse implements HTTPResponse {
  @override
  final int statusCode;
  @override
  final String statusText;
  @override
  final dynamic content;

  _HTTPResponse(this.statusCode, this.statusText, this.content);
}
