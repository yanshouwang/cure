import 'dart:async';

import 'package:pedantic/pedantic.dart';

import 'connection.dart';
import 'handshake_protocol.dart';
import 'hub_protocol.dart';
import 'logger.dart';
import 'retry_policy.dart';
import 'stream.dart';
import 'subject.dart';
import 'utils.dart';

const DEFAULT_TIMEOUT_IN_MS = 30 * 1000;
const DEFAULT_PING_INTERVAL_IN_MS = 15 * 1000;

/// Represents a connection to a Signalr Hub.
abstract class HubConnection {
  /// The server timeout in milliseconds.
  ///
  /// If this timeout elapses without receiving any messages from the server, the connection will be terminated with an error.
  ///
  /// The default timeout value is 30,000 milliseconds (30 seconds).
  int serverTimeoutInMilliseconds;

  /// Default interval at which to ping the server.
  ///
  /// The default value is 15,000 milliseconds (15 seconds).
  ///
  /// Allows the server to detect hard disconnects (like when a client unplugs their computer).
  int keepAliveIntervalInMilliseconds;

  /// Indicates the state of the [HubConnection] to the server.
  HubConnectionState get state;

  /// Represents the connection id of the [HubConnection] on the server. The connection id will be null when the connection is either in the disconnected state or if the negotiation step was skipped.
  String get connectionId;

  /// Indicates the url of the [HubConnection] to the server.
  String baseURL;

  /// Starts the connection.
  ///
  /// Returns a [Future] that resolves when the connection has been successfully established, or rejects with an error.
  Future<void> startAsync();

  /// Stops the connection.
  ///
  /// Returns a [Future] that resolves when the connection has been successfully terminated, or rejects with an error.
  Future<void> stopAsync();

  /// Invokes a streaming hub method on the server using the specified name and arguments.
  ///
  /// [T] The type of the items returned by the server.
  ///
  /// [methodName] The name of the server method to invoke.
  ///
  /// [args] The arguments used to invoke the server method.
  ///
  /// Returns an object that yields results from the server as they are received.
  StreamResult<T> stream<T>(String methodName, [List<dynamic> args]);

  /// Invokes a hub method on the server using the specified name and arguments. Does not wait for a response from the receiver.
  ///
  /// The [Future] returned by this method resolves when the client has sent the invocation to the server. The server may still
  /// be processing the invocation.
  ///
  /// [methodName] The name of the server method to invoke.
  ///
  /// [args] The arguments used to invoke the server method.
  ///
  /// Returns a [Future] that resolves when the invocation has been successfully sent, or rejects with an error.
  Future<void> sendAsync(String methodName, [List<dynamic> args]);

  /// Invokes a hub method on the server using the specified name and arguments.
  ///
  /// The [Future] returned by this method resolves when the server indicates it has finished invoking the method. When the promise
  /// resolves, the server has finished invoking the method. If the server method returns a result, it is produced as the result of
  /// resolving the [Future].
  ///
  /// [T] The expected return type.
  ///
  /// [methodName] The name of the server method to invoke.
  ///
  /// [args] The arguments used to invoke the server method.
  ///
  /// Returns a [Future] that resolves with the result of the server method (if any), or rejects with an error.
  Future<T> invokeAsync<T>(String methodName, [List<dynamic> args]);

  /// Registers a handler that will be invoked when the hub method with the specified method name is invoked.
  ///
  /// [methodName] The name of the hub method to define.
  ///
  /// [newMethod] The handler that will be raised when the hub method is invoked.
  void on(String methodName, void Function(List<dynamic> args) newMethod);

  /// Removes the specified handler for the specified hub method.
  ///
  /// You must pass the exact same Function instance as was previously passed to [HubConnection.on]. Passing a different instance (even if the function
  /// body is the same) will not remove the handler.
  ///
  /// [methodName] The name of the method to remove handlers for.
  /// [method] The handler to remove. This must be the same Function instance as the one passed to [HubConnection.on].
  void off(String methodName, [void Function(List<dynamic> args) method]);

