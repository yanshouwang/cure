import 'dart:convert';

import 'package:cure/cryptography.dart';
import 'package:test/test.dart';

void main() {
  group('# SimpleCRC', () {
    test('# CRC-4/ITU', () {
      final crc = CRC.crc4ITU();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x07;
      expect(actual, matcher);
    });
    test('# CRC-5/EPC', () {
      final crc = CRC.crc5EPC();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x00;
      expect(actual, matcher);
    });
    test('# CRC-5/ITU', () {
      final crc = CRC.crc5ITU();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x07;
      expect(actual, matcher);
    });
    test('# CRC-5/USB', () {
      final crc = CRC.crc5USB();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x19;
      expect(actual, matcher);
    });
    test('# CRC-6/ITU', () {
      final crc = CRC.crc6ITU();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x06;
      expect(actual, matcher);
    });
    test('# CRC-7/MMC', () {
      final crc = CRC.crc7MMC();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x75;
      expect(actual, matcher);
    });
    test('# CRC-8', () {
      final crc = CRC.crc8();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xF4;
      expect(actual, matcher);
    });
    test('# CRC-8/ITU', () {
      final crc = CRC.crc8ITU();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xA1;
      expect(actual, matcher);
    });
    test('# CRC-8/MAXIM', () {
      final crc = CRC.crc8MAXIM();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xA1;
      expect(actual, matcher);
    });
    test('# CRC-8/ROHC', () {
      final crc = CRC.crc8ROHC();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xD0;
      expect(actual, matcher);
    });
    test('# CRC-16', () {
      final crc = CRC.crc16();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xBB3D;
      expect(actual, matcher);
    });
    test('# CRC-16/CCITT', () {
      final crc = CRC.crc16CCITT();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x2189;
      expect(actual, matcher);
    });
    test('# CRC-16/CCITT-FALSE', () {
      final crc = CRC.crc16CCITTFALSE();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x29B1;
      expect(actual, matcher);
    });
    test('# CRC-16/DNP', () {
      final crc = CRC.crc16DNP();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xEA82;
      expect(actual, matcher);
    });
    test('# CRC-16/MAXIM', () {
      final crc = CRC.crc16MAXIM();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x44C2;
      expect(actual, matcher);
    });
    test('# CRC-16/MODBUS', () {
      final crc = CRC.crc16MODBUS();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x4B37;
      expect(actual, matcher);
    });
    test('# CRC-16/USB', () {
      final crc = CRC.crc16USB();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xB4C8;
      expect(actual, matcher);
    });
    test('# CRC-16/X25', () {
      final crc = CRC.crc16X25();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x906E;
      expect(actual, matcher);
    });
    test('# CRC-16/XMODEM', () {
      final crc = CRC.crc16XMODEM();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x31C3;
      expect(actual, matcher);
    });
    test('# CRC-32', () {
      final crc = CRC.crc32();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xCBF43926;
      expect(actual, matcher);
    });
    test('# CRC-32/MPEG2', () {
      final crc = CRC.crc32MPEG2();
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x0376E6E7;
      expect(actual, matcher);
    });
  });
  group('# MappingCRC', () {
    test('# CRC-4/ITU', () {
      final crc = CRC.crc4ITU(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x07;
      expect(actual, matcher);
    });
    test('# CRC-5/EPC', () {
      final crc = CRC.crc5EPC(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x00;
      expect(actual, matcher);
    });
    test('# CRC-5/ITU', () {
      final crc = CRC.crc5ITU(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x07;
      expect(actual, matcher);
    });
    test('# CRC-5/USB', () {
      final crc = CRC.crc5USB(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x19;
      expect(actual, matcher);
    });
    test('# CRC-6/ITU', () {
      final crc = CRC.crc6ITU(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x06;
      expect(actual, matcher);
    });
    test('# CRC-7/MMC', () {
      final crc = CRC.crc7MMC(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x75;
      expect(actual, matcher);
    });
    test('# CRC-8', () {
      final crc = CRC.crc8(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xF4;
      expect(actual, matcher);
    });
    test('# CRC-8/ITU', () {
      final crc = CRC.crc8ITU(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xA1;
      expect(actual, matcher);
    });
    test('# CRC-8/MAXIM', () {
      final crc = CRC.crc8MAXIM(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xA1;
      expect(actual, matcher);
    });
    test('# CRC-8/ROHC', () {
      final crc = CRC.crc8ROHC(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xD0;
      expect(actual, matcher);
    });
    test('# CRC-16', () {
      final crc = CRC.crc16(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xBB3D;
      expect(actual, matcher);
    });
    test('# CRC-16/CCITT', () {
      final crc = CRC.crc16CCITT(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x2189;
      expect(actual, matcher);
    });
    test('# CRC-16/CCITT-FALSE', () {
      final crc = CRC.crc16CCITTFALSE(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x29B1;
      expect(actual, matcher);
    });
    test('# CRC-16/DNP', () {
      final crc = CRC.crc16DNP(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xEA82;
      expect(actual, matcher);
    });
    test('# CRC-16/MAXIM', () {
      final crc = CRC.crc16MAXIM(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x44C2;
      expect(actual, matcher);
    });
    test('# CRC-16/MODBUS', () {
      final crc = CRC.crc16MODBUS(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x4B37;
      expect(actual, matcher);
    });
    test('# CRC-16/USB', () {
      final crc = CRC.crc16USB(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xB4C8;
      expect(actual, matcher);
    });
    test('# CRC-16/X25', () {
      final crc = CRC.crc16X25(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x906E;
      expect(actual, matcher);
    });
    test('# CRC-16/XMODEM', () {
      final crc = CRC.crc16XMODEM(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x31C3;
      expect(actual, matcher);
    });
    test('# CRC-32', () {
      final crc = CRC.crc32(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0xCBF43926;
      expect(actual, matcher);
    });
    test('# CRC-32/MPEG2', () {
      final crc = CRC.crc32MPEG2(true);
      final data = utf8.encode('123456789');
      final actual = crc.calculate(data);
      final matcher = 0x0376E6E7;
      expect(actual, matcher);
    });
  });
  test('# Verify', () {
    final crc = CRC.crc4ITU();
    final data = utf8.encode('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    final actual = crc.verify(data, 0x0B);
    final matcher = true;
    expect(actual, matcher);
  });
}
