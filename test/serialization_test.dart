import 'package:cure/serialization.dart';
import 'package:test/test.dart';

void main() {
  group('JSON', () {
    test('# fromJSON', () {
      final source = '["A","B","C"]';
      final actual = JSON.fromJSON(source);
      final matcher = ['A', 'B', 'C'];
      expect(actual, matcher);
    });

    test('# toJSON', () {
      final obj = ['A', 'B', 'C'];
      final actual = JSON.toJSON(obj);
      final matcher = '["A","B","C"]';
      expect(actual, matcher);
    });
  });
}
