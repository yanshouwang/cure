import 'default_reconnect_policy.dart';
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
  HubProtocol get protocol;
  HttpConnectionOptions get httpConnectionOptions;
  String get url;
  Logger get logger;
  RetryPolicy get reconnectPolicy;

  /// Configures console logging for the [HubConnection].
  ///
  /// [logging] A [LogLevel], a string representing a [LogLevel], or an object implementing the [Logger] interface. See [the documentation for client logging configuration](https://docs.microsoft.com/aspnet/core/signalr/configuration#configure-logging) for more details.
  ///
  /// Returns the [HubConnectionBuilder] instance, for chaining.
  HubConnectionBuilder configureLogging(Object logging);

  /// Configures the [HubConnection] to use HTTP-based transports to connect to the specified URL.
  ///
  /// [url] The URL the connection will use.
  ///
  /// [transportTypeOrOptions] The specific transport to use or an options object used to configure the connection.
  ///
  /// Returns the [HubConnectionBuilder] instance, for chaining.
  HubConnectionBuilder withURL(String url, [Object transportTypeOrOptions]);

  /// Configures the [HubConnection] to use the specified Hub Protocol.
  ///
  /// [protocol] The [HubProtocol] implementation to use.
  ///
  /// Returns the [HubConnectionBuilder] instance, for chaining.
  HubConnectionBuilder withHubProtocol(HubProtocol protocol);

  /// Configures the [HubConnection] to automatically attempt to reconnect if the connection is lost.
  ///
  /// [retryDelaysOrReconnectPolicy] An array containing the delays in milliseconds before trying each reconnect attempt or a [RetryPolicy] that controls the timing and number of reconnect attempts.
  ///
  /// * The length of the array represents how many failed reconnect attempts it takes before the client will stop attempting to reconnect
  ///
  /// Returns the [HubConnectionBuilder] instance, for chaining.
  HubConnectionBuilder withAutomaticReconnect(
      [Object retryDelaysOrReconnectPolicy]);

  /// Creates a [HubConnection] from the configuration options specified in this builder.
  ///
  /// Returns the configured [HubConnection].
  HubConnection build();

  factory HubConnectionBuilder() => _HubConnectionBuilder();
}

class _HubConnectionBuilder implements HubConnectionBuilder {
  @override
  HubProtocol protocol;
  @override
  HttpConnectionOptions httpConnectionOptions;
  @override
  String url;
  @override
  Logger logger;
  @override
  RetryPolicy reconnectPolicy;

  @override
  HubConnectionBuilder configureLogging(Object logging) {
    Arg.isRequired(logging, 'logging');

    if (logging is Logger) {
      logger = logging;
    } else {
      logger = ConsoleLogger(logging);
    }

    return this;
  }

  @override
  HubConnectionBuilder withURL(String url, [Object transportTypeOrOptions]) {
    Arg.isRequired(url, 'url');
    Arg.isNotEmpty(url, 'url');

    this.url = url;

    // Flow-typing knows where it's at. Since HttpTransportType is a number and HttpConnectionOptions is guaranteed
    // to be an object, we know (as does TypeScript) this comparison is all we need to figure out which overload was called.
    if (transportTypeOrOptions is HttpConnectionOptions) {
      httpConnectionOptions = transportTypeOrOptions;
    } else {
      httpConnectionOptions ??=
          HttpConnectionOptions(transport: transportTypeOrOptions);
    }

    return this;
  }

  @override
  HubConnectionBuilder withHubProtocol(HubProtocol protocol) {
    Arg.isRequired(protocol, 'protocol');

    this.protocol = protocol;
    return this;
  }

  @override
  HubConnectionBuilder withAutomaticReconnect(
      [Object retryDelaysOrReconnectPolicy]) {
    if (reconnectPolicy != null) {
      throw Exception('A reconnectPolicy has already been set.');
    }

    if (retryDelaysOrReconnectPolicy == null) {
      reconnectPolicy = DefaultReconnectPolicy();
    } else if (retryDelaysOrReconnectPolicy is List<int>) {
      reconnectPolicy = DefaultReconnectPolicy(retryDelaysOrReconnectPolicy);
    } else {
      reconnectPolicy = retryDelaysOrReconnectPolicy;
    }

    return this;
  }

  @override
  HubConnection build() {
    // If HttpConnectionOptions has a logger, use it. Otherwise, override it with the one
    // provided to configureLogger
    final httpConnectionOptions =
        this.httpConnectionOptions ?? HttpConnectionOptions();

    // If it's 'null', the user **explicitly** asked for null, don't mess with it.
    // If our logger is undefined or null, that's OK, the HttpConnection constructor will handle it.
    httpConnectionOptions.logger ??= logger;

    // Now create the connection
    if (url == null) {
      throw Exception(
          "The 'HubConnectionBuilder.withUrl' method must be called before building the connection.");
    }
    final connection = HttpConnection(url, httpConnectionOptions);

    return HubConnection.create(connection, logger ?? NullLogger(),
        protocol ?? JsonHubProtocol(), reconnectPolicy);
  }
}
