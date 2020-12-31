import 'dart:async';
import 'dart:typed_data';

import 'package:cure/serialization.dart';
import 'package:cure/sse.dart';
import 'package:cure/ws.dart';

import 'connection.dart';
import 'default_http_client.dart';
import 'http_client.dart';
import 'http_connection_options.dart';
import 'http_connection_stub.dart'
    if (dart.library.html) 'http_connection_html.dart'
    if (dart.library.io) 'http_connection_io.dart';
import 'logger.dart';
import 'long_polling_transport.dart';
import 'server_sent_events_transport.dart';
import 'transport.dart';
import 'utils.dart';
import 'web_socket_transport.dart';

const MAX_REDIRECTS = 100;

class HTTPConnection implements Connection {
  HTTPClient _httpClient;
  Logger _logger;
  HTTPConnectionOptions _options;
  final int _negotiateVersion;

  ConnectionState _connectionState;
  bool _connectionStarted;
  // Can't be private for test.
  Transport transport;
  Future<void> _startInternalFuture;
  Future<void> _stopFuture;
  Completer<void> _stopCompleter;
  Exception _stopError;
  dynamic Function() _accessTokenFactory;
  TransportSendQueue _sendQueue;

  @override
  final Map<String, dynamic> features;
  @override
  String baseURL;
  @override
  String connectionId;
  @override
  void Function(dynamic data) onreceive;
  @override
  void Function(Exception error) onclose;

  HTTPConnection(String url, [HTTPConnectionOptions options])
      : _negotiateVersion = 1,
        features = {} {
    Arg.isRequired(url, 'url');

    options ??= HTTPConnectionOptions();
    _logger = createLogger(options.logger);
    baseURL = _resolveUrl(url);

    options.logMessageContent ??= false;
    options.withCredentials ??= true;
    options.webSocket ??= (url, {protocols, headers}) =>
        WebSocket.connect(url, protocols: protocols, headers: headers);
    options.eventSource ??= (url, {headers, withCredentials}) =>
        EventSource.connect(url,
            headers: headers, withCredentials: withCredentials);

    _httpClient = options.httpClient ?? DefaultHTTPClient(_logger);
    _connectionState = ConnectionState.disconnected;
    _connectionStarted = false;
    _options = options;

    onreceive = null;
    onclose = null;
  }

  String _resolveUrl(String url) {
    if (url.startsWith('https://', 0) || url.startsWith('http://', 0)) {
      return url;
    }
    return resolveUrl(url, _logger);
  }

  @override
  Future<void> sendAsync(dynamic data) {
    if (_connectionState != ConnectionState.connected) {
      final error = Exception(
          "Cannot send data if the connection is not in the 'Connected' State.");
      return Future.error(error);
    }

    _sendQueue ??= TransportSendQueue(transport);

    // Transport will not be null if state is connected
    return _sendQueue.sendAsync(data);
  }

  @override
  Future<void> startAsync([TransferFormat transferFormat]) async {
    transferFormat ??= TransferFormat.binary;

    _logger.log(LogLevel.debug,
        "Starting connection with transfer format '$transferFormat'.");

    if (_connectionState != ConnectionState.disconnected) {
      final error = Exception(
          "Cannot start an HttpConnection that is not in the 'disconnected' state.");
      return Future.error(error);
    }

    _connectionState = ConnectionState.connecting;

    _startInternalFuture = _startInternalAsync(transferFormat);
    await _startInternalFuture;

    // The TypeScript compiler thinks that connectionState must be Connecting here. The TypeScript compiler is wrong.
    if (_connectionState == ConnectionState.disconnecting) {
      // stop() was called and transitioned the client into the Disconnecting state.
      final message =
          'Failed to start the HttpConnection before stop() was called.';
      _logger.log(LogLevel.error, message);

      // We cannot await stopPromise inside startInternal since stopInternal awaits the startInternalPromise.
      await _stopFuture;

      final error = Exception(message);
      return Future.error(error);
    } else if (_connectionState != ConnectionState.connected) {
      // stop() was called and transitioned the client into the Disconnecting state.
      final message =
          "HttpConnection.startInternal completed gracefully but didn't enter the connection into the connected state!";
      _logger.log(LogLevel.error, message);
      final error = Exception(message);
      return Future.error(error);
    }

    _connectionStarted = true;
  }

