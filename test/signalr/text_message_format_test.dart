import 'package:cure/signalr.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

void main() {
  group('# should parse correctly', () {
    final elements = [
      Tuple2('\u001e', ['']),
      Tuple2('\u001e\u001e', ['', '']),
      Tuple2('Hello\u001e', ['Hello']),
      Tuple2('Hello,\u001eWorld!\u001e', ['Hello,', 'World!']),
    ];
    for (var element in elements) {
      test('# ${Uri.encodeFull(element.item1)}', () {
        final messages = TextMessageFormat.parse(element.item1);
        expect(messages, element.item2);
      });
    }
  });
  group('# should fail to parse', () {
    final elements = [
      Tuple2('', 'Message is incomplete.'),
      Tuple2('ABC', 'Message is incomplete.'),
      Tuple2('ABC\u001eXYZ', 'Message is incomplete.')
    ];
    for (var element in elements) {
      test('# ${Uri.encodeFull(element.item1)}', () {
        final m = predicate((e) => '$e' == 'Exception: ${element.item2}');
        final matcher = throwsA(m);
        expect(() => TextMessageFormat.parse(element.item1), matcher);
      });
    }
  });
}
