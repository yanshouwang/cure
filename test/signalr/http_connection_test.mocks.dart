import 'dart:async' as _i3;

import 'package:cure/src/signalr/logger.dart' as _i4;
import 'package:cure/src/signalr/transport.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;

// ignore_for_file: comment_references

// ignore_for_file: unnecessary_parenthesis

/// A class which mocks [Transport].
///
/// See the documentation for Mockito's code generation for more information.
class MockTransport extends _i1.Mock implements _i2.Transport {
  MockTransport() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Future<void> connectAsync(
          String? url, _i2.TransferFormat? transferFormat) =>
      (super.noSuchMethod(
          Invocation.method(#connectAsync, [url, transferFormat]),
          Future.value(null)) as _i3.Future<void>);
  @override
  _i3.Future<void> sendAsync(Object? data) => (super.noSuchMethod(
          Invocation.method(#sendAsync, [data]), Future.value(null))
      as _i3.Future<void>);
  @override
  _i3.Future<void> stopAsync() =>
      (super.noSuchMethod(Invocation.method(#stopAsync, []), Future.value(null))
          as _i3.Future<void>);
}

/// A class which mocks [Logger].
///
/// See the documentation for Mockito's code generation for more information.
class MockLogger extends _i1.Mock implements _i4.Logger {
  MockLogger() {
    _i1.throwOnMissingStub(this);
  }

  @override
  void log(_i4.LogLevel? logLevel, String? message) =>
      super.noSuchMethod(Invocation.method(#log, [logLevel, message]));
}
