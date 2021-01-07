import 'dart:async';

import 'package:cure/signalr.dart';
import 'package:mockito/mockito.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'test_connection.dart';

void main() {
  test('# is not enabled by default', () async {
    await VerifyLogger.runAsync((logger) async {
      final closeCompleter = Completer<void>();
      var onreconnectingCalled = false;

      final connection = TestConnection();
      final hubConnection =
          HubConnection.create(connection, logger, JsonHubProtocol());

      hubConnection.onclose((_) => closeCompleter.complete());

      hubConnection.onreconnecting((_) => onreconnectingCalled = true);

      await hubConnection.startAsync();

      // Typically this would be called by the transport
      final error = Exception('Connection lost');
      connection.onclose.call(error);

      await closeCompleter.future;

      expect(onreconnectingCalled, false);
    });
  });
  test('# can be opted into', () async {
    await VerifyLogger.runAsync((logger) async {
      final reconnectedCompleter = Completer<void>();

      var nextRetryDelayCalledCompleter = Completer<void>();
      var continueRetryingCompleter = Completer<void>();

      var lastRetryCount = -1;
      var lastElapsedMs = -1;
      Exception retryReason;
      var onreconnectingCount = 0;
      var onreconnectedCount = 0;
      var closeCount = 0;

      final connection = TestConnection();
      final retryPolicy = MockRetryPolicy();
      when(retryPolicy.nextRetryDelayInMilliseconds(any)).thenAnswer((i) {
        final retryContext = i.positionalArguments[0] as RetryContext;
        lastRetryCount = retryContext.previousRetryCount;
        lastElapsedMs = retryContext.elapsedMilliseconds;
        retryReason = retryContext.retryReason;
        nextRetryDelayCalledCompleter.complete();
        return 0;
      });
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), retryPolicy);

      hubConnection.onreconnecting((_) => onreconnectingCount++);

      hubConnection.onreconnected((_) {
        onreconnectedCount++;
        reconnectedCompleter.complete();
      });

      hubConnection.onclose((_) => closeCount++);

      await hubConnection.startAsync();

      connection.startFuture = () {
        final completer = continueRetryingCompleter;
        continueRetryingCompleter = Completer<void>();
        return completer.future;
      };

      final oncloseError = Exception('Connection lost');
      final continueRetryingError = Exception('Reconnect attempt failed');

      // Typically this would be called by the transport
      connection.onclose(oncloseError);

      await nextRetryDelayCalledCompleter.future;
      nextRetryDelayCalledCompleter = Completer<void>();

      expect(hubConnection.state, HubConnectionState.reconnecting);
      expect(lastRetryCount, 0);
      expect(lastElapsedMs, 0);
      expect(retryReason, oncloseError);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);

      // Make sure the the Future is "handled" immediately upon rejection or else this test fails.
      unawaited(continueRetryingCompleter.future.catchError((_) => {}));
      continueRetryingCompleter.completeError(continueRetryingError);
      await nextRetryDelayCalledCompleter.future;

      final matcher = greaterThanOrEqualTo(0);

      expect(lastRetryCount, 1);
      expect(lastElapsedMs, matcher);
      expect(retryReason, continueRetryingError);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);

      continueRetryingCompleter.complete();
      await reconnectedCompleter.future;

      expect(hubConnection.state, HubConnectionState.connected);
      expect(lastRetryCount, 1);
      expect(lastElapsedMs, matcher);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 1);
      expect(closeCount, 0);

      await hubConnection.stopAsync();

      expect(lastRetryCount, 1);
      expect(lastElapsedMs, matcher);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 1);
      expect(closeCount, 1);
    });
  });
  test('# stops if the reconnect policy returns null', () async {
    await VerifyLogger.runAsync((logger) async {
      final closeCompleter = Completer<void>();

      var nextRetryDelayCalledCompleter = Completer<void>();

      var lastRetryCount = -1;
      var lastElapsedMs = -1;
      Exception retryReason;
      var onreconnectingCount = 0;
      var onreconnectedCount = 0;
      var closeCount = 0;

      final connection = TestConnection();
      final retryPolicy = MockRetryPolicy();
      when(retryPolicy.nextRetryDelayInMilliseconds(any)).thenAnswer((i) {
        final retryContext = i.positionalArguments[0] as RetryContext;
        lastRetryCount = retryContext.previousRetryCount;
        lastElapsedMs = retryContext.elapsedMilliseconds;
        retryReason = retryContext.retryReason;
        nextRetryDelayCalledCompleter.complete();

        return retryContext.previousRetryCount == 0 ? 0 : null;
      });
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), retryPolicy);

      hubConnection.onreconnecting((_) => onreconnectingCount++);

      hubConnection.onreconnected((_) => onreconnectedCount++);

      hubConnection.onclose((_) {
        closeCount++;
        closeCompleter.complete();
      });

      await hubConnection.startAsync();

      final oncloseError = Exception('Connection lost');
      final startError = Exception('Reconnect attempt failed');

      connection.startFuture = () => throw startError;

      // Typically this would be called by the transport
      connection.onclose(oncloseError);

      await nextRetryDelayCalledCompleter.future;
      nextRetryDelayCalledCompleter = Completer<void>();

      expect(hubConnection.state, HubConnectionState.reconnecting);
      expect(lastRetryCount, 0);
      expect(lastElapsedMs, 0);
      expect(retryReason, oncloseError);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);

      await nextRetryDelayCalledCompleter.future;

      expect(hubConnection.state, HubConnectionState.disconnected);
      expect(lastRetryCount, 1);
      final matcher = greaterThanOrEqualTo(0);
      expect(lastElapsedMs, matcher);
      expect(retryReason, startError);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 1);
    });
  });
  test('# can reconnect multiple times', () async {
    await VerifyLogger.runAsync((logger) async {
      var reconnectedCompleter = Completer<void>();
      var nextRetryDelayCalledCompleter = Completer<void>();

      var lastRetryCount = -1;
      var lastElapsedMs = -1;
      Exception retryReason;
      var onreconnectingCount = 0;
      var onreconnectedCount = 0;
      var closeCount = 0;

      final connection = TestConnection();
      final retryPolicy = MockRetryPolicy();
      when(retryPolicy.nextRetryDelayInMilliseconds(any)).thenAnswer((i) {
        final retryContext = i.positionalArguments[0] as RetryContext;
        lastRetryCount = retryContext.previousRetryCount;
        lastElapsedMs = retryContext.elapsedMilliseconds;
        retryReason = retryContext.retryReason;
        nextRetryDelayCalledCompleter.complete();
        return 0;
      });
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), retryPolicy);

      hubConnection.onreconnecting((_) => onreconnectingCount++);

      hubConnection.onreconnected((_) {
        onreconnectedCount++;
        reconnectedCompleter.complete();
      });

      hubConnection.onclose((_) => closeCount++);

      await hubConnection.startAsync();

      final oncloseError = Exception('Connection lost 1');
      final oncloseError2 = Exception('Connection lost 2');

      // Typically this would be called by the transport
      connection.onclose(oncloseError);

      await nextRetryDelayCalledCompleter.future;
      nextRetryDelayCalledCompleter = Completer<void>();

      expect(hubConnection.state, HubConnectionState.reconnecting);
      expect(lastRetryCount, 0);
      expect(lastElapsedMs, 0);
      expect(retryReason, oncloseError);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);

      await reconnectedCompleter.future;
      reconnectedCompleter = Completer<void>();

      expect(hubConnection.state, HubConnectionState.connected);
      expect(lastRetryCount, 0);
      expect(lastElapsedMs, 0);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 1);
      expect(closeCount, 0);

      connection.onclose(oncloseError2);

      await nextRetryDelayCalledCompleter.future;

      expect(hubConnection.state, HubConnectionState.reconnecting);
      expect(lastRetryCount, 0);
      expect(lastElapsedMs, 0);
      expect(retryReason, oncloseError2);
      expect(onreconnectingCount, 2);
      expect(onreconnectedCount, 1);
      expect(closeCount, 0);

      await reconnectedCompleter.future;

      expect(hubConnection.state, HubConnectionState.connected);
      expect(lastRetryCount, 0);
      expect(lastElapsedMs, 0);
      expect(onreconnectingCount, 2);
      expect(onreconnectedCount, 2);
      expect(closeCount, 0);

      await hubConnection.stopAsync();

      expect(lastRetryCount, 0);
      expect(lastElapsedMs, 0);
      expect(onreconnectingCount, 2);
      expect(onreconnectedCount, 2);
      expect(closeCount, 1);
    });
  });
  test(
      '# does not transition into the reconnecting state if the first retry delay is null',
      () async {
    await VerifyLogger.runAsync((logger) async {
      final closeCompleter = Completer<void>();

      var onreconnectingCount = 0;
      var onreconnectedCount = 0;
      var closeCount = 0;

      final connection = TestConnection();
      // Note the [] parameter to the DefaultReconnectPolicy.
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), DefaultReconnectPolicy([]));

      hubConnection.onreconnecting((_) => onreconnectingCount++);

      hubConnection.onreconnected((_) => onreconnectedCount++);

      hubConnection.onclose((_) {
        closeCount++;
        closeCompleter.complete();
      });

      await hubConnection.startAsync();

      // Typically this would be called by the transport
      connection.onclose(Exception('Connection lost'));

      await closeCompleter.future;

      expect(hubConnection.state, HubConnectionState.disconnected);
      expect(onreconnectingCount, 0);
      expect(onreconnectedCount, 0);
      expect(closeCount, 1);
    });
  });
  test(
      '# does not transition into the reconnecting state if the connection is lost during initial handshake',
      () async {
    await VerifyLogger.runAsync((logger) async {
      var onreconnectingCount = 0;
      var onreconnectedCount = 0;
      var closeCount = 0;

      // Disable autoHandshake in TestConnection
      final connection = TestConnection(false);
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), DefaultReconnectPolicy());

      hubConnection.onreconnecting((_) => onreconnectingCount++);

      hubConnection.onreconnected((_) => onreconnectedCount++);

      hubConnection.onclose((_) => closeCount++);

      final startFuture = hubConnection.startAsync();

      expect(hubConnection.state, HubConnectionState.connecting);

      // Typically this would be called by the transport
      connection.onclose(Exception('Connection lost'));

      final m = predicate((e) => '$e' == 'Exception: Connection lost');
      final matcher = throwsA(m);
      await expectLater(startFuture, matcher);

      expect(onreconnectingCount, 0);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);
    });
  });
  test(
      '# continues reconnecting state if the connection is lost during a reconnecting handshake',
      () async {
    await VerifyLogger.runAsync((logger) async {
      final reconnectedCompleter = Completer<void>();
      var nextRetryDelayCalledCompleter = Completer<void>();

      var lastRetryCount = 0;
      Exception retryReason;
      var onreconnectingCount = 0;
      var onreconnectedCount = 0;
      var closeCount = 0;

      // Disable autoHandshake in TestConnection
      final connection = TestConnection(false);
      final retryPolicy = MockRetryPolicy();
      when(retryPolicy.nextRetryDelayInMilliseconds(any)).thenAnswer((i) {
        final retryContext = i.positionalArguments[0] as RetryContext;
        lastRetryCount = retryContext.previousRetryCount;
        retryReason = retryContext.retryReason;
        nextRetryDelayCalledCompleter.complete();
        return 0;
      });
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), retryPolicy);

      hubConnection.onreconnecting((_) => onreconnectingCount++);

      hubConnection.onreconnected((_) {
        onreconnectedCount++;
        reconnectedCompleter.complete();
      });

      hubConnection.onclose((_) => closeCount++);

      final startFuture = hubConnection.startAsync();
      // Manually complete handshake.
      connection.receive({});
      await startFuture;

      var replacedStartCalledCompleter = Completer<void>();
      connection.startFuture = () {
        replacedStartCalledCompleter.complete();
        return Future.value();
      };

      final oncloseError = Exception('Connection lost 1');
      final oncloseError2 = Exception('Connection lost 2');

      // Typically this would be called by the transport
      connection.onclose(oncloseError);

      await nextRetryDelayCalledCompleter.future;
      nextRetryDelayCalledCompleter = Completer<void>();

      expect(hubConnection.state, HubConnectionState.reconnecting);
      expect(lastRetryCount, 0);
      expect(retryReason, oncloseError);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);

      await replacedStartCalledCompleter.future;
      replacedStartCalledCompleter = Completer<void>();

      // Fail underlying connection during reconnect during handshake
      connection.onclose(oncloseError2);

      await nextRetryDelayCalledCompleter.future;

      expect(hubConnection.state, HubConnectionState.reconnecting);
      expect(lastRetryCount, 1);
      expect(retryReason, oncloseError2);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);

      await replacedStartCalledCompleter.future;

      // Manually complete handshake.
      connection.receive({});

      await reconnectedCompleter.future;

      expect(hubConnection.state, HubConnectionState.connected);
      expect(lastRetryCount, 1);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 1);
      expect(closeCount, 0);

      await hubConnection.stopAsync();

      expect(lastRetryCount, 1);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 1);
      expect(closeCount, 1);
    });
  });
  test('# continues reconnecting state if invalid handshake response received',
      () async {
    await VerifyLogger.runAsync((logger) async {
      final reconnectedCompleter = Completer<void>();
      var nextRetryDelayCalledCompleter = Completer<void>();

      var lastRetryCount = 0;
      var onreconnectingCount = 0;
      var onreconnectedCount = 0;
      var closeCount = 0;

      // Disable autoHandshake in TestConnection
      final connection = TestConnection(false);
      final retryPolicy = MockRetryPolicy();
      when(retryPolicy.nextRetryDelayInMilliseconds(any)).thenAnswer((i) {
        final retryContext = i.positionalArguments[0] as RetryContext;
        lastRetryCount = retryContext.previousRetryCount;
        nextRetryDelayCalledCompleter.complete();
        return 0;
      });
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), retryPolicy);

      hubConnection.onreconnecting((_) => onreconnectingCount++);

      hubConnection.onreconnected((_) {
        onreconnectedCount++;
        reconnectedCompleter.complete();
      });

      hubConnection.onclose((_) => closeCount++);

      final startFuture = hubConnection.startAsync();
      // Manually complete handshake.
      connection.receive({});
      await startFuture;

      var replacedStartCalledCompleter = Completer<void>();
      connection.startFuture = () {
        replacedStartCalledCompleter.complete();
        return Future.value();
      };

      // Typically this would be called by the transport
      final error = Exception('Connection lost');
      connection.onclose(error);

      await nextRetryDelayCalledCompleter.future;
      nextRetryDelayCalledCompleter = Completer<void>();

      expect(hubConnection.state, HubConnectionState.reconnecting);
      expect(lastRetryCount, 0);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);

      await replacedStartCalledCompleter.future;
      replacedStartCalledCompleter = Completer<void>();

      // Manually fail handshake
      final m = predicate(
          (e) => '$e' == 'Exception: Server returned handshake error: invalid');
      final matcher = throwsA(m);
      expect(() => connection.receive({'error': 'invalid'}), matcher);

      await nextRetryDelayCalledCompleter.future;

      expect(hubConnection.state, HubConnectionState.reconnecting);
      expect(lastRetryCount, 1);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);

      await replacedStartCalledCompleter.future;

      // Manually complete handshake.
      connection.receive({});

      await reconnectedCompleter.future;

      expect(hubConnection.state, HubConnectionState.connected);
      expect(lastRetryCount, 1);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 1);
      expect(closeCount, 0);

      await hubConnection.stopAsync();

      expect(lastRetryCount, 1);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 1);
      expect(closeCount, 1);
    }, ['Server returned handshake error: invalid']);
  });
  test('# can be stopped while restarting the underlying connection', () async {
    await VerifyLogger.runAsync((logger) async {
      var onreconnectingCount = 0;
      var onreconnectedCount = 0;
      var closeCount = 0;

      final connection = TestConnection();
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), DefaultReconnectPolicy([0]));

      hubConnection.onreconnecting((_) => onreconnectingCount++);

      hubConnection.onreconnected((_) => onreconnectedCount++);

      hubConnection.onclose((_) => closeCount++);

      await hubConnection.startAsync();

      final stopCalledCompleter = Completer<void>();
      Future<void> stopFuture;

      connection.startFuture = () {
        stopCalledCompleter.complete();
        stopFuture = hubConnection.stopAsync();
        return Future.value();
      };

      // Typically this would be called by the transport
      connection.onclose(Exception('Connection lost'));

      await stopCalledCompleter.future;
      await stopFuture;

      expect(hubConnection.state, HubConnectionState.disconnected);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 1);
    });
  });
  test('# can be stopped during a restart handshake', () async {
    await VerifyLogger.runAsync((logger) async {
      final closedCompleter = Completer<void>();
      final nextRetryDelayCalledCompleter = Completer<void>();
      var onreconnectingCount = 0;
      var onreconnectedCount = 0;
      var closeCount = 0;

      // Disable autoHandshake in TestConnection
      final connection = TestConnection(false);
      final retryPolicy = MockRetryPolicy();
      when(retryPolicy.nextRetryDelayInMilliseconds(any)).thenAnswer((_) {
        nextRetryDelayCalledCompleter.complete();
        return 0;
      });
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), retryPolicy);

      hubConnection.onreconnecting((_) => onreconnectingCount++);

      hubConnection.onreconnected((_) {
        onreconnectedCount++;
        closedCompleter.complete();
      });

      hubConnection.onclose((_) => closeCount++);

      final startFuture = hubConnection.startAsync();
      // Manually complete handshake.
      connection.receive({});
      await startFuture;

      final replacedSendCalledCompleter = Completer<void>();
      connection.sendFuture = () {
        replacedSendCalledCompleter.complete();
        return Future.value();
      };

      // Typically this would be called by the transport
      connection.onclose(Exception('Connection lost'));

      await nextRetryDelayCalledCompleter.future;

      expect(hubConnection.state, HubConnectionState.reconnecting);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);

      // Wait for the handshake to actually started. Right now, we're awaiting the 0ms delay.
      await replacedSendCalledCompleter.future;

      await hubConnection.stopAsync();

      expect(hubConnection.state, HubConnectionState.disconnected);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 1);
    });
  });
  test('# can be stopped during a reconnect delay', () async {
    await VerifyLogger.runAsync((logger) async {
      final closedCompleter = Completer<void>();
      final nextRetryDelayCalledCompleter = Completer<void>();
      var onreconnectingCount = 0;
      var onreconnectedCount = 0;
      var closeCount = 0;

      final connection = TestConnection();
      final retryPolicy = MockRetryPolicy();
      when(retryPolicy.nextRetryDelayInMilliseconds(any)).thenAnswer((_) {
        nextRetryDelayCalledCompleter.complete();
        // 60s is hopefully longer than this test could ever take.
        return 60 * 1000;
      });
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), retryPolicy);

      hubConnection.onreconnecting((_) => onreconnectingCount++);

      hubConnection.onreconnected((_) {
        onreconnectedCount++;
        closedCompleter.complete();
      });

      hubConnection.onclose((_) => closeCount++);

      await hubConnection.startAsync();

      // Typically this would be called by the transport
      connection.onclose(Exception('Connection lost'));

      await nextRetryDelayCalledCompleter.future;

      expect(hubConnection.state, HubConnectionState.reconnecting);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 0);

      await hubConnection.stopAsync();

      expect(hubConnection.state, HubConnectionState.disconnected);
      expect(onreconnectingCount, 1);
      expect(onreconnectedCount, 0);
      expect(closeCount, 1);
    });
  });
  test(
      '# reconnect on close message if allowReconnect is true and auto reconnect is enabled',
      () async {
    await VerifyLogger.runAsync((logger) async {
      final connection = TestConnection();
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), DefaultReconnectPolicy());
      try {
        var isReconnecting = false;
        Exception reconnectingError;

        hubConnection.onreconnecting((e) {
          isReconnecting = true;
          reconnectingError = e;
        });

        await hubConnection.startAsync();

        connection.receive({
          'allowReconnect': true,
          'error': 'Error!',
          'type': MessageType.close,
        });

        expect(isReconnecting, true);
        expect('$reconnectingError',
            'Exception: Server returned an error on close: Error!');
      } finally {
        await hubConnection.stopAsync();
      }
    });
  });
  test(
      '# stop on close message if allowReconnect is missing and auto reconnect is enabled',
      () async {
    await VerifyLogger.runAsync((logger) async {
      final connection = TestConnection();
      final hubConnection = HubConnection.create(
          connection, logger, JsonHubProtocol(), DefaultReconnectPolicy());
      try {
        var isClosed = false;
        Exception closeError;
        hubConnection.onclose((e) {
          isClosed = true;
          closeError = e;
        });

        await hubConnection.startAsync();

        connection.receive({
          'error': 'Error!',
          'type': MessageType.close,
        });

        expect(isClosed, true);
        expect('$closeError',
            'Exception: Server returned an error on close: Error!');
      } finally {
        await hubConnection.stopAsync();
      }
    });
  });
}

class MockRetryPolicy extends Mock implements RetryPolicy {}
