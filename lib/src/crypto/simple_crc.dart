import 'dart:math';

import 'base_crc.dart';
import 'utils.dart';

class SimpleCRC extends BaseCRC {
  SimpleCRC(String name, int width, int poly, int init, bool refIn, bool refOut,
      int xorOut)
      : super(name, width, poly, init, refIn, refOut, xorOut);

  @override
  int calculate(List<int> data) {
    // width < 8：crc 需要与 byte 左对齐
    final digits1 = max(8 - width, 0);
    // width > 8：byte 需要与 crc 左对齐
    final digits2 = max(width - 8, 0);
    var crc = init << digits1;
    for (var item in data) {
      if (refIn) {
        // 反转每个字节
        item = item.reverse8();
      }
      crc ^= item << digits2;
      final expected = 0x80 << digits2;
      final fixed = poly << digits1;
      for (var i = 0; i < 8; i++) {
        final actual = crc & expected;
        if (actual == expected) {
          crc = (crc << 1) ^ fixed;
        } else {
          crc <<= 1;
        }
      }
    }
    crc >>= digits1;
    if (refOut) {
      crc = crc.reverse32();
      crc >>= 32 - width;
    }
    crc ^= xorOut;
    final mask = pow(2, width).toInt() - 1;
    crc &= mask;
    return crc;
  }
}
