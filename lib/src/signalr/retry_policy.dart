// 0, 2, 10, 30 second delays before reconnect attempts.
const DEFAULT_RETRY_DELAYS_IN_MILLISECONDS = [0, 2000, 10000, 30000, null];

/// An abstraction that controls when the client attempts to reconnect and how many times it does so.
abstract class RetryPolicy {
  /// Called after the transport loses the connection.
  ///
  /// [retryContext] Details related to the retry event to help determine how long to wait for the next retry.
  ///
  /// Returns the amount of time in milliseconds to wait before the next retry. `null` tells the client to stop retrying.
  int? nextRetryDelayInMilliseconds(RetryContext retryContext);

  factory RetryPolicy([List<int>? retryDelays]) => _RetryPolicy(retryDelays);
}

class _RetryPolicy implements RetryPolicy {
  final List<int?> _retryDelays;

  _RetryPolicy([List<int>? retryDelays])
      : _retryDelays = retryDelays != null
            ? retryDelays.merge([null])
            : DEFAULT_RETRY_DELAYS_IN_MILLISECONDS;

  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) {
    return _retryDelays[retryContext.previousRetryCount];
  }
}

class RetryContext {
  /// The number of consecutive failed tries so far.
  final int previousRetryCount;

  /// The amount of time in milliseconds spent retrying so far.
  final int elapsedMilliseconds;

  /// The exception that forced the upcoming retry.
  final Object retryReason;

  RetryContext(
      this.previousRetryCount, this.elapsedMilliseconds, this.retryReason);
}

extension on List<int> {
  /// Merge [array] into this.
  List<int?> merge(List<int?> array) {
    return List.generate(
        length + array.length, (i) => i < length ? this[i] : array[i - length]);
  }
}