  /// Registers a handler that will be invoked when the connection is closed.
  ///
  /// [callback] The handler that will be invoked when the connection is closed. Optionally receives a single argument containing the error that caused the connection to close (if any).
  void onclose(void Function(Exception error) callback);

  /// Registers a handler that will be invoked when the connection starts reconnecting.
  ///
  /// [callback] The handler that will be invoked when the connection starts reconnecting. Optionally receives a single argument containing the error that caused the connection to start reconnecting (if any).
  void onreconnecting(void Function(Exception error) callback);

  /// Registers a handler that will be invoked when the connection successfully reconnects.
  ///
  /// [callback] The handler that will be invoked when the connection successfully reconnects.
  void onreconnected(void Function(String connectionId) callback);

  factory HubConnection.create(
      Connection connection, Logger logger, HubProtocol protocol,
      [RetryPolicy reconnectPolicy]) {
    return _HubConnection(connection, logger, protocol, reconnectPolicy);
  }
}

class _HubConnection implements HubConnection {
  final dynamic _cachedPingMessage;
  final Connection _connection;
  final Logger _logger;
  final RetryPolicy _reconnectPolicy;
  final HubProtocol _protocol;
  final HandshakeProtocol _handshakeProtocol;
  Map<String, void Function(HubMessage invocationEvent, Exception error)>
      _callbacks;
  final Map<String, List<void Function(List<dynamic> args)>> _methods;
  int _invocationId;
  final List<void Function(Exception error)> _closedCallbacks;
  final List<void Function(Exception error)> _reconnectingCallbacks;
  final List<void Function(String connectionId)> _reconnectedCallbacks;
  bool _receivedHandshakeResponse;
  Completer<void> _handshakeCompleter;
  Exception _stopDuringStartError;
  HubConnectionState _connectionState;
  // connectionStarted is tracked independently from connectionState, so we can check if the
  // connection ever did successfully transition from connecting to connected before disconnecting.
  bool _connectionStarted;
  Future<void> _startFuture;
  Future<void> _stopFuture;
  Timer _reconnectDelayHandle;
  Timer _timeoutHandle;
  Timer _pingServerHandle;

  @override
  String get baseURL => _connection.baseURL ?? '';
  @override
  set baseURL(String url) {
    if (_connectionState != HubConnectionState.disconnected &&
        _connectionState != HubConnectionState.reconnecting) {
      throw Exception(
          'The HubConnection must be in the Disconnected or Reconnecting state to change the url.');
    }

    if (url == null) {
      throw Exception('The HubConnection url must be a valid url.');
    }

    _connection.baseURL = url;
  }

  @override
  int keepAliveIntervalInMilliseconds;
  @override
  int serverTimeoutInMilliseconds;

  @override
  HubConnectionState get state => _connectionState;
  @override
  String get connectionId => _connection?.connectionId;

  _HubConnection(this._connection, this._logger, this._protocol,
      [this._reconnectPolicy])
      : serverTimeoutInMilliseconds = DEFAULT_TIMEOUT_IN_MS,
        keepAliveIntervalInMilliseconds = DEFAULT_PING_INTERVAL_IN_MS,
        _handshakeProtocol = HandshakeProtocol(),
        _callbacks = {},
        _methods = {},
        _closedCallbacks = [],
        _reconnectingCallbacks = [],
        _reconnectedCallbacks = [],
        _invocationId = 0,
        _receivedHandshakeResponse = false,
        _connectionState = HubConnectionState.disconnected,
        _connectionStarted = false,
        _cachedPingMessage = _protocol.writeMessage(PingMessage()) {
    Arg.isRequired(_connection, 'connection');
    Arg.isRequired(_logger, 'logger');
    Arg.isRequired(_protocol, 'protocol');

    _connection.onreceive = (data) => _processIncomingData(data);
    _connection.onclose = (error) => _connectionClosed(error);
  }

  @override
  Future<void> startAsync() {
    _startFuture = _startWithStateTransitionsAsync();
    return _startFuture;
  }

