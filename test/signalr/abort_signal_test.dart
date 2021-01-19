import 'package:cure/src/signalr/abort_signal.dart';
import 'package:test/test.dart';

void main() {
  group('# aborted', () {
    test('# is false on initialization', () {
      final controller = AbortController();
      final signal = controller.signal;
      expect(signal.aborted, false);
    });
    test('# is true when aborted', () {
      final controller = AbortController();
      final signal = controller.signal;
      controller.abort();
      expect(signal.aborted, true);
    });
  });
  group('# onAbort', () {
    test('# is called when abort is called', () {
      final controller = AbortController();
      final signal = controller.signal;
      var abortCalled = false;
      signal.onabort = () => abortCalled = true;
      controller.abort();
      expect(abortCalled, true);
    });
  });
}
