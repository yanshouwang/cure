/// An abstraction that controls when the client attempts to reconnect and how many times it does so.
abstract class RetryPolicy {
  /// Called after the transport loses the connection.
  ///
  /// [retryContext] Details related to the retry event to help determine how long to wait for the next retry.
  ///
  /// Returns the amount of time in milliseconds to wait before the next retry. `null` tells the client to stop retrying.
  int nextRetryDelayInMilliseconds(RetryContext retryContext);
}

abstract class RetryContext {
  /// The number of consecutive failed tries so far.
  int get previousRetryCount;

  /// The amount of time in milliseconds spent retrying so far.
  int get elapsedMilliseconds;

  /// The exception that forced the upcoming retry.
  Exception get retryReason;

  factory RetryContext(int previousRetryCount, int elapsedMilliseconds,
          Exception retryReason) =>
      _RetryContext(previousRetryCount, elapsedMilliseconds, retryReason);
}

class _RetryContext implements RetryContext {
  @override
  final int previousRetryCount;
  @override
  final int elapsedMilliseconds;
  @override
  final Exception retryReason;

  _RetryContext(
      this.previousRetryCount, this.elapsedMilliseconds, this.retryReason);
}
