import 'client_stub.dart'
    if (dart.library.html) 'client_html.dart'
    if (dart.library.io) 'client_io.dart';
import 'content_type.dart';
import 'request.dart';
import 'response.dart';

/// Client for RESTful API
abstract class Client {
  /// HEAD
  Future<Response> headAsync(String url, [Map<String, String> headers]);

  /// GET
  Future<Response> getAsync(String url, [Map<String, String> headers]);

  /// POST
  Future<Response> postAsync(
      String url, String content, ContentType contentType,
      [Map<String, String> headers]);

  /// PUT
  Future<Response> putAsync(String url, String content, ContentType contentType,
      [Map<String, String> headers]);

  /// PATCH
  Future<Response> patchAsync(
      String url, String content, ContentType contentType,
      [Map<String, String> headers]);

  /// DELETE
  Future<Response> deleteAsync(String url, [Map<String, String> headers]);

  /// Send a [request].
  Future<Response> sendAsync(Request request);

  /// Close the connection.
  ///
  /// If [force] is true, the connection will close immediately and will throw an exception when a request is not complete.
  void close([bool force = false]);

  factory Client() => createClient();
}
