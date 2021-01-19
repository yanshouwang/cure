import 'dart:collection';
import 'dart:convert';

import 'content_type.dart';

/// HTTP request
class Request {
  /// method
  final String method;

  /// url
  final Uri url;

  /// headers
  final Map<String, String> headers;

  /// content
  String? content;

  /// Create a request.
  Request(this.method, this.url)
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
    return content != null ? encoding.encode(content!) : [];
  }

  Encoding get encoding {
    final charset = contentType?.charset;
    return Encoding.getByName(charset) ?? utf8;
  }

  ContentType? get contentType {
    final source = headers['content-type'];
    return source == null ? null : ContentType.parse(source);
  }
}
