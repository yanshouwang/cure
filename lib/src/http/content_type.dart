import 'package:string_scanner/string_scanner.dart';

import 'utils.dart';

/// The `Content-Type` entity header is used to indicate the
/// [media type](https://developer.mozilla.org/en-US/docs/Glossary/MIME_type)
/// of the resource.
class ContentType {
  /// The [MIME type](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types)
  /// of the resource or the data.
  final MimeType mediaType;

  /// The character encoding standard.
  final String? charset;

  /// Create a ContentType.
  ContentType(this.mediaType, this.charset);

  /// Create a ContentType from String.
  factory ContentType.parse(String source) {
    final scanner = StringScanner(source);
    scanner.scan(whitespace);
    scanner.expect(token);
    final type = scanner.lastMatch![0]!.toLowerCase();
    scanner.expect('/');
    scanner.expect(token);
    final subType = scanner.lastMatch![0]!.toLowerCase();
    scanner.scan(whitespace);
    final parameters = <String, String?>{};
    while (scanner.scan(';')) {
      scanner.scan(whitespace);
      scanner.expect(token);
      final key = scanner.lastMatch![0]!.toLowerCase();
      scanner.expect('=');
      scanner.expect(token);
      final value = scanner.lastMatch![0];
      scanner.scan(whitespace);
      parameters[key] = value;
    }
    scanner.expectDone();
    final mediaType = MimeType(type, subType);
    final charset = parameters['charset'];
    return ContentType(mediaType, charset);
  }

  /// text/plain; charset=utf-8
  static ContentType get text => ContentType.parse('text/plain; charset=utf-8');

  /// text/html; charset=utf-8
  static ContentType get html => ContentType.parse('text/html; charset=utf-8');

  /// application/x-www-form-urlencoded; charset=utf-8
  static ContentType get urlencoded =>
      ContentType.parse('application/x-www-form-urlencoded; charset=utf-8');

  /// application/json; charset=utf-8
  static ContentType get json =>
      ContentType.parse('application/json; charset=utf-8');

  @override
  String toString() =>
      charset == null ? '$mediaType' : '$mediaType; charset=${charset}';
}

/// A media type (also known as a Multipurpose Internet Mail Extensions or MIME
/// type) is a standard that indicates the nature and format of a document,
/// file, or assortment of bytes. It is defined and standardized in IETF's
/// [RFC 6838](https://tools.ietf.org/html/rfc6838).
class MimeType {
  /// The `type` represents the general category into which the data type falls,
  /// such as `video` or `text`.
  final String type;

  /// The `subtype` identifies the exact kind of data of the specified type the
  /// MIME type represents.
  ///
  /// For example, for the MIME type `text`, the subtype might be `plain` (plain text),
  /// `html` (HTML source code), or `calendar` (for iCalendar/.ics) files.
  final String subType;

  /// Create a MimeType.
  MimeType(this.type, this.subType);

  @override
  String toString() => '${type}/${subType}';
}
