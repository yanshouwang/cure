import 'crc.dart';

/// Base class to implement CRC
abstract class BaseCRC implements CRC {
  @override
  final String name;
  @override
  final int width;
  @override
  final int poly;
  @override
  final int init;
  @override
  final bool refIn;
  @override
  final bool refOut;
  @override
  final int xorOut;

  BaseCRC(this.name, this.width, this.poly, this.init, this.refIn, this.refOut,
      this.xorOut);

  @override
  bool verify(List<int> data, int crc) {
    final expected = calculate(data);
    return crc == expected;
  }
}
