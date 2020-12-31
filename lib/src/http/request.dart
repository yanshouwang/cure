import 'dart:collection';
import 'dart:convert';

import 'content_type.dart';

/// HTTP request
abstract class Request {
  /// method
  String get method;

  /// url
  Uri get url;

  /// headers
  Map<String, String> get headers;

  /// content
  String content;

  /// Create a request.
  factory Request(String method, Uri url) => _Request(method, url);
}

class _Request implements Request {
  @override
  final String method;
  @override
  final Uri url;
  @override
  final Map<String, String> headers;

  @override
  String content;

  _Request(this.method, this.url)
      : headers = LinkedHashMap(
            equals: (key1, key2) => key1.toLowerCase() == key2.toLowerCase(),
            hashCode: (key) => key.toLowerCase().hashCode);

  @override
  String toString() {
    return '$method $url';
  }
}

extension RequestExtension on Request {
  List<int> encode() {
    return content == null ? [] : encoding.encode(content);
  }

  Encoding get encoding {
    final charset = contentType?.charset;
    return charset == null ? utf8 : Encoding.getByName(charset);
  }

  ContentType get contentType {
    final source = headers['content-type'];
    return source == null ? null : ContentType.parse(source);
  }
}