  @override
  Future<void> stopAsync([Exception error]) async {
    if (_connectionState == ConnectionState.disconnected) {
      _logger.log(LogLevel.debug,
          'Call to HttpConnection.stop($error) ignored because the connection is already in the disconnected state.');
      return Future.value();
    }

    if (_connectionState == ConnectionState.disconnecting) {
      _logger.log(LogLevel.debug,
          'Call to HttpConnection.stop($error) ignored because the connection is already in the disconnecting state.');
      return _stopFuture;
    }

    _connectionState = ConnectionState.disconnecting;

    _stopCompleter = Completer();
    _stopFuture = _stopCompleter.future;

    // stopInternal should never throw so just observe it.
    await _stopInternalAsync(error);
    await _stopFuture;
  }

  Future<void> _startInternalAsync(TransferFormat transferFormat) async {
    // Store the original base url and the access token factory since they may change
    // as part of negotiating
    var url = baseURL;
    _accessTokenFactory = _options.accessTokenFactory;

    try {
      if (_options.skipNegotiation == true) {
        if (_options.transport == HTTPTransportType.webSockets) {
          // No need to add a connection ID in this case
          transport = _constructTransport(HTTPTransportType.webSockets);
          // We should just call connect directly in this case.
          // No fallback or negotiate in this case.
          await _startTransportAsync(url, transferFormat);
        } else {
          throw Exception(
              'Negotiation can only be skipped when using the WebSocket transport directly.');
        }
      } else {
        NegotiateResponse negotiateResponse;
        var redirects = 0;

        do {
          negotiateResponse = await _getNegotiationResponseAsync(url);
          // the user tries to stop the connection when it is being started
          if (_connectionState == ConnectionState.disconnecting ||
              _connectionState == ConnectionState.disconnected) {
            throw Exception('The connection was stopped during negotiation.');
          }

          if (negotiateResponse.error != null) {
            throw Exception(negotiateResponse.error);
          }

          if (negotiateResponse.protocolVersion != null) {
            throw Exception(
                'Detected a connection attempt to an ASP.NET Signalr Server. This client only supports connecting to an ASP.NET Core Signalr Server. See https://aka.ms/signalr-core-differences for details.');
          }

          if (negotiateResponse.url != null) {
            url = negotiateResponse.url;
          }

          if (negotiateResponse.accessToken != null) {
            // Replace the current access token factory with one that uses
            // the returned access token
            final accessToken = negotiateResponse.accessToken;
            _accessTokenFactory = () => Future.value(accessToken);
          }

          redirects++;
        } while (negotiateResponse.url != null && redirects < MAX_REDIRECTS);

        if (redirects == MAX_REDIRECTS && negotiateResponse.url != null) {
          throw Exception('Negotiate redirection limit exceeded.');
        }

        await _createTransportAsync(
            url, _options.transport, negotiateResponse, transferFormat);
      }

      if (transport is LongPollingTransport) {
        features['inherentKeepAlive'] = true;
      }

      if (_connectionState == ConnectionState.connecting) {
        // Ensure the connection transitions to the connected state prior to completing this.startInternalPromise.
        // start() will handle the case when stop was called and startInternal exits still in the disconnecting state.
        _logger.log(
            LogLevel.debug, 'The HTTPConnection connected successfully.');
        _connectionState = ConnectionState.connected;
      }

      // stop() is waiting on us via this.startInternalPromise so keep this.transport around so it can clean up.
      // This is the only case startInternal can exit in neither the connected nor disconnected state because stopConnection()
      // will transition to the disconnected state. start() will wait for the transition using the stopPromise.
    } catch (e) {
      _logger.log(LogLevel.error, 'Failed to start the connection: $e');
      _connectionState = ConnectionState.disconnected;
      transport = null;
      return Future.error(e);
    }
  }

