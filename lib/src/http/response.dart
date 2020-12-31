import 'dart:convert';

import 'content_type.dart';

/// HTTP response
abstract class Response {
  /// statusCode
  int get statusCode;

  /// statusText
  String get statusText;

  /// content
  String get content;

  /// headers
  Map<String, String> get headers;

  /// Create a response
  factory Response(int statusCode, String statusText, String content,
          Map<String, String> headers) =>
      _Response(statusCode, statusText, content, headers);
}

class _Response implements Response {
  @override
  final String content;
  @override
  final Map<String, String> headers;
  @override
  final int statusCode;
  @override
  final String statusText;

  _Response(this.statusCode, this.statusText, this.content, this.headers);
}

extension ResponseExtension on Response {
  Encoding get encoding {
    final charset = contentType?.charset;
    return charset == null ? utf8 : Encoding.getByName(charset);
  }

  ContentType get contentType {
    final source = headers['content-type'];
    return source == null ? null : ContentType.parse(source);
  }
}