  @override
  Future<void> stopAsync() async {
    final startFuture = _startFuture;
    _stopFuture = _stopInternalAsync();
    await _stopFuture;

    try {
      // Awaiting undefined continues immediately
      await startFuture;
    } catch (_) {
      // This exception is returned to the user as a rejected Future from the start method.
    }
  }

  @override
  StreamResult<T> stream<T>(String methodName, [List<dynamic> args]) {
    args ??= [];
    final streams = _replaceStreamingParams(args);
    final invocationDescriptor =
        _createStreamInovation(methodName, args, streams.value);

    Future<void> futureQueue;
    final subject = Subject<T>();
    subject.cancelCallback = () {
      final cancelInvocation =
          _createCancelInocation(invocationDescriptor.invocationId);

      _callbacks.remove(invocationDescriptor.invocationId);

      return futureQueue.then((_) => _sendWithProtocolAsync(cancelInvocation));
    };

    _callbacks[invocationDescriptor.invocationId] = (invocationEvent, error) {
      if (error != null) {
        subject.error(error);
        return;
      } else if (invocationEvent is CompletionMessage) {
        if (invocationEvent.error != null) {
          final error = Exception(invocationEvent.error);
          subject.error(error);
        } else {
          subject.complete();
        }
      } else if (invocationEvent is StreamItemMessage) {
        final item = invocationEvent.item as T;
        subject.next(item);
      }
    };

    futureQueue = _sendWithProtocolAsync(invocationDescriptor).catchError((e) {
      subject.error(e);
      _callbacks.remove(invocationDescriptor.invocationId);
    });

    _launchStreams(streams.key, futureQueue);

    return subject;
  }

  @override
  Future<void> sendAsync(String methodName, [List<dynamic> args]) {
    final streams = _replaceStreamingParams(args);
    final message = _createInvocation(methodName, args, true, streams.value);
    final sendFuture = _sendWithProtocolAsync(message);

    _launchStreams(streams.key, sendFuture);

    return sendFuture;
  }

  @override
  Future<T> invokeAsync<T>(String methodName, [List<dynamic> args]) {
    args ??= [];
    final streams = _replaceStreamingParams(args);
    final invocationDescriptor =
        _createInvocation(methodName, args, false, streams.value);

    final completer = Completer<dynamic>();

    // invocationId will always have a value for a non-blocking invocation
    _callbacks[invocationDescriptor.invocationId] = (invocationEvent, error) {
      if (error != null) {
        completer.completeError(error);
        return;
      } else if (invocationEvent is CompletionMessage) {
        // invocationEvent will not be null when an error is not passed to the callback
        if (invocationEvent.error != null) {
          final error = Exception(invocationEvent.error);
          completer.completeError(error);
        } else {
          completer.complete(invocationEvent.result);
        }
      } else {
        final error =
            Exception('Unexpected message type: ${invocationEvent.type}');
        completer.completeError(error);
      }
    };

    final futureQueue =
        _sendWithProtocolAsync(invocationDescriptor).catchError((e) {
      completer.completeError(e);
      // invocationId will always have a value for a non-blocking invocation
      _callbacks.remove(invocationDescriptor.invocationId);
    });

    _launchStreams(streams.key, futureQueue);

    return completer.future;
  }

  @override
  void on(String methodName, void Function(List<dynamic> args) newMethod) {
    if (methodName == null || newMethod == null) {
      return;
    }

    methodName = methodName.toLowerCase();
    if (_methods[methodName] == null) {
      _methods[methodName] = [];
    }

    // Preventing adding the same handler multiple times.
    if (_methods[methodName].contains(newMethod)) {
      return;
    }

    _methods[methodName].add(newMethod);
  }

  @override
  void off(String methodName, [void Function(List<dynamic> args) method]) {
    if (methodName == null) {
      return;
    }

    methodName = methodName.toLowerCase();
    final handlers = _methods[methodName];
    if (handlers == null) {
      return;
    }
    if (method != null) {
      final removeIdx = handlers.indexOf(method);
      if (removeIdx != -1) {
        handlers.removeAt(removeIdx);
        if (handlers.isEmpty) {
          _methods.remove(methodName);
        }
      }
    } else {
      _methods.remove(methodName);
    }
  }

