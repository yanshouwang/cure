import 'mapping_crc.dart';
import 'simple_crc.dart';

/// Cyclic Redundancy Check， CRC
abstract class CRC {
  /// name
  String get name;

  /// width
  int get width;

  /// poly
  int get poly;

  /// init
  int get init;

  /// refIn
  bool get refIn;

  /// refOut
  bool get refOut;

  /// xorOut
  int get xorOut;

  /// Caculate [data]'s crc.
  int calculate(List<int> data);

  /// Verify weather [data] matches the [crc].
  bool verify(List<int> data, int crc);

  /// Create a [CRC] with arguments.
  factory CRC(String name, int width, int poly, int init, bool refIn,
      bool refOut, int xorOut,
      [bool mapping = false]) {
    final crc = mapping
        ? MappingCRC(name, width, poly, init, refIn, refOut, xorOut)
        : SimpleCRC(name, width, poly, init, refIn, refOut, xorOut);
    return crc;
  }

  /// CRC-4/ITU
  factory CRC.crc4ITU([bool mapping = false]) =>
      CRC('CRC-4/ITU', 4, 0x03, 0x00, true, true, 0x00, mapping);

  /// CRC-5/EPC
  factory CRC.crc5EPC([bool mapping = false]) =>
      CRC('CRC-5/EPC', 5, 0x09, 0x09, false, false, 0x00, mapping);

  /// CRC-5/ITU
  factory CRC.crc5ITU([bool mapping = false]) =>
      CRC('CRC-5/ITU', 5, 0X15, 0x00, true, true, 0x00, mapping);

  /// CRC-5/USB
  factory CRC.crc5USB([bool mapping = false]) =>
      CRC('CRC-5/USB', 5, 0x05, 0x1F, true, true, 0x1F, mapping);

  /// CRC-6/ITU
  factory CRC.crc6ITU([bool mapping = false]) =>
      CRC('CRC-6/ITU', 6, 0x03, 0x00, true, true, 0x00, mapping);

  /// CRC-7/MMC
  factory CRC.crc7MMC([bool mapping = false]) =>
      CRC('CRC-7/MMC', 7, 0x09, 0x00, false, false, 0x00, mapping);

  /// CRC-8
  factory CRC.crc8([bool mapping = false]) =>
      CRC('CRC-8', 8, 0x07, 0x00, false, false, 0x00, mapping);

  /// CRC-8/ITU
  factory CRC.crc8ITU([bool mapping = false]) =>
      CRC('CRC-8/ITU', 8, 0x07, 0x00, false, false, 0x55, mapping);

  /// CRC-8/MAXIM
  factory CRC.crc8MAXIM([bool mapping = false]) =>
      CRC('CRC-8/MAXIM', 8, 0x31, 0x00, true, true, 0x00, mapping);

  /// CRC-8/ROHC
  factory CRC.crc8ROHC([bool mapping = false]) =>
      CRC('CRC-8/ROHC', 8, 0x07, 0xFF, true, true, 0x00, mapping);

  /// CRC-16
  factory CRC.crc16([bool mapping = false]) =>
      CRC('CRC-16', 16, 0x8005, 0x0000, true, true, 0x0000, mapping);

  /// CRC-16/CCITT
  factory CRC.crc16CCITT([bool mapping = false]) =>
      CRC('CRC-16/CCITT', 16, 0x1021, 0x0000, true, true, 0x0000, mapping);

  /// CRC-16/CCITT-FALSE
  factory CRC.crc16CCITTFALSE([bool mapping = false]) => CRC(
      'CRC-16/CCITT-FALSE', 16, 0x1021, 0xFFFF, false, false, 0x0000, mapping);

  /// CRC-16/DNP
  factory CRC.crc16DNP([bool mapping = false]) =>
      CRC('CRC-16/DNP', 16, 0x3D65, 0x0000, true, true, 0xFFFF, mapping);

  /// CRC-16/MAXIM
  factory CRC.crc16MAXIM([bool mapping = false]) =>
      CRC('CRC-16/MAXIM', 16, 0x8005, 0x0000, true, true, 0xFFFF, mapping);

  /// CRC-16/MODBUS
  factory CRC.crc16MODBUS([bool mapping = false]) =>
      CRC('CRC-16/MODBUS', 16, 0x8005, 0xFFFF, true, true, 0x0000, mapping);

  /// CRC-16/USB
  factory CRC.crc16USB([bool mapping = false]) =>
      CRC('CRC-16/USB', 16, 0x8005, 0xFFFF, true, true, 0xFFFF, mapping);

  /// CRC-16/X25
  factory CRC.crc16X25([bool mapping = false]) =>
      CRC('CRC-16/X25', 16, 0x1021, 0xFFFF, true, true, 0xFFFF, mapping);

  /// CRC-16/XMODEM
  factory CRC.crc16XMODEM([bool mapping = false]) =>
      CRC('CRC-16/XMODEM', 16, 0x1021, 0x0000, false, false, 0x0000, mapping);

  /// CRC-32
  factory CRC.crc32([bool mapping = false]) => CRC(
      'CRC-32', 32, 0x04C11DB7, 0xFFFFFFFF, true, true, 0xFFFFFFFF, mapping);

  /// CRC-32/MPEG-2
  factory CRC.crc32MPEG2([bool mapping = false]) => CRC('CRC-32/MPEG-2', 32,
      0x04C11DB7, 0xFFFFFFFF, false, false, 0x00000000, mapping);
}
