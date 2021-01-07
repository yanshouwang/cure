/// Exception thrown when an HTTP request fails.
class HttpException implements Exception {
  /// A descriptive exception message.
  final String message;

  /// The HTTP status code represented by this exception.
  final int statusCode;

  /// Constructs a new instance of [HttpException].
  HttpException(this.message, this.statusCode);

  @override
  String toString() {
    return 'HttpException: $message\nstatusCode: $statusCode';
  }
}

/// Exception thrown when a timeout elapses.
class TimeoutException implements Exception {
  /// A descriptive exception message.
  final String message;

  /// Constructs a new instance of [TimeoutException].
  TimeoutException() : message = 'A timeout occurred.';

  @override
  String toString() {
    return 'TimeoutException: $message';
  }
}

/// Exception thrown when an action is aborted.
class AbortException implements Exception {
  /// A descriptive exception message.
  final String message;

  /// Constructs a new instance of [AbortException].
  AbortException() : message = 'An abort occurred.';

  @override
  String toString() {
    return 'AbortException: $message';
  }
}