  Future<void> _stopInternalAsync(Exception error) async {
    // Set error as soon as possible otherwise there is a race between
    // the transport closing and providing an error and the error from a close message
    // We would prefer the close message error.
    _stopError = error;

    try {
      await _startInternalFuture;
    } catch (e) {
      // This exception is returned to the user as a rejected Promise from the start method.
    }

    // The transport's onclose will trigger stopConnection which will run our onclose event.
    // The transport should always be set if currently connected. If it wasn't set, it's likely because
    // stop was called during start() and start() failed.
    if (transport != null) {
      try {
        await transport.stopAsync();
      } catch (e) {
        _logger.log(LogLevel.error,
            "HttpConnection.transport.stop() threw error '$e'.");
        _stopConnection();
      }

      transport = null;
    } else {
      _logger.log(LogLevel.debug,
          'HttpConnection.transport is null in HttpConnection.stop() because start() failed.');
      _stopConnection();
    }
  }

  void _stopConnection([Exception error]) {
    _logger.log(LogLevel.debug,
        'HttpConnection.stopConnection($error) called while in state $_connectionState.');

    transport = null;

    // If we have a stopError, it takes precedence over the error from the transport
    error = _stopError ?? error;
    _stopError = null;

    if (_connectionState == ConnectionState.disconnected) {
      _logger.log(LogLevel.debug,
          'Call to HttpConnection.stopConnection($error) was ignored because the connection is already in the disconnected state.');
      return;
    }

    if (_connectionState == ConnectionState.connecting) {
      _logger.log(LogLevel.warning,
          'Call to HttpConnection.stopConnection($error) was ignored because the connection is still in the connecting state.');
      throw Exception(
          'HttpConnection.stopConnection($error) was called while the connection is still in the connecting state.');
    }

    if (_connectionState == ConnectionState.disconnecting) {
      // A call to stop() induced this call to stopConnection and needs to be completed.
      // Any stop() awaiters will be scheduled to continue after the onclose callback fires.
      _stopCompleter.complete();
    }

    if (error != null) {
      _logger.log(
          LogLevel.error, "Connection disconnected with error '$error'.");
    } else {
      _logger.log(LogLevel.information, 'Connection disconnected.');
    }

    if (_sendQueue != null) {
      _sendQueue.stopAsync().catchError((e) => _logger.log(
          LogLevel.error, "TransportSendQueue.stopAsync() threw error '$e'."));
      _sendQueue = null;
    }

    connectionId = null;
    _connectionState = ConnectionState.disconnected;

    if (_connectionStarted == true) {
      _connectionStarted = false;
      try {
        onclose?.call(error);
      } catch (e) {
        _logger.log(LogLevel.error,
            'HttpConnection.onclose($error) threw error `${e}`.');
      }
    }
  }

  Transport _constructTransport(HTTPTransportType transport) {
    if (transport == HTTPTransportType.webSockets) {
      if (_options.webSocket == null) {
        throw Exception("'WebSocket' is not supported in your environment.");
      }
      return WebSocketTransport(
          _httpClient,
          _accessTokenFactory,
          _logger,
          _options.logMessageContent ?? false,
          _options.webSocket,
          _options.headers ?? {});
    } else if (transport == HTTPTransportType.serverSentEvents) {
      if (_options.eventSource == null) {
        throw Exception("'EventSource' is not supported in your environment.");
      }
      return ServerSentEventsTransport(
          _httpClient,
          _accessTokenFactory,
          _logger,
          _options.logMessageContent ?? false,
          _options.eventSource,
          _options.withCredentials,
          _options.headers ?? {});
    } else if (transport == HTTPTransportType.longPolling) {
      return LongPollingTransport(
          _httpClient,
          _accessTokenFactory,
          _logger,
          _options.logMessageContent ?? false,
          _options.withCredentials,
          _options.headers ?? {});
    } else {
      throw Exception('Unknown transport: $transport.');
    }
  }

  Future<void> _startTransportAsync(String url, TransferFormat transferFormat) {
    transport.onreceive = onreceive;
    transport.onclose = (e) => _stopConnection(e);
    return transport.connectAsync(url, transferFormat);
  }