  @override
  void onclose(void Function(Exception error) callback) {
    if (callback != null) {
      _closedCallbacks.add(callback);
    }
  }

  @override
  void onreconnecting(void Function(Exception error) callback) {
    if (callback != null) {
      _reconnectingCallbacks.add(callback);
    }
  }

  @override
  void onreconnected(void Function(String connectionId) callback) {
    if (callback != null) {
      _reconnectedCallbacks.add(callback);
    }
  }

  void _processIncomingData(dynamic data) {
    _cleanupTimeout();

    if (!_receivedHandshakeResponse) {
      data = _processHandshakeResponse(data);
      _receivedHandshakeResponse = true;
    }

    // Data may have all been read when processing handshake response
    if (data != null) {
      // Parse the messages
      final messages = _protocol.parseMessages(data, _logger);

      for (final message in messages) {
        if (message is InvocationMessage) {
          _invokeClientMethod(message);
        } else if (message is CompletionMessage) {
          final callback = _callbacks[message.invocationId];
          if (callback != null) {
            _callbacks.remove(message.invocationId);
            callback(message, null);
          }
        } else if (message is StreamItemMessage) {
          final callback = _callbacks[message.invocationId];
          if (callback != null) {
            callback(message, null);
          }
        } else if (message is PingMessage) {
          // Don't care about pings
        } else if (message is CloseMessage) {
          _logger.log(
              LogLevel.information, 'Close message received from server.');

          final error = message.error != null
              ? Exception('Server returned an error on close: ${message.error}')
              : null;

          if (message.allowReconnect == true) {
            // It feels wrong not to await connection.stop() here, but processIncomingData is called as part of an onreceive callback which is not async,
            // this is already the behavior for serverTimeout(), and HttpConnection.Stop() should catch and log all possible exceptions.
            _connection.stopAsync(error);
          } else {
            // We cannot await stopInternal() here, but subsequent calls to stop() will await this if stopInternal() is still ongoing.
            _stopFuture = _stopInternalAsync(error);
          }
        } else {
          _logger.log(
              LogLevel.warning, 'Invalid message type: ${message.type}.');
        }
      }
    }

    _resetTimeoutPeriod();
  }

  dynamic _processHandshakeResponse(dynamic data) {
    HandshakeResponseMessage responseMessage;
    dynamic remainingData;

    try {
      final tuple = _handshakeProtocol.parseHandshakeResponse(data);
      remainingData = tuple.key;
      responseMessage = tuple.value;
    } catch (e) {
      final message = 'Error parsing handshake response: $e';
      _logger.log(LogLevel.error, message);

      final error = Exception(message);
      _handshakeCompleter.completeError(error);
      throw error;
    }
    if (responseMessage.error != null) {
      final message =
          'Server returned handshake error: ${responseMessage.error}';
      _logger.log(LogLevel.error, message);

      final error = Exception(message);
      _handshakeCompleter.completeError(error);
      throw error;
    } else {
      _logger.log(LogLevel.debug, 'Server handshake complete.');
      _handshakeCompleter.complete();
    }

    return remainingData;
  }

