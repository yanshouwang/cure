import 'dart:math';
import 'dart:typed_data';

abstract class BinaryMessageFormat {
  static Uint8List write(Uint8List output) {
    var size = output.lengthInBytes;
    final lenBuffer = <int>[];
    do {
      var sizePart = size & 0x7f;
      size = size >> 7;
      if (size > 0) {
        sizePart |= 0x80;
      }
      lenBuffer.add(sizePart);
    } while (size > 0);

    size = output.lengthInBytes;

    final buffer = Uint8List(lenBuffer.length + size);
    buffer.setAll(0, lenBuffer);
    buffer.setAll(lenBuffer.length, output);
    return buffer;
  }

  static List<Uint8List> parse(Uint8List input) {
    final result = <Uint8List>[];
    final uint8Array = Uint8List.fromList(input);
    final maxLengthPrefixSize = 5;
    final numBitsToShift = [0, 7, 14, 21, 28];

    for (var offset = 0; offset < input.lengthInBytes;) {
      var numBytes = 0;
      var size = 0;
      var byteRead;
      do {
        byteRead = uint8Array[offset + numBytes];
        size = size | ((byteRead & 0x7f) << (numBitsToShift[numBytes]));
        numBytes++;
      } while (
          numBytes < min(maxLengthPrefixSize, input.lengthInBytes - offset) &&
              (byteRead & 0x80) != 0);

      if ((byteRead & 0x80) != 0 && numBytes < maxLengthPrefixSize) {
        throw Exception('Cannot read message size.');
      }

      if (numBytes == maxLengthPrefixSize && byteRead > 7) {
        throw Exception('Messages bigger than 2GB are not supported.');
      }

      if (uint8Array.lengthInBytes >= (offset + numBytes + size)) {
        result.add(
            uint8Array.sublist(offset + numBytes, offset + numBytes + size));
      } else {
        throw Exception('Incomplete message.');
      }

      offset = offset + numBytes + size;
    }

    return result;
  }
}
