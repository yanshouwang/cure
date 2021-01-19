import 'package:cure/signalr.dart';
import 'package:cure/src/signalr/transport.dart';
import 'package:meta/meta.dart';

import 'http_connection.dart';
import 'http_connection_options.dart';
import 'hub_connection.dart';
import 'hub_protocol.dart';
import 'json_hub_protocol.dart';
import 'logger.dart';
import 'retry_policy.dart';
import 'utils.dart';

/// A builder for configuring [HubConnection] instances.
abstract class HubConnectionBuilder {
  @visibleForTesting
  String? get $url;
  @visibleForTesting
  HttpConnectionOptions? get $httpConnectionOptions;
  @visibleForTesting
  Logger? get $logger;
  @visibleForTesting
  HubProtocol? get $protocol;
  @visibleForTesting
  RetryPolicy? get $reconnectPolicy;

  /// The URL the connection will use.
  set url(String value);

  /// The specific transport to use.
  set transportType(HttpTransportType value);

  /// An options object used to configure the connection.
  set httpConnectionOptions(HttpConnectionOptions value);

  /// The minimum level of messages to log. Anything at this level, or a more severe level, will be logged.
  set logLevel(LogLevel value);

  /// An object implementing the [Logger] interface, which will be used to write all log messages.
  set logger(Logger value);

  /// The [HubProtocol] implementation to use.
  set protocol(HubProtocol value);

  /// Configures the HubConnection to automatically attempt to reconnect if the connection is lost.
  /// By default, the client will wait 0, 2, 10 and 30 seconds respectively before trying up to 4
  /// reconnect attempts.
  ///
  /// When [reconnectDelays] or [reconnectPolicy] was set, set this to true is unnecessary.
  ///
  /// Must called after [reconnectDelays] and [reconnectPolicy] when set to false.
  set reconnect(bool value);

  /// An array containing the delays in milliseconds before trying each reconnect attempt.
  /// The length of the array represents how many failed reconnect attempts it takes before
  /// the client will stop attempting to reconnect.
  set reconnectDelays(List<int> value);

  /// An [RetryPolicy] that controls the timing and number of reconnect attempts.
  set reconnectPolicy(RetryPolicy value);

  /// Creates a [HubConnection] from the configuration options specified in this builder.
  ///
  /// Returns the configured [HubConnection].
  HubConnection build();

  factory HubConnectionBuilder() => _HubConnectionBuilder();
}

class _HubConnectionBuilder implements HubConnectionBuilder {
  String? _url;
  HttpConnectionOptions? _httpConnectionOptions;
  Logger? _logger;
  HubProtocol? _protocol;
  RetryPolicy? _reconnectPolicy;

  @override
  String? get $url => _url;
  @override
  HttpConnectionOptions? get $httpConnectionOptions => _httpConnectionOptions;
  @override
  Logger? get $logger => _logger;
  @override
  HubProtocol? get $protocol => _protocol;
  @override
  RetryPolicy? get $reconnectPolicy => _reconnectPolicy;

  @override
  set url(String value) {
    Arg.isNotEmpty(value, 'url');

    _url = value;
  }

  @override
  set transportType(HttpTransportType value) {
    _httpConnectionOptions = HttpConnectionOptions(transport: value);
  }

  @override
  set httpConnectionOptions(HttpConnectionOptions value) {
    _httpConnectionOptions = value;
  }

  @override
  set logLevel(LogLevel value) {
    _logger = ConsoleLogger(value);
  }

  @override
  set logger(Logger value) {
    _logger = value;
  }

  @override
  set protocol(HubProtocol value) {
    _protocol = value;
  }

  @override
  set reconnect(bool value) {
    if (value) {
      _reconnectPolicy ??= RetryPolicy();
    } else {
      _reconnectPolicy = null;
    }
  }

  @override
  set reconnectDelays(List<int> value) {
    _reconnectPolicy = RetryPolicy(value);
  }

  @override
  set reconnectPolicy(RetryPolicy value) {
    _reconnectPolicy = value;
  }

  @override
  HubConnection build() {
    // If HttpConnectionOptions has a logger, use it. Otherwise, override it with the one
    // provided to configureLogger
    final httpConnectionOptions =
        _httpConnectionOptions ?? HttpConnectionOptions();

    // If it's 'null', the user **explicitly** asked for null, don't mess with it.
    // If our logger is undefined or null, that's OK, the HttpConnection constructor will handle it.
    httpConnectionOptions.logger ??= _logger;

    // Now create the connection
    if (_url == null) {
      throw Exception("The 'url' must be set before building the connection.");
    }

    final connection = HttpConnection(_url!, httpConnectionOptions);
    final logger = _logger ?? NullLogger();
    final protocol = _protocol ?? JsonHubProtocol();

    return HubConnection.create(connection, logger, protocol, _reconnectPolicy);
  }
}