  Future<NegotiateResponse> _getNegotiationResponseAsync(String url) async {
    final headers = <String, String>{};
    if (_accessTokenFactory != null) {
      final token = await _accessTokenFactory();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final userAgentHeader = getUserAgentHeader();
    headers[userAgentHeader.key] = userAgentHeader.value;

    if (_options.headers != null) {
      for (var header in _options.headers.entries) {
        headers[header.key] = header.value;
      }
    }

    final negotiateURL = _resolveNegotiateURL(url);
    _logger.log(LogLevel.debug, 'Sending negotiation request: $negotiateURL.');
    try {
      final options = HTTPRequest(
          content: '',
          headers: headers,
          withCredentials: _options.withCredentials);
      final response = await _httpClient.postAsync(negotiateURL, options);

      if (response.statusCode != 200) {
        final error = Exception(
            "Unexpected status code returned from negotiate '${response.statusCode}'");
        return Future.error(error);
      }

      var obj = JSON.fromJSON(response.content);
      var negotiateResponse = NegotiateResponse.fromJSON(obj);
      if (negotiateResponse.negotiateVersion == null ||
          negotiateResponse.negotiateVersion < 1) {
        // Negotiate version 0 doesn't use connectionToken
        // So we set it equal to connectionId so all our logic can use connectionToken without being aware of the negotiate version
        //negotiateResponse.connectionToken = negotiateResponse.connectionId;
        obj['connectionToken'] = negotiateResponse.connectionId;
        negotiateResponse = NegotiateResponse.fromJSON(obj);
      }
      return negotiateResponse;
    } catch (e) {
      _logger.log(
          LogLevel.error, 'Failed to complete negotiation with the server: $e');
      return Future.error(e);
    }
  }

  Future<void> _createTransportAsync(
      String url,
      dynamic transport,
      NegotiateResponse negotiateResponse,
      TransferFormat transferFormat) async {
    var connectURL = _createConnectURL(url, negotiateResponse.connectionToken);
    if (transport is Transport) {
      _logger.log(LogLevel.debug,
          'Connection was provided an instance of Transport, using that directly.');
      this.transport = transport;
      await _startTransportAsync(connectURL, transferFormat);

      connectionId = negotiateResponse.connectionId;
      return;
    }

    final transportExceptions = [];
    final transports = negotiateResponse.availableTransports ?? [];
    var negotiate = negotiateResponse;
    for (final endpoint in transports) {
      final transportOrError =
          _resolveTransportOrError(endpoint, transport, transferFormat);
      if (transportOrError is Exception) {
        // Store the error and continue, we don't want to cause a re-negotiate in these cases
        transportExceptions
            .add('${endpoint.transport} failed: $transportOrError');
      } else if (transportOrError is Transport) {
        this.transport = transportOrError;
        if (negotiate == null) {
          try {
            negotiate = await _getNegotiationResponseAsync(url);
          } catch (e) {
            return Future.error(e);
          }
          connectURL = _createConnectURL(url, negotiate.connectionToken);
        }
        try {
          await _startTransportAsync(connectURL, transferFormat);
          connectionId = negotiate.connectionId;
          return;
        } catch (ex) {
          _logger.log(LogLevel.error,
              "Failed to start the transport '${endpoint.transport}': $ex");
          negotiate = null;
          transportExceptions.add('${endpoint.transport} failed: $ex');

          if (_connectionState != ConnectionState.connecting) {
            final message =
                'Failed to select transport before stop() was called.';
            _logger.log(LogLevel.debug, message);
            final error = Exception(message);
            return Future.error(error);
          }
        }
      }
    }

    final error = transportExceptions.isNotEmpty
        ? Exception(
            'Unable to connect to the server with any of the available transports. ${transportExceptions.join(" ")}')
        : Exception(
            'None of the transports supported by the client are supported by the server.');
    return Future.error(error);
  }

  String _resolveNegotiateURL(String url) {
    final index = url.indexOf('?');
    var negotiateUrl = url.substring(0, index == -1 ? url.length : index);
    if (negotiateUrl[negotiateUrl.length - 1] != '/') {
      negotiateUrl += '/';
    }
    negotiateUrl += 'negotiate';
    negotiateUrl += index == -1 ? '' : url.substring(index);

    if (!negotiateUrl.contains('negotiateVersion')) {
      negotiateUrl += index == -1 ? '?' : '&';
      negotiateUrl += 'negotiateVersion=$_negotiateVersion';
    }
    return negotiateUrl;
  }

  String _createConnectURL(String url, String connectionToken) {
    if (connectionToken == null) {
      return url;
    }

    return url + (url.contains('?') ? '&' : '?') + 'id=$connectionToken';
  }

  dynamic _resolveTransportOrError(AvailableTransport endpoint,
      dynamic requestedTransport, TransferFormat requestedTransferFormat) {
    final transport = endpoint.transport;
    if (transport == null) {
      _logger.log(LogLevel.debug,
          "Skipping transport '${endpoint.transport}' because it is not supported by this client.");
      return Exception(
          "Skipping transport '${endpoint.transport}' because it is not supported by this client.");
    } else {
      if (_transportMatches(requestedTransport, transport)) {
        final transferFormats = endpoint.transferFormats;
        if (transferFormats.contains(requestedTransferFormat)) {
          if ((transport == HTTPTransportType.webSockets &&
                  _options.webSocket == null) ||
              (transport == HTTPTransportType.serverSentEvents &&
                  _options.eventSource == null)) {
            _logger.log(LogLevel.debug,
                "Skipping transport '$transport' because it is not supported in your environment.");
            return Exception(
                "'$transport' is not supported in your environment.");
          } else {
            _logger.log(LogLevel.debug, "Selecting transport '$transport'.");
            try {
              return _constructTransport(transport);
            } catch (e) {
              return e;
            }
          }
        } else {
          _logger.log(LogLevel.debug,
              "Skipping transport '$transport' because it does not support the requested transfer format '$requestedTransferFormat'.");
          return Exception(
              "'$transport' does not support $requestedTransferFormat.");
        }
      } else {
        _logger.log(LogLevel.debug,
            "Skipping transport '$transport' because it was disabled by the client.");
        return Exception("'$transport' is disabled by the client.");
      }
    }
  }

  bool _transportMatches(
      dynamic requestedTransport, HTTPTransportType actualTransport) {
    final value = requestedTransport is HTTPTransportType
        ? (requestedTransport.toJSON())
        : requestedTransport;
    return value == null ||
        value == HTTPTransportType.none.toJSON() ||
        ((actualTransport.toJSON() & value) != 0);
  }
}

abstract class TransportSendQueue {
  Future<void> sendAsync(dynamic data);
  Future<void> stopAsync();

