import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// ByteArrayStream Extension
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

/// List Extension
extension ListExtension<T> on List<T> {
  /// Merge [array] into this.
  List<T> merge(List<T> array) {
    return List.generate(
        length + array.length, (i) => i < length ? this[i] : array[i - length]);
  }
}