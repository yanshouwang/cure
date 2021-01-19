import 'client.dart';
import 'content_type.dart';
import 'request.dart';
import 'response.dart';

abstract class BaseClient implements Client {
  @override
  Future<Response> headAsync(String url, [Map<String, String>? headers]) =>
      _sendAsync('HEAD', url, headers);

  @override
  Future<Response> getAsync(String url, [Map<String, String>? headers]) =>
      _sendAsync('GET', url, headers);

  @override
  Future<Response> postAsync(
          String url, String content, ContentType contentType,
          [Map<String, String>? headers]) =>
      _sendAsync('POST', url, headers, content, contentType);

  @override
  Future<Response> putAsync(String url, String content, ContentType contentType,
          [Map<String, String>? headers]) =>
      _sendAsync('PUT', url, headers, content, contentType);

  @override
  Future<Response> patchAsync(
          String url, String content, ContentType contentType,
          [Map<String, String>? headers]) =>
      _sendAsync('PATCH', url, headers, content, contentType);

  @override
  Future<Response> deleteAsync(String url, [Map<String, String>? headers]) =>
      _sendAsync('DELETE', url, headers);

  Future<Response> _sendAsync(String method, String url,
      [Map<String, String>? headers,
      String? content,
      ContentType? contentType]) {
    final uri = Uri.parse(url);
    final request = Request(method, uri);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (content != null) {
      request.content = content;
    }
    if (contentType != null) {
      request.headers['content-type'] = contentType.toString();
    }
    return sendAsync(request);
  }
}
