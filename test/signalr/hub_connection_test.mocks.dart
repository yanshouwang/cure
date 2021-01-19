import 'package:cure/src/signalr/logger.dart' as _i3;
import 'package:cure/src/signalr/stream.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;

// ignore_for_file: comment_references

// ignore_for_file: unnecessary_parenthesis

/// A class which mocks [StreamSubscriber].
///
/// See the documentation for Mockito's code generation for more information.
class MockStreamSubscriber<T> extends _i1.Mock
    implements _i2.StreamSubscriber<T> {
  MockStreamSubscriber() {
    _i1.throwOnMissingStub(this);
  }

  @override
  void next(T? value) => super.noSuchMethod(Invocation.method(#next, [value]));
  @override
  void error(Object? error) =>
      super.noSuchMethod(Invocation.method(#error, [error]));
}

/// A class which mocks [Logger].
///
/// See the documentation for Mockito's code generation for more information.
class MockLogger extends _i1.Mock implements _i3.Logger {
  MockLogger() {
    _i1.throwOnMissingStub(this);
  }

  @override
  void log(_i3.LogLevel? logLevel, String? message) =>
      super.noSuchMethod(Invocation.method(#log, [logLevel, message]));
}
