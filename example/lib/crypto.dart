import 'dart:convert';

import 'package:cure/crypto.dart';

void main() {
  final crc = CRC.crc16MODBUS();
  final data = utf8.encode('123456789');
  final value = crc.calculate(data);
  print(value);
  final result = crc.verify(data, value);
  print(result);
}
