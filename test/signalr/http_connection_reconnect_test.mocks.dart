import 'package:cure/src/signalr/retry_policy.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;

// ignore_for_file: comment_references

// ignore_for_file: unnecessary_parenthesis

/// A class which mocks [RetryPolicy].
///
/// See the documentation for Mockito's code generation for more information.
class MockRetryPolicy extends _i1.Mock implements _i2.RetryPolicy {
  MockRetryPolicy() {
    _i1.throwOnMissingStub(this);
  }

  @override
  int? nextRetryDelayInMilliseconds(_i2.RetryContext? retryContext) =>
      (super.noSuchMethod(
              Invocation.method(#nextRetryDelayInMilliseconds, [retryContext]))
          as int?);
}