  void _connectionClosed([Exception error]) {
    _logger.log(LogLevel.debug,
        'HubConnection.connectionClosed($error) called while in state $_connectionState.');

    // Triggering this.handshakeRejecter is insufficient because it could already be resolved without the continuation having run yet.
    _stopDuringStartError = _stopDuringStartError ??
        error ??
        Exception(
            'The underlying connection was closed before the hub handshake could complete.');

    // If the handshake is in progress, start will be waiting for the handshake promise, so we complete it.
    // If it has already completed, this should just noop.
    if (_handshakeCompleter != null && !_handshakeCompleter.isCompleted) {
      _handshakeCompleter.complete();
    }

    _cancelCallbacksWithError(error ??
        Exception(
            'Invocation canceled due to the underlying connection being closed.'));

    _cleanupTimeout();
    _cleanupPingTimer();

    if (_connectionState == HubConnectionState.disconnecting) {
      _completeClose(error);
    } else if (_connectionState == HubConnectionState.connected &&
        _reconnectPolicy != null) {
      _reconnectAsync(error);
    } else if (_connectionState == HubConnectionState.connected) {
      _completeClose(error);
    }

    // If none of the above if conditions were true were called the HubConnection must be in either:
    // 1. The Connecting state in which case the handshakeResolver will complete it and stopDuringStartError will fail it.
    // 2. The Reconnecting state in which case the handshakeResolver will complete it and stopDuringStartError will fail the current reconnect attempt
    //    and potentially continue the reconnect() loop.
    // 3. The Disconnected state in which case we're already done.
  }

  Future<void> _startWithStateTransitionsAsync() async {
    if (_connectionState != HubConnectionState.disconnected) {
      final error = Exception(
          "Cannot start a HubConnection that is not in the 'Disconnected' state.");
      return Future.error(error);
    }

    _connectionState = HubConnectionState.connecting;
    _logger.log(LogLevel.debug, 'Starting HubConnection.');

    try {
      await _startInternalAsync();
      _connectionState = HubConnectionState.connected;
      _connectionStarted = true;
      _logger.log(LogLevel.debug, 'HubConnection connected sucessfully.');
    } catch (e) {
      _connectionState = HubConnectionState.disconnected;
      _logger.log(LogLevel.debug,
          "HubConnection failed to start successfully because of error '$e'.");
      return Future.error(e);
    }
  }

  Future<void> _startInternalAsync() async {
    _stopDuringStartError = null;
    _receivedHandshakeResponse = false;

    _handshakeCompleter = Completer();
    final future = _handshakeCompleter.future;
    // HACK: Dart will throw error if we don't catch the error immediately...
    // See https://github.com/dart-lang/sdk/issues/44561
    unawaited(future.catchError((_) {}));

    await _connection.startAsync(_protocol.transferFormat);

    try {
      final handshakeRequest =
          HandshakeRequestMessage(_protocol.name, _protocol.version);

      _logger.log(LogLevel.debug, 'Sending handshake request.');

      final message =
          _handshakeProtocol.writeHandshakeRequest(handshakeRequest);
      await _sendMessageAsync(message);

      _logger.log(
          LogLevel.information, "Using HubProtocol '${_protocol.name}'.");

      _cleanupTimeout();
      _resetTimeoutPeriod();
      _resetKeepAliveInterval();

      await future;

      if (_stopDuringStartError != null) {
        throw _stopDuringStartError;
      }
    } catch (e) {
      _logger.log(LogLevel.debug,
          "Hub handshake failed with error '$e' during start(). Stopping HubConnection.");

      _cleanupTimeout();
      _cleanupPingTimer();

      await _connection.stopAsync(e);
      rethrow;
    }
  }

  void _resetTimeoutPeriod() {
    if (_connection.features == null ||
        _connection.features['inherentKeepAlive'] != true) {
      // Set the timeout timer
      final duration = Duration(milliseconds: serverTimeoutInMilliseconds);
      _timeoutHandle = Timer(duration, () => _serverTimeout());
    }
  }

  void _serverTimeout() {
    // The server hasn't talked to us in a while. It doesn't like us anymore ... :(
    // Terminate the connection, but we don't need to wait on the promise. This could trigger reconnecting.
    // tslint:disable-next-line:no-floating-promises
    final error = Exception(
        'Server timeout elapsed without receiving a message from the server.');
    _connection.stopAsync(error);
  }

  void _resetKeepAliveInterval() {
    if (_connection.features['inherentKeepAlive'] == true) {
      return;
    }

    _cleanupPingTimer();
    final duration = Duration(milliseconds: keepAliveIntervalInMilliseconds);
    _pingServerHandle = Timer(duration, () async {
      if (_connectionState == HubConnectionState.connected) {
        try {
          await _sendMessageAsync(_cachedPingMessage);
        } catch (_) {
          // We don't care about the error. It should be seen elsewhere in the client.
          // The connection is probably in a bad or closed state now, cleanup the timer so it stops triggering
          _cleanupPingTimer();
        }
      }
    });
  }

