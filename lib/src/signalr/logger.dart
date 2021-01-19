/// An abstraction that provides a sink for diagnostic messages.
abstract class Logger {
  /// Called by the framework to emit a diagnostic message.
  ///
  /// [logLevel] The severity level of the message.
  ///
  /// [message] The message.
  void log(LogLevel logLevel, String message);
}

/// A logger that does nothing when log messages are sent to it.
class NullLogger implements Logger {
  static final _instance = NullLogger._();

  NullLogger._();

  /// The singleton instance of the [NullLogger].
  factory NullLogger() => _instance;

  @override
  void log(LogLevel logLevel, String message) {}
}

/// Indicates the severity of a log message.
///
/// Log Levels are ordered in increasing severity. So `debug` is more severe than `trace`, etc.
enum LogLevel {
  /// Log level for very low severity diagnostic messages.
  trace,

  /// Log level for low severity diagnostic messages.
  debug,

  /// Log level for informational diagnostic messages.
  information,

  /// Log level for diagnostic messages that indicate a non-fatal problem.
  warning,

  /// Log level for diagnostic messages that indicate a failure in the current operation.
  error,

  /// Log level for diagnostic messages that indicate a failure that will terminate the entire application.
  critical,

  /// The highest possible log level. Used when configuring logging to indicate that no log messages should be emitted.
  none,
}
