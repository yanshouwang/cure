import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Extension for ByteArrayStream.
extension ByteArrayStreamExtension on Stream<List<int>> {
  /// Extract [ByteBuffer] from this stream.
  Future<Uint8List> extractAsync() {
    var completer = Completer<Uint8List>();
    var sink = ByteConversionSink.withCallback((elements) {
      final value = Uint8List.fromList(elements);
      completer.complete(value);
    });
    listen((data) => sink.add(data),
        onError: completer.completeError,
        onDone: sink.close,
        cancelOnError: true);
    return completer.future;
  }
}

/// Extension for int.
extension IntExtension on int {
  /// Reverse 8 bits.
  int reverse8() {
    var value = (this & 0xf0) >> 4 | (this & 0x0f) << 4;
    value = (value & 0xcc) >> 2 | (value & 0x33) << 2;
    value = (value & 0xaa) >> 1 | (value & 0x55) << 1;
    return value;
  }

  /// Reverse 32 bits.
  int reverse32() {
    var value = (this & 0xffff0000) >> 16 | (this & 0x0000ffff) << 16;
    value = (value & 0xff00ff00) >> 8 | (value & 0x00ff00ff) << 8;
    value = (value & 0xf0f0f0f0) >> 4 | (value & 0x0f0f0f0f) << 4;
    value = (value & 0xcccccccc) >> 2 | (value & 0x33333333) << 2;
    value = (value & 0xaaaaaaaa) >> 1 | (value & 0x55555555) << 1;
    return value;
  }
}