  void _cleanupPingTimer() {
    if (_pingServerHandle != null) {
      _pingServerHandle.cancel();
      _pingServerHandle = null;
    }
  }

  void _cleanupTimeout() {
    if (_timeoutHandle != null) {
      _timeoutHandle.cancel();
      _timeoutHandle = null;
    }
  }

  Future<void> _stopInternalAsync([Exception error]) {
    if (_connectionState == HubConnectionState.disconnected) {
      _logger.log(LogLevel.debug,
          'Call to HubConnection.stop($error) ignored because it is already in the disconnected state.');
      return Future.value();
    }

    if (_connectionState == HubConnectionState.disconnecting) {
      _logger.log(LogLevel.debug,
          'Call to HttpConnection.stop($error) ignored because the connection is already in the disconnecting state.');
      return _stopFuture;
    }

    _connectionState = HubConnectionState.disconnecting;

    _logger.log(LogLevel.debug, 'Stopping HubConnection.');

    if (_reconnectDelayHandle != null) {
      // We're in a reconnect delay which means the underlying connection is currently already stopped.
      // Just clear the handle to stop the reconnect loop (which no one is waiting on thankfully) and
      // fire the onclose callbacks.
      _logger.log(LogLevel.debug,
          'Connection stopped during reconnect delay. Done reconnecting.');

      _clearTimeout(_reconnectDelayHandle);
      _reconnectDelayHandle = null;

      _completeClose();
      return Future.value();
    }

    _cleanupTimeout();
    _cleanupPingTimer();
    _stopDuringStartError = error ??
        Exception(
            'The connection was stopped before the hub handshake could complete.');

    // HttpConnection.stop() should not complete until after either HttpConnection.start() fails
    // or the onclose callback is invoked. The onclose callback will transition the HubConnection
    // to the disconnected state if need be before HttpConnection.stop() completes.
    return _connection.stopAsync(error);
  }

  void _clearTimeout(reconnectDelayHandle) {}

  void _completeClose([Exception error]) {
    if (_connectionStarted == true) {
      _connectionState = HubConnectionState.disconnected;
      _connectionStarted = false;

      try {
        _closedCallbacks.forEach((c) => c.call(error));
      } catch (e) {
        _logger.log(LogLevel.error,
            "`An onclose callback called with error '$error' threw error '$e'.");
      }
    }
  }

  void _launchStreams(
      Map<int, StreamResult<dynamic>> streams, Future<void> futureQueue) {
    if (streams.isEmpty) {
      return;
    }

    // Synchronize stream data so they arrive in-order on the server
    futureQueue ??= Future.value();

    // We want to iterate over the keys, since the keys are the stream ids
    for (var entry in streams.entries) {
      var streamId = entry.key.toString();
      final stream = entry.value;
      final subscriber = StreamSubscriber(onnext: (item) {
        futureQueue = futureQueue.then((_) {
          final message = _createStreamItemMessage(streamId, item);
          return _sendWithProtocolAsync(message);
        });
      }, onerror: (error) {
        error = error ?? Exception('Unknown error');

        futureQueue = futureQueue.then((_) {
          final message = _createCompletionMessage(streamId, error: error);
          return _sendWithProtocolAsync(message);
        });
      }, oncomplete: () {
        futureQueue = futureQueue.then((_) {
          final message = _createCompletionMessage(streamId);
          return _sendWithProtocolAsync(message);
        });
      });
      stream.subscribe(subscriber);
    }
  }

