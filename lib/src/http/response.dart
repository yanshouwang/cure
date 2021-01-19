import 'dart:convert';

import 'content_type.dart';

/// HTTP response
class Response {
  /// statusCode
  final int statusCode;

  /// statusText
  final String? statusText;

  /// content
  final String? content;

  /// headers
  final Map<String, String> headers;

  /// Create a response
  Response(this.statusCode, this.statusText, this.content, this.headers);
}

extension ResponseExtension on Response {
  Encoding get encoding {
    final charset = contentType?.charset;
    return Encoding.getByName(charset) ?? utf8;
  }

  ContentType? get contentType {
    final source = headers['content-type'];
    return source == null ? null : ContentType.parse(source);
  }
}
