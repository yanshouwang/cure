import 'dart:typed_data';

import 'package:cure/src/signalr_message_pack/binary_message_format.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

void main() {
  [
    Tuple2(<int>[], []),
    Tuple2([0x00], [<int>[]]),
    Tuple2(
      [0x01, 0xff],
      [
        [0xff],
      ],
    ),
    Tuple2(
      [0x01, 0xff, 0x01, 0x7f],
      [
        [0xff],
        [0x7f],
      ],
    ),
  ].forEach((element) {
    test("# should parse '${element.item1}' correctly", () {
      final data = Uint8List.fromList(element.item1);
      final actual = BinaryMessageFormat.parse(data);
      final matcher = element.item2.map((e) => Uint8List.fromList(e));
      expect(actual, matcher);
    });
  });

  [
    Tuple2([0x80], 'Cannot read message size.'),
    Tuple2([0x02, 0x01, 0x80, 0x80], 'Cannot read message size.'),
    Tuple2(
      [0x07, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x80],
      'Cannot read message size.',
    ),
    Tuple2(
      [0x07, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01],
      'Incomplete message.',
    ),
    Tuple2(
      [0xff, 0xff, 0xff, 0xff, 0xff],
      'Messages bigger than 2GB are not supported.',
    ),
    Tuple2(
      [0x80, 0x80, 0x80, 0x80, 0x08],
      'Messages bigger than 2GB are not supported.',
    ),
    Tuple2(
      [0x80, 0x80, 0x80, 0x80, 0x80],
      'Messages bigger than 2GB are not supported.',
    ),
    Tuple2([0x02, 0x00], 'Incomplete message.'),
    Tuple2([0xff, 0xff, 0xff, 0xff, 0x07], 'Incomplete message.'),
  ].forEach((element) {
    test('# throws `${element.item2}`', () {
      final m = predicate((e) => '$e' == 'Exception: ${element.item2}');
      final matcher = throwsA(m);
      final data = Uint8List.fromList(element.item1);
      expect(() => BinaryMessageFormat.parse(data), matcher);
    });
  });

  [
    Tuple2(<int>[], [0x00]),
    Tuple2([0x20], [0x01, 0x20]),
  ].forEach((element) {
    test("# should write '${element.item1}'", () {
      final data = Uint8List.fromList(element.item1);
      final actual = BinaryMessageFormat.write(data);
      final matcher = Uint8List.fromList(element.item2);
      expect(actual, matcher);
    });
  });

  [0x0000, 0x0001, 0x007f, 0x0080, 0x3fff, 0x4000, 0xc0de].forEach((size) {
    test("# messages should be roundtrippable (message size: '${size}')", () {
      final elements = <int>[];
      for (var i = 0; i < size; i++) {
        elements.add(i & 0xff);
      }
      final data0 = Uint8List.fromList(elements);
      final data1 = BinaryMessageFormat.write(data0);
      final data2 = BinaryMessageFormat.parse(data1);
      expect(data2.length, 1);
      expect(data2[0], data0);
    });
  });
}
