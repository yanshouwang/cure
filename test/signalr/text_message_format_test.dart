import 'package:cure/signalr.dart';
import 'package:test/test.dart';

void main() {
  group('# Should parse correctly', () {
    final items = [
      MapEntry('\u001e', ['']),
      MapEntry('\u001e\u001e', ['', '']),
      MapEntry('Hello\u001e', ['Hello']),
      MapEntry('Hello,\u001eWorld!\u001e', ['Hello,', 'World!']),
    ];
    for (var item in items) {
      test('# ${Uri.encodeFull(item.key)}', () {
        final messages = TextMessageFormat.parse(item.key);
        expect(messages, item.value);
      });
    }
  });

  group('# Should fail to parse', () {
    final items = [
      MapEntry('', 'Message is incomplete.'),
      MapEntry('ABC', 'Message is incomplete.'),
      MapEntry('ABC\u001eXYZ', 'Message is incomplete.')
    ];
    for (var item in items) {
      test('# ${Uri.encodeFull(item.key)}', () {
        final error = Exception(item.value);
        final m = predicate((e) => '$e' == '$error');
        final matcher = throwsA(m);
        expect(() => TextMessageFormat.parse(item.key), matcher);
      });
    }
  });
}
