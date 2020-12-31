import 'package:string_scanner/string_scanner.dart';

import 'utils.dart';

abstract class ContentType {
  String get mimeType;
  String get primaryType;
  String get subType;
  String get charset;

  factory ContentType(String primaryType, String subType, [String charset]) =>
      _ContentType(primaryType, subType, charset);

  factory ContentType.parse(String source) {
    final scanner = StringScanner(source);
    scanner.scan(whitespace);
    scanner.expect(token);
    final primaryType = scanner.lastMatch[0].toLowerCase();
    scanner.expect('/');
    scanner.expect(token);
    final subType = scanner.lastMatch[0].toLowerCase();
    scanner.scan(whitespace);
    final parameters = <String, String>{};
    while (scanner.scan(';')) {
      scanner.scan(whitespace);
      scanner.expect(token);
      final key = scanner.lastMatch[0].toLowerCase();
      scanner.expect('=');
      scanner.expect(token);
      final value = scanner.lastMatch[0];
      scanner.scan(whitespace);
      parameters[key] = value;
    }
    scanner.expectDone();
    final charset = parameters['charset'];
    return ContentType(primaryType, subType, charset);
  }

  static ContentType get text => ContentType.parse('text/plain; charset=utf-8');
  static ContentType get html => ContentType.parse('text/html; charset=utf-8');
  static ContentType get urlencoded =>
      ContentType.parse('application/x-www-form-urlencoded; charset=utf-8');
  static ContentType get json =>
      ContentType.parse('application/json; charset=utf-8');
}

class _ContentType implements ContentType {
  @override
  final String primaryType;
  @override
  final String subType;
  @override
  final String charset;

  @override
  String get mimeType => '${primaryType}/${subType}';

  _ContentType(this.primaryType, this.subType, this.charset);
}

extension ContentTypeExtension on ContentType {
  MapEntry<String, String> get header {
    final key = 'content-type';
    final value =
        charset == null ? mimeType : '${mimeType}; charset=${charset}';
    return MapEntry(key, value);
  }
}