  factory TransportSendQueue(Transport transport) =>
      _TransportSendQueue(transport);
}

class _TransportSendQueue implements TransportSendQueue {
  final Transport _transport;
  final List<dynamic> _buffer;
  Completer<void> _sendBufferedData;
  bool _executing;
  Completer<void> _transportResult;
  Future<void> _sendLoopFuture;

  _TransportSendQueue(this._transport)
      : _buffer = [],
        _executing = true,
        _sendBufferedData = Completer(),
        _transportResult = Completer() {
    _sendLoopFuture = _sendLoopAsync();
  }

  @override
  Future<void> sendAsync(dynamic data) {
    _bufferData(data);
    _transportResult ??= Completer();
    return _transportResult.future;
  }

  void _bufferData(dynamic data) {
    if (_buffer.isNotEmpty && _buffer[0].runtimeType != data.runtimeType) {
      throw Exception(
          'Expected data to be of type ${_buffer[0].runtimeType} but was of type ${data.runtimeType}');
    }
    _buffer.add(data);
    // Called twice will throw an unexpected exception.
    if (!_sendBufferedData.isCompleted) {
      _sendBufferedData.complete();
    }
  }

  @override
  Future<void> stopAsync() {
    _executing = false;
    // Called twice will throw an unexpected exception.
    if (!_sendBufferedData.isCompleted) {
      _sendBufferedData.complete();
    }
    return _sendLoopFuture;
  }

  Future<void> _sendLoopAsync() async {
    while (true) {
      await _sendBufferedData.future;

      if (!_executing) {
        final error = Exception('Connection stopped.');
        _transportResult?.completeError(error);
        break;
      }

      _sendBufferedData = Completer();

      final transportResult = _transportResult;
      _transportResult = null;

      final data = _buffer[0] is String
          ? _buffer.join('')
          : _TransportSendQueue._concatBuffers(_buffer.cast<ByteBuffer>());

      _buffer.clear();

      try {
        await _transport.sendAsync(data);
        transportResult.complete();
      } catch (e) {
        transportResult.completeError(e);
      }
    }
  }

  static ByteBuffer _concatBuffers(List<ByteBuffer> arrayBuffers) {
    final totalLength =
        arrayBuffers.map((b) => b.lengthInBytes).reduce((a, b) => a + b);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final item in arrayBuffers) {
      result.setAll(offset, item.asUint8List());
      offset += item.lengthInBytes;
    }

