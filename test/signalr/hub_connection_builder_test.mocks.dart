import 'package:cure/src/signalr/logger.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;

// ignore_for_file: comment_references

// ignore_for_file: unnecessary_parenthesis

/// A class which mocks [Logger].
///
/// See the documentation for Mockito's code generation for more information.
class MockLogger extends _i1.Mock implements _i2.Logger {
  MockLogger() {
    _i1.throwOnMissingStub(this);
  }

  @override
  void log(_i2.LogLevel? logLevel, String? message) =>
      super.noSuchMethod(Invocation.method(#log, [logLevel, message]));
}
