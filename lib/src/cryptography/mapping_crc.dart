import 'dart:math';

import 'base_crc.dart';
import 'utils.dart';

class MappingCRC extends BaseCRC {
  final Map<int, int> _map;

  MappingCRC(String name, int width, int poly, int init, bool refIn,
      bool refOut, int xorOut)
      : _map = _createMap(width, poly),
        super(name, width, poly, init, refIn, refOut, xorOut);

  @override
  int calculate(List<int> data) {
    final digits1 = max(8 - width, 0);
    final digits2 = max(width - 8, 0);
    var crc = init << digits1;
    for (var item in data) {
      if (refIn) {
        item = item.reverse8();
      }
      // 本字节的 CRC, 等于上一字节的 CRC 左移八位, 与上一字节的 CRC 高八位同本字节异或后对应 CRC 的异或值
      final key = (crc >> digits2) & 0xff ^ item;
      final value = _map[key];
      crc = (crc << 8) ^ value;
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

Map<int, int> _createMap(int width, int poly) {
  final map = <int, int>{};
  for (var key = 0; key <= 0xff; key++) {
    // 1) 将 Mx^r 的前 r 位放入一个长度为 r 的寄存器
    // 2) 如果寄存器的首位为 1，将寄存器左移 1 位(将 Mx^r 剩下部分的 MSB 移入寄存器的 LSB)，再与 G 的后 r 位异或，否则仅将寄存器左移 1 位(将 Mx^r 剩下部分的 MSB 移入寄存器的 LSB)
    // 3) 重复第 2 步，直到 M 全部 Mx^r 移入寄存器
    // 4) 寄存器中的值则为校验码
    final digits1 = max(8 - width, 0);
    final digits2 = max(width - 8, 0);
    var value = key << digits2;
    final expected = 0x80 << digits2;
    final fixed = poly << digits1;
    for (var i = 0; i < 8; i++) {
      final actual = value & expected;
      if (actual == expected) {
        value = (value << 1) ^ fixed;
      } else {
        value <<= 1;
      }
    }
    map[key] = value;
  }
  return map;
}