    return result.buffer;
  }
}

abstract class NegotiateResponse {
  String get connectionId;
  String get connectionToken;
  int get negotiateVersion;
  List<AvailableTransport> get availableTransports;
  String get url;
  String get accessToken;
  String get error;
  String get protocolVersion;

  Map<String, dynamic> toJSON();

  factory NegotiateResponse(
      {String connectionId,
      String connectionToken,
      int negotiateVersion,
      List<AvailableTransport> availableTransports,
      String url,
      String accessToken,
      String error,
      String protocolVersion}) {
    return _NegotiateResponse(connectionId, connectionToken, negotiateVersion,
        availableTransports, url, accessToken, error, protocolVersion);
  }

  factory NegotiateResponse.fromJSON(Map<String, dynamic> obj) {
    final connectionId = obj['connectionId'] as String;
    final connectionToken = obj['connectionToken'] as String;
    final negotiateVersion = obj['negotiateVersion'] as int;
    final availableTransports = (obj['availableTransports'] as List<dynamic>)
        ?.map((e) => AvailableTransport.fromJSON(e as Map<String, dynamic>))
        ?.toList();
    final url = obj['url'] as String;
    final accessToken = obj['accessToken'] as String;
    final error = obj['error'] as String;
    final protocolVersion = obj['ProtocolVersion'] as String;
    return _NegotiateResponse(connectionId, connectionToken, negotiateVersion,
        availableTransports, url, accessToken, error, protocolVersion);
  }
}

class _NegotiateResponse implements NegotiateResponse {
  @override
  final String connectionId;
  @override
  final String connectionToken;
  @override
  final int negotiateVersion;
  @override
  final List<AvailableTransport> availableTransports;
  @override
  final String url;
  @override
  final String accessToken;
  @override
  final String error;
  @override
  final String protocolVersion;

  _NegotiateResponse(
      this.connectionId,
      this.connectionToken,
      this.negotiateVersion,
      this.availableTransports,
      this.url,
      this.accessToken,
      this.error,
      this.protocolVersion);

  @override
  Map<String, dynamic> toJSON() {
    var obj = <String, dynamic>{};
    obj.writeNotNull('connectionId', connectionId);
    obj.writeNotNull('connectionToken', connectionToken);
    obj.writeNotNull('negotiateVersion', negotiateVersion);
    obj.writeNotNull('availableTransports', availableTransports);
    obj.writeNotNull('url', url);
    obj.writeNotNull('accessToken', accessToken);
    obj.writeNotNull('error', error);
    obj.writeNotNull('ProtocolVersion', protocolVersion);
    return obj;
  }
}

abstract class AvailableTransport {
  HTTPTransportType get transport;
  List<TransferFormat> get transferFormats;

  Map<String, dynamic> toJSON();

  factory AvailableTransport(
      HTTPTransportType transport, List<TransferFormat> transferFormats) {
    return _AvailableTransport(transport, transferFormats);
  }

  factory AvailableTransport.fromJSON(Map<String, dynamic> obj) {
    final transport = HTTPTransportType.fromJSON(obj['transport'] as int);
    final transferFormats = (obj['transferFormats'] as List<dynamic>)
        .map((e) => TransferFormat.fromJSON(e as int))
        .toList();
    return _AvailableTransport(transport, transferFormats);
  }
}

class _AvailableTransport implements AvailableTransport {
  @override
  final HTTPTransportType transport;
  @override
  final List<TransferFormat> transferFormats;

  _AvailableTransport(this.transport, this.transferFormats);

  @override
  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{
      'transport': transport,
      'transferFormats': transferFormats,
    };
    return obj;
  }
}

abstract class ConnectionState {
  String get name;

  static const ConnectionState connecting = _ConnectionState('Connecting');
  static const ConnectionState connected = _ConnectionState('Connected');
  static const ConnectionState disconnected = _ConnectionState('Disconnected');
  static const ConnectionState disconnecting =
      _ConnectionState('Disconnecting');
}

class _ConnectionState implements ConnectionState {
  @override
  final String name;

  const _ConnectionState(this.name);

  @override
  String toString() {
    return name;
  }
}