  MapEntry<Map<int, StreamResult<dynamic>>, List<String>>
      _replaceStreamingParams(List<dynamic> args) {
    final streams = <int, StreamResult<dynamic>>{};
    final streamIds = <String>[];

    for (var i = args.length - 1; i >= 0; i--) {
      final argument = args[i];
      if (argument is StreamResult<dynamic>) {
        final streamId = _invocationId;
        _invocationId++;
        // Store the stream for later use
        streams[streamId] = argument;
        streamIds.add('$streamId');

        // remove stream from args
        args.removeAt(i);
      }
    }

    return MapEntry(streams, streamIds);
  }

  InvocationMessage _createInvocation(String methodName, List<dynamic> args,
      bool nonblocking, List<String> streamIds) {
    if (nonblocking) {
      if (streamIds.isNotEmpty) {
        return InvocationMessage(methodName, args, streamIds: streamIds);
      } else {
        return InvocationMessage(methodName, args);
      }
    } else {
      final invocationId = _invocationId.toString();
      _invocationId++;

      if (streamIds.isNotEmpty) {
        return InvocationMessage(methodName, args,
            invocationId: invocationId, streamIds: streamIds);
      } else {
        return InvocationMessage(methodName, args, invocationId: invocationId);
      }
    }
  }

  StreamInvocationMessage _createStreamInovation(
      String methodName, List<dynamic> args, List<String> streamIds) {
    final invocationId = _invocationId.toString();
    _invocationId++;

    if (streamIds.isNotEmpty) {
      return StreamInvocationMessage(invocationId, methodName, args,
          streamIds: streamIds);
    } else {
      return StreamInvocationMessage(invocationId, methodName, args);
    }
  }

  CancelInvocationMessage _createCancelInocation(String id) {
    return CancelInvocationMessage(id);
  }

  StreamItemMessage _createStreamItemMessage(String id, dynamic item) {
    return StreamItemMessage(id, item: item);
  }

  CompletionMessage _createCompletionMessage(String id,
      {Exception error, dynamic result}) {
    if (error != null) {
      return CompletionMessage(id, error: '$error');
    }

    return CompletionMessage(id, result: result);
  }

  Future<void> _sendWithProtocolAsync(dynamic message) {
    final data = _protocol.writeMessage(message);
    return _sendMessageAsync(data);
  }

  Future<void> _sendMessageAsync(dynamic message) {
    _resetKeepAliveInterval();
    return _connection.sendAsync(message);
  }

  void _invokeClientMethod(InvocationMessage invocationMessage) {
    final methods = _methods[invocationMessage.target.toLowerCase()];
    if (methods != null) {
      try {
        methods.forEach((m) => m.call(invocationMessage.arguments.toList()));
      } catch (e) {
        _logger.log(LogLevel.error,
            "A callback for the method ${invocationMessage.target.toLowerCase()} threw error '$e'.");
      }

      if (invocationMessage.invocationId != null) {
        // This is not supported in v1. So we return an error to avoid blocking the server waiting for the response.
        final message =
            'Server requested a response, which is not supported in this version of the client.';
        _logger.log(LogLevel.error, message);

        // We don't want to wait on the stop itself.
        final error = Exception(message);
        _stopFuture = _stopInternalAsync(error);
      }
    } else {
      _logger.log(LogLevel.warning,
          "No client method with the name '${invocationMessage.target}' found.");
    }
  }

  void _cancelCallbacksWithError(Exception error) {
    final callbacks = _callbacks.values;
    _callbacks = {};

    for (var callback in callbacks) {
      callback(null, error);
    }
  }

  Future<void> _reconnectAsync([Exception error]) async {
    final reconnectStartTime = DateTime.now();
    var previousReconnectAttempts = 0;
    var retryError =
        error ?? Exception('Attempting to reconnect due to a unknown error.');

    var nextRetryDelay =
        _getNextRetryDelay(previousReconnectAttempts++, 0, retryError);

    if (nextRetryDelay == null) {
      _logger.log(LogLevel.debug,
          'Connection not reconnecting because the IRetryPolicy returned null on the first reconnect attempt.');
      _completeClose(error);
      return;
    }

    _connectionState = HubConnectionState.reconnecting;

    if (error != null) {
      _logger.log(LogLevel.information,
          "Connection reconnecting because of error '$error'.");
    } else {
      _logger.log(LogLevel.information, 'Connection reconnecting.');
    }

    if (_reconnectingCallbacks != null) {
      try {
        _reconnectingCallbacks.forEach((c) => c.call(error));
      } catch (e) {
        _logger.log(LogLevel.error,
            "An onreconnecting callback called with error '$error' threw error '$e'.");
      }

      // Exit early if an onreconnecting callback called connection.stop().
      if (_connectionState != HubConnectionState.reconnecting) {
        _logger.log(LogLevel.debug,
            'Connection left the reconnecting state in onreconnecting callback. Done reconnecting.');
        return;
      }
    }

    while (nextRetryDelay != null) {
      _logger.log(LogLevel.information,
          'Reconnect attempt number $previousReconnectAttempts will start in $nextRetryDelay ms.');

      final completer = Completer<void>();
      final duration = Duration(milliseconds: nextRetryDelay);
      _reconnectDelayHandle = Timer(duration, () => completer.complete());
      await completer.future;
      _reconnectDelayHandle = null;

      if (_connectionState != HubConnectionState.reconnecting) {
        _logger.log(LogLevel.debug,
            'Connection left the reconnecting state during reconnect delay. Done reconnecting.');
        return;
      }

      try {
        await _startInternalAsync();

        _connectionState = HubConnectionState.connected;
        _logger.log(
            LogLevel.information, 'HubConnection reconnected successfully.');

        if (_reconnectedCallbacks != null) {
          try {
            _reconnectedCallbacks
                .forEach((c) => c.call(_connection.connectionId));
          } catch (e) {
            _logger.log(LogLevel.error,
                "An onreconnected callback called with connectionId '${_connection.connectionId}; threw error '$e'.");
          }
        }

        return;
      } catch (e) {
        _logger.log(LogLevel.information,
            "Reconnect attempt failed because of error '$e'.");

        if (_connectionState != HubConnectionState.reconnecting) {
          _logger.log(LogLevel.debug,
              'Connection left the reconnecting state during reconnect attempt. Done reconnecting.');
          return;
        }

        retryError = e is Exception ? e : Exception('$e');
        nextRetryDelay = _getNextRetryDelay(
            previousReconnectAttempts++,
            DateTime.now().difference(reconnectStartTime).inMilliseconds,
            retryError);
      }
    }

    _logger.log(LogLevel.information,
        'Reconnect retries have been exhausted after ${DateTime.now().difference(reconnectStartTime).inMilliseconds} ms and ${previousReconnectAttempts} failed attempts. Connection disconnecting.');

    _completeClose();
  }

  int _getNextRetryDelay(
      int previousRetryCount, int elapsedMilliseconds, Exception retryReason) {
    try {
      final retryContext =
          RetryContext(previousRetryCount, elapsedMilliseconds, retryReason);
      return _reconnectPolicy.nextRetryDelayInMilliseconds(retryContext);
    } catch (e) {
      _logger.log(LogLevel.error,
          "IRetryPolicy.nextRetryDelayInMilliseconds($previousRetryCount, $elapsedMilliseconds) threw error '$e'.");
      return null;
    }
  }
}

/// Describes the current state of the [HubConnection] to the server.
abstract class HubConnectionState {
  String get name;

  /// The hub connection is disconnected.
  static const HubConnectionState disconnected =
      _HubConnectionState('Disconnected');

  /// The hub connection is connecting.
  static const HubConnectionState connecting =
      _HubConnectionState('Connecting');

  /// The hub connection is connected.
  static const HubConnectionState connected = _HubConnectionState('Connected');

  /// The hub connection is disconnecting.
  static const HubConnectionState disconnecting =
      _HubConnectionState('Disconnecting');

  /// The hub connection is reconnecting.
  static const HubConnectionState reconnecting =
      _HubConnectionState('Reconnecting');
}

class _HubConnectionState implements HubConnectionState {
  @override
  final String name;

  const _HubConnectionState(this.name);

  @override
  String toString() {
    return name;
  }
}
