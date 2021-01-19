import 'dart:async';
import 'dart:typed_data';

import 'package:cure/convert.dart';
import 'package:cure/signalr.dart';
import 'package:cure/src/signalr/connection.dart';
import 'package:cure/src/signalr/handshake_protocol.dart';
import 'package:cure/src/signalr/text_message_format.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'hub_connection_test.mocks.dart';
import 'test_connection.dart';
import 'utils.dart';

@GenerateMocks([StreamSubscriber, Logger])
void main() {
  group('# startAsync', () {
    test('# sends handshake message', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();
          expect(connection.sentData.length, 1);
          final obj = json.decode(connection.sentData[0] as String);
          final message = HandshakeRequestMessage.fromJSON(obj);
          expect(message.protocol, 'json');
          expect(message.version, 1);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# can change url', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();
          await hubConnection.stopAsync();
          hubConnection.baseURL = 'http://newurl.com';
          expect(hubConnection.baseURL, 'http://newurl.com');
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# can change url in onclose', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          expect(hubConnection.baseURL, 'http://example.com');
          hubConnection
              .onclose((_) => hubConnection.baseURL = 'http://newurl.com');

          await hubConnection.stopAsync();
          expect(hubConnection.baseURL, 'http://newurl.com');
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# changing url while active throws', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final m = predicate((e) =>
              '$e' ==
              'Exception: The HubConnection must be in the Disconnected or Reconnecting state to change the url.');
          final matcher = throwsA(m);
          expect(() => hubConnection.baseURL = 'http://newurl.com', matcher);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# state connected', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        expect(hubConnection.state, HubConnectionState.disconnected);
        try {
          await hubConnection.startAsync();
          expect(hubConnection.state, HubConnectionState.connected);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
  });
  group('# ping', () {
    test('# automatically sends multiple pings', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);

        hubConnection.keepAliveIntervalInMilliseconds = 5;

        try {
          await hubConnection.startAsync();
          await delayUntilAsync(500);

          final numPings = connection.sentData
              .where((item) =>
                  json.decode(item as String)['type'] ==
                  MessageType.ping.toJSON())
              .length;
          final matcher = greaterThanOrEqualTo(2);
          expect(numPings, matcher);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# does not send pings for connection with inherentKeepAlive',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection(true, true);
        final hubConnection = createHubConnection(connection, logger);

        hubConnection.keepAliveIntervalInMilliseconds = 5;

        try {
          await hubConnection.startAsync();
          await delayUntilAsync(500);

          final numPings = connection.sentData
              .where((item) =>
                  json.decode(item as String)['type'] ==
                  MessageType.ping.toJSON())
              .length;
          expect(numPings, 0);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
  });
  group('# stopAsync', () {
    test('# state disconnected', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        expect(hubConnection.state, HubConnectionState.disconnected);
        try {
          await hubConnection.startAsync();
          expect(hubConnection.state, HubConnectionState.connected);
        } finally {
          await hubConnection.stopAsync();
          expect(hubConnection.state, HubConnectionState.disconnected);
        }
      });
    });
  });
  group('# sendAsync', () {
    test('# sends a non blocking invocation', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();

        final hubConnection = createHubConnection(connection, logger);
        try {
          // We don't actually care to wait for the send.
          unawaited(hubConnection.sendAsync('testMethod', [
            'arg',
            42
          ]).catchError((_) =>
              {})); // Suppress exception and unhandled promise rejection warning.

          // Verify the message is sent
          expect(connection.sentData.length, 1);
          final obj = json.decode(connection.sentData[0] as String);
          final message = InvocationMessage.fromJSON(obj);
          expect(message.target, 'testMethod');
          expect(
            message.arguments,
            unorderedEquals(['arg', 42]),
          );
          expect(
            [
              message.headers,
              message.invocationId,
              message.streamIds,
            ],
            everyElement(isNull),
          );
        } finally {
          // Close the connection
          await hubConnection.stopAsync();
        }
      });
    });
    test('# works if argument is null', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();

        final hubConnection = createHubConnection(connection, logger);
        try {
          // We don't actually care to wait for the send.
          unawaited(
            hubConnection.sendAsync(
              'testMethod',
              [
                'arg',
                null,
              ],
            ).catchError((_) => {}),
          );

          // Verify the message is sent
          expect(connection.sentData.length, 1);
          final obj = json.decode(connection.sentData[0] as String);
          final message = InvocationMessage.fromJSON(obj);
          expect(message.target, 'testMethod');
          expect(
            message.arguments,
            unorderedEquals(['arg', null]),
          );
          expect(
            [
              message.headers,
              message.invocationId,
              message.streamIds,
            ],
            everyElement(isNull),
          );
        } finally {
          // Close the connection
          await hubConnection.stopAsync();
        }
      });
    });
  });
  group('# invokeAsync', () {
    test('# sends an invocation', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();

        final hubConnection = createHubConnection(connection, logger);
        try {
          // We don't actually care to wait for the send.
          unawaited(
            hubConnection
                .invokeAsync('testMethod', ['arg', 42]).catchError((_) => {}),
          );

          // Verify the message is sent
          expect(connection.sentData.length, 1);
          final obj = json.decode(connection.sentData[0] as String);
          final message = InvocationMessage.fromJSON(obj);
          expect(message.target, 'testMethod');
          expect(
            message.arguments,
            unorderedEquals(['arg', 42]),
          );
          expect(message.invocationId, connection.lastInvocationId);
          expect(
            [
              message.headers,
              message.streamIds,
            ],
            everyElement(isNull),
          );
        } finally {
          // Close the connection
          await hubConnection.stopAsync();
        }
      });
    });
    test('# can process handshake from text', () async {
      await VerifyLogger.runAsync((logger) async {
        var protocolCalled = false;

        final mockProtocol = TestProtocol(TransferFormat.text);
        mockProtocol.onreceive = (d) => protocolCalled = true;
        ;

        final connection = TestConnection(false);
        final hubConnection =
            createHubConnection(connection, logger, mockProtocol);
        try {
          var startCompleted = false;
          final startFuture =
              hubConnection.startAsync().then((_) => startCompleted = true);
          final data = '{}' + TextMessageFormat.recordSeparator;
          expect(startCompleted, false);

          connection.receiveText(data);
          await startFuture;

          // message only contained handshake response
          expect(protocolCalled, false);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# can process handshake from binary', () async {
      await VerifyLogger.runAsync((logger) async {
        var protocolCalled = false;

        final mockProtocol = TestProtocol(TransferFormat.binary);
        mockProtocol.onreceive = (d) => protocolCalled = true;

        final connection = TestConnection(false);
        final hubConnection =
            createHubConnection(connection, logger, mockProtocol);
        try {
          var startCompleted = false;
          final startFuture =
              hubConnection.startAsync().then((_) => startCompleted = true);
          expect(startCompleted, false);

          // handshake response + message separator
          final data = [0x7b, 0x7d, 0x1e];

          connection.receiveBinary(Uint8List.fromList(data));
          await startFuture;

          // message only contained handshake response
          expect(protocolCalled, false);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# can process handshake and additional messages from binary',
        () async {
      await VerifyLogger.runAsync((logger) async {
        late Uint8List receivedProcotolData;

        final mockProtocol = TestProtocol(TransferFormat.binary);
        mockProtocol.onreceive = (d) => receivedProcotolData = d as Uint8List;

        final connection = TestConnection(false);
        final hubConnection =
            createHubConnection(connection, logger, mockProtocol);
        try {
          var startCompleted = false;
          final startFuture =
              hubConnection.startAsync().then((_) => startCompleted = true);
          expect(startCompleted, false);

          // handshake response + message separator + message pack message
          final data = [
            0x7b,
            0x7d,
            0x1e,
            0x65,
            0x95,
            0x03,
            0x80,
            0xa1,
            0x30,
            0x01,
            0xd9,
            0x5d,
            0x54,
            0x68,
            0x65,
            0x20,
            0x63,
            0x6c,
            0x69,
            0x65,
            0x6e,
            0x74,
            0x20,
            0x61,
            0x74,
            0x74,
            0x65,
            0x6d,
            0x70,
            0x74,
            0x65,
            0x64,
            0x20,
            0x74,
            0x6f,
            0x20,
            0x69,
            0x6e,
            0x76,
            0x6f,
            0x6b,
            0x65,
            0x20,
            0x74,
            0x68,
            0x65,
            0x20,
            0x73,
            0x74,
            0x72,
            0x65,
            0x61,
            0x6d,
            0x69,
            0x6e,
            0x67,
            0x20,
            0x27,
            0x45,
            0x6d,
            0x70,
            0x74,
            0x79,
            0x53,
            0x74,
            0x72,
            0x65,
            0x61,
            0x6d,
            0x27,
            0x20,
            0x6d,
            0x65,
            0x74,
            0x68,
            0x6f,
            0x64,
            0x20,
            0x69,
            0x6e,
            0x20,
            0x61,
            0x20,
            0x6e,
            0x6f,
            0x6e,
            0x2d,
            0x73,
            0x74,
            0x72,
            0x65,
            0x61,
            0x6d,
            0x69,
            0x6e,
            0x67,
            0x20,
            0x66,
            0x61,
            0x73,
            0x68,
            0x69,
            0x6f,
            0x6e,
            0x2e,
          ];

          connection.receiveBinary(Uint8List.fromList(data));
          await startFuture;

          // left over data is the message pack message
          expect(receivedProcotolData.lengthInBytes, 102);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# can process handshake and additional messages from text', () async {
      await VerifyLogger.runAsync((logger) async {
        String? receivedProcotolData;

        final mockProtocol = TestProtocol(TransferFormat.text);
        mockProtocol.onreceive = (d) => receivedProcotolData = d as String;

        final connection = TestConnection(false);
        final hubConnection =
            createHubConnection(connection, logger, mockProtocol);
        try {
          var startCompleted = false;
          final startFuture =
              hubConnection.startAsync().then((_) => startCompleted = true);
          expect(startCompleted, false);

          final data = '{}' +
              TextMessageFormat.recordSeparator +
              '{\"type\":6}' +
              TextMessageFormat.recordSeparator;

          connection.receiveText(data);
          await startFuture;

          expect(receivedProcotolData,
              '{\"type\":6}' + TextMessageFormat.recordSeparator);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test(
        '# start completes if connection closes and handshake not received yet',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final mockProtocol = TestProtocol(TransferFormat.text);

        final connection = TestConnection(false);
        final hubConnection =
            createHubConnection(connection, logger, mockProtocol);
        try {
          var startCompleted = false;
          final startFuture =
              hubConnection.startAsync().then((_) => startCompleted = true);
          expect(startCompleted, false);

          await connection.stopAsync();
          try {
            await startFuture;
          } catch (_) {}
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# rejects the promise when an error is received', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final invokeFuture =
              hubConnection.invokeAsync('testMethod', ['arg', 42]);

          connection.receive({
            'type': MessageType.completion,
            'invocationId': connection.lastInvocationId,
            'error': 'foo'
          });

          final m = predicate((e) => '$e' == 'Exception: foo');
          final matcher = throwsA(m);
          await expectLater(invokeFuture, matcher);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# resolves the promise when a result is received', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final invokeFuture =
              hubConnection.invokeAsync('testMethod', ['arg', 42]);

          connection.receive({
            'type': MessageType.completion,
            'invocationId': connection.lastInvocationId,
            'result': 'foo'
          });

          expect(await invokeFuture, 'foo');
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# is able to send stream items to server with invoke', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final subject = Subject();
          final invokeFuture =
              hubConnection.invokeAsync('testMethod', ['arg', subject]);

          final obj1 = json.decode(connection.sentData[1] as String);
          final message1 = InvocationMessage.fromJSON(obj1);
          expect(message1.target, 'testMethod');
          expect(
            message1.arguments,
            unorderedEquals(['arg']),
          );
          expect(message1.invocationId, '1');
          expect(
            message1.streamIds,
            unorderedEquals(['0']),
          );
          expect(message1.headers, isNull);

          subject.next('item numero uno');
          final duration = Duration(milliseconds: 50);
          await Future.delayed(duration);

          final obj2 = json.decode(connection.sentData[2] as String);
          final message2 = StreamItemMessage.fromJSON(obj2);
          expect(message2.invocationId, '0');
          expect(message2.item, 'item numero uno');
          expect(message2.headers, isNull);

          connection.receive({
            'type': MessageType.completion,
            'invocationId': '1',
            'result': 'foo'
          });

          expect(await invokeFuture, 'foo');
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# is able to send stream items to server with send', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final subject = Subject();
          await hubConnection.sendAsync('testMethod', ['arg', subject]);

          final obj1 = json.decode(connection.sentData[1] as String);
          final message1 = InvocationMessage.fromJSON(obj1);
          expect(message1.target, 'testMethod');
          expect(
            message1.arguments,
            unorderedEquals(['arg']),
          );
          expect(
            message1.streamIds,
            unorderedEquals(['0']),
          );
          expect(
            [message1.headers, message1.invocationId],
            everyElement(isNull),
          );

          subject.next('item numero uno');
          final duration = Duration(milliseconds: 50);
          await Future.delayed(duration);

          final obj2 = json.decode(connection.sentData[2] as String);
          final message2 = StreamItemMessage.fromJSON(obj2);
          expect(message2.invocationId, '0');
          expect(message2.item, 'item numero uno');
          expect(message2.headers, isNull);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# is able to send stream items to server with stream', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          String? streamItem = '';
          Object? streamError;
          final subject = Subject();
          final subscriber = MockStreamSubscriber();
          when(subscriber.complete()).thenAnswer((_) {});
          when(subscriber.error(any)).thenAnswer((i) {
            final e = i.positionalArguments[0] as Exception?;
            streamError = e;
          });
          when(subscriber.next(any)).thenAnswer((i) {
            final item = i.positionalArguments[0];
            streamItem = item;
          });
          hubConnection
              .stream('testMethod', ['arg', subject]).subscribe(subscriber);

          final obj1 = json.decode(connection.sentData[1] as String);
          final message1 = StreamInvocationMessage.fromJSON(obj1);
          expect(message1.invocationId, '1');
          expect(message1.target, 'testMethod');
          expect(
            message1.arguments,
            unorderedEquals(['arg']),
          );
          expect(
            message1.streamIds,
            unorderedEquals(['0']),
          );
          expect(message1.headers, isNull);

          subject.next('item numero uno');
          final duration = Duration(milliseconds: 50);
          await Future.delayed(duration);
          final obj2 = json.decode(connection.sentData[2] as String);
          final message2 = StreamItemMessage.fromJSON(obj2);
          expect(message2.invocationId, '0');
          expect(message2.item, 'item numero uno');
          expect(message2.headers, isNull);

          connection.receive({
            'type': MessageType.streamItem,
            'invocationId': '1',
            'item': 'foo'
          });
          expect(streamItem, 'foo');

          expect(streamError, null);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# completes pending invocations when stopped', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();

        final hubConnection = createHubConnection(connection, logger);

        await hubConnection.startAsync();

        final invokeFuture = hubConnection.invokeAsync('testMethod');
        // HACK: CATCH EXCEPTION IMMEDIATELY
        unawaited(invokeFuture.catchError((_) {}));
        await hubConnection.stopAsync();

        final m = predicate((e) =>
            '$e' ==
            'Exception: Invocation canceled due to the underlying connection being closed.');
        final matcher = throwsA(m);
        await expectLater(invokeFuture, matcher);
      });
    });
    test('# completes pending invocations when connection is lost', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();

        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final invokeFuture = hubConnection.invokeAsync('testMethod');
          // Typically this would be called by the transport
          connection.onclose!(Exception('Connection lost'));

          final m = predicate((e) => '$e' == 'Exception: Connection lost');
          final matcher = throwsA(m);
          await expectLater(invokeFuture, matcher);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
  });
  group('# on', () {
    test('# invocations ignored in callbacks not registered', () async {
      await VerifyLogger.runAsync((logger) async {
        final warnings = <String>[];
        final wrappingLogger = MockLogger();
        when(wrappingLogger.log(any, any)).thenAnswer((i) {
          final logLevel = i.positionalArguments[0] as LogLevel;
          final message = i.positionalArguments[1] as String;

          if (logLevel == LogLevel.warning) {
            warnings.add(message);
          }
          logger.log(logLevel, message);
        });
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, wrappingLogger);
        try {
          await hubConnection.startAsync();

          connection.receive({
            'arguments': ['test'],
            'nonblocking': true,
            'target': 'message',
            'type': MessageType.invocation,
          });

          expect(warnings, ["No client method with the name 'message' found."]);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test(
        '# invocations ignored in callbacks that have registered then unregistered',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final warnings = <String>[];
        final wrappingLogger = MockLogger();
        when(wrappingLogger.log(any, any)).thenAnswer((i) {
          final logLevel = i.positionalArguments[0] as LogLevel;
          final message = i.positionalArguments[1] as String;

          if (logLevel == LogLevel.warning) {
            warnings.add(message);
          }
          logger.log(logLevel, message);
        });
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, wrappingLogger);
        try {
          await hubConnection.startAsync();

          final handler = (_) => {};
          hubConnection.on('message', handler);
          hubConnection.off('message', handler);

          connection.receive({
            'arguments': ['test'],
            'invocationId': '0',
            'nonblocking': true,
            'target': 'message',
            'type': MessageType.invocation,
          });

          expect(warnings, ["No client method with the name 'message' found."]);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# all handlers can be unregistered with just the method name',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          var count = 0;
          final handler = (_) => count++;
          final secondHandler = (_) => count++;
          hubConnection.on('inc', handler);
          hubConnection.on('inc', secondHandler);

          connection.receive({
            'arguments': [],
            'nonblocking': true,
            'target': 'inc',
            'type': MessageType.invocation,
          });

          hubConnection.off('inc');

          connection.receive({
            'arguments': [],
            'nonblocking': true,
            'target': 'inc',
            'type': MessageType.invocation,
          });

          expect(count, 2);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test(
        '# a single handler can be unregistered with the method name and handler',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          var count = 0;
          final handler = (_) => count++;
          final secondHandler = (_) => count++;
          hubConnection.on('inc', handler);
          hubConnection.on('inc', secondHandler);

          connection.receive({
            'arguments': [],
            'nonblocking': true,
            'target': 'inc',
            'type': MessageType.invocation,
          });

          hubConnection.off('inc', handler);

          connection.receive({
            'arguments': [],
            'nonblocking': true,
            'target': 'inc',
            'type': MessageType.invocation,
          });

          expect(count, 3);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test("# can't register the same handler multiple times", () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          var count = 0;
          final handler = (_) => count++;
          hubConnection.on('inc', handler);
          hubConnection.on('inc', handler);

          connection.receive({
            'arguments': [],
            'nonblocking': true,
            'target': 'inc',
            'type': MessageType.invocation,
          });

          expect(count, 1);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# callback invoked when servers invokes a method on the client',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          String? value = '';
          hubConnection.on('message', (v) => value = v[0] as String?);

          connection.receive({
            'arguments': ['test'],
            'nonblocking': true,
            'target': 'message',
            'type': MessageType.invocation,
          });

          expect(value, 'test');
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# stop on handshake error', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection(false);
        final hubConnection = createHubConnection(connection, logger);
        try {
          Object? closeError;
          hubConnection.onclose((e) => closeError = e);

          var startCompleted = false;
          final startFuture =
              hubConnection.startAsync().then((_) => startCompleted = true);
          expect(startCompleted, false);
          try {
            connection.receiveHandshakeResponse('Error!');
          } catch (_) {}
          final m = predicate((e) =>
              '$e' == 'Exception: Server returned handshake error: Error!');
          final matcher = throwsA(m);
          await expectLater(startFuture, matcher);

          expect(closeError, null);
        } finally {
          await hubConnection.stopAsync();
        }
      }, ['Server returned handshake error: Error!']);
    });
    test('# stop on close message', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          var isClosed = false;
          Object? closeError;
          hubConnection.onclose((e) {
            isClosed = true;
            closeError = e;
          });

          await hubConnection.startAsync();

          connection.receive({
            'type': MessageType.close,
          });

          expect(isClosed, true);
          expect(closeError, null);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# stop on error close message', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          var isClosed = false;
          Object? closeError;
          hubConnection.onclose((e) {
            isClosed = true;
            closeError = e;
          });

          await hubConnection.startAsync();

          // allowReconnect Should have no effect since auto reconnect is disabled by default.
          connection.receive({
            'allowReconnect': true,
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
    test('# can have multiple callbacks', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          var numInvocations1 = 0;
          var numInvocations2 = 0;
          hubConnection.on('message', (_) => numInvocations1++);
          hubConnection.on('message', (_) => numInvocations2++);

          connection.receive({
            'arguments': [],
            'nonblocking': true,
            'target': 'message',
            'type': MessageType.invocation,
          });

          expect(numInvocations1, 1);
          expect(numInvocations2, 1);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# can unsubscribe from on', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          var numInvocations = 0;
          final callback = (_) => numInvocations++;
          hubConnection.on('message', callback);

          connection.receive({
            'arguments': [],
            'nonblocking': true,
            'target': 'message',
            'type': MessageType.invocation,
          });

          hubConnection.off('message', callback);

          connection.receive({
            'arguments': [],
            'nonblocking': true,
            'target': 'message',
            'type': MessageType.invocation,
          });

          expect(numInvocations, 1);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# unsubscribing from non-existing callbacks no-ops', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          hubConnection.off('_', (_) => {});
          hubConnection.on('message', (_) => {});
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# using null/undefined for methodName or method no-ops', () async {
      await VerifyLogger.runAsync((logger) async {
        final warnings = <String>[];
        final wrappingLogger = MockLogger();
        when(wrappingLogger.log(any, any)).thenAnswer((i) {
          final logLevel = i.positionalArguments[0] as LogLevel;
          final message = i.positionalArguments[1] as String;

          if (logLevel == LogLevel.warning) {
            warnings.add(message);
          }
          logger.log(logLevel, message);
        });

        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, wrappingLogger);
        try {
          await hubConnection.startAsync();

          // invoke a method to make sure we are not trying to use null/undefined
          connection.receive({
            'arguments': [],
            'invocationId': '0',
            'nonblocking': true,
            'target': 'message',
            'type': MessageType.invocation,
          });

          hubConnection.off('message', null);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
  });
  group('# stream', () {
    test('# sends an invocation', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();

        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          hubConnection.stream('testStream', ['arg', 42]);

          // Verify the message is sent (+ handshake)
          expect(connection.sentData.length, 2);
          final obj = json.decode(connection.sentData[1] as String);
          final message = StreamInvocationMessage.fromJSON(obj);
          expect(message.invocationId, connection.lastInvocationId);
          expect(message.target, 'testStream');
          expect(
            message.arguments,
            unorderedEquals(['arg', 42]),
          );
          expect(
            [message.headers, message.streamIds],
            everyElement(isNull),
          );

          // Close the connection
          await hubConnection.stopAsync();
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# completes with an error when an error is yielded', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final observer = TestObserver();
          hubConnection.stream('testMethod', ['arg', 42]).subscribe(observer);

          connection.receive({
            'type': MessageType.completion,
            'invocationId': connection.lastInvocationId,
            'error': 'foo'
          });

          final matcher = predicate((e) => '$e' == 'Exception: foo');
          await expectLater(observer.completed, throwsA(matcher));
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# completes the observer when a completion is received', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final observer = TestObserver();
          hubConnection.stream('testMethod', ['arg', 42]).subscribe(observer);

          connection.receive({
            'type': MessageType.completion,
            'invocationId': connection.lastInvocationId
          });

          expect(await observer.completed, []);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# completes pending streams when stopped', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();

        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final observer = TestObserver();
          hubConnection.stream('testMethod').subscribe(observer);

          await hubConnection.stopAsync();

          final m = predicate((e) =>
              '$e' ==
              'Exception: Invocation canceled due to the underlying connection being closed.');
          final matcher = throwsA(m);

          await expectLater(observer.completed, matcher);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# completes pending streams when connection is lost', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();

        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final observer = TestObserver();
          hubConnection.stream('testMethod').subscribe(observer);

          // Typically this would be called by the transport
          connection.onclose!(Exception('Connection lost'));

          final m = predicate((e) => '$e' == 'Exception: Connection lost');
          final matcher = throwsA(m);
          await expectLater(observer.completed, matcher);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# yields items as they arrive', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final observer = TestObserver();
          hubConnection.stream('testMethod').subscribe(observer);

          connection.receive({
            'type': MessageType.streamItem,
            'invocationId': connection.lastInvocationId,
            'item': 1
          });
          expect(observer.itemsReceived, [1]);

          connection.receive({
            'type': MessageType.streamItem,
            'invocationId': connection.lastInvocationId,
            'item': 2
          });
          expect(observer.itemsReceived, [1, 2]);

          connection.receive({
            'type': MessageType.streamItem,
            'invocationId': connection.lastInvocationId,
            'item': 3
          });
          expect(observer.itemsReceived, [1, 2, 3]);

          connection.receive({
            'type': MessageType.completion,
            'invocationId': connection.lastInvocationId
          });
          expect(await observer.completed, [1, 2, 3]);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# does not require error function registered', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();

        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();
          final subscriber = NullSubscriber();
          hubConnection.stream('testMethod').subscribe(subscriber);

          // Typically this would be called by the transport
          // triggers observer.error()
          connection.onclose!(Exception('Connection lost'));
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# does not require complete function registered', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();

        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();
          final subscriber = NullSubscriber();
          hubConnection.stream('testMethod').subscribe(subscriber);

          // Send completion to trigger observer.complete()
          // Expectation is connection.receive will not throw
          connection.receive({
            'type': MessageType.completion,
            'invocationId': connection.lastInvocationId
          });
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# can be canceled', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();

          final observer = TestObserver();
          final subscription =
              hubConnection.stream('testMethod').subscribe(observer);

          connection.receive({
            'type': MessageType.streamItem,
            'invocationId': connection.lastInvocationId,
            'item': 1
          });
          expect(observer.itemsReceived, [1]);

          subscription.dispose();

          connection.receive({
            'type': MessageType.streamItem,
            'invocationId': connection.lastInvocationId,
            'item': 2
          });
          // Observer should no longer receive messages
          expect(observer.itemsReceived, [1]);

          // Close message sent asynchronously so we need to wait
          await delayUntilAsync(1000, () => connection.sentData.length == 3);
          // Verify the cancel is sent (+ handshake)
          expect(connection.sentData.length, 3);
          final obj = json.decode(connection.sentData[2] as String);
          final message = CancelInvocationMessage.fromJSON(obj);
          expect(message.invocationId, connection.lastInvocationId);
          expect(message.headers, isNull);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
  });
  group('# onclose', () {
    test('# can have multiple callbacks', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        await hubConnection.startAsync();

        try {
          var invocations = 0;
          hubConnection.onclose((e) => invocations++);
          hubConnection.onclose((e) => invocations++);
          // Typically this would be called by the transport
          connection.onclose!(null);
          expect(invocations, 2);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# callbacks receive error', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        await hubConnection.startAsync();

        try {
          Object? error;
          hubConnection.onclose((e) => error = e);

          // Typically this would be called by the transport
          connection.onclose!(Exception('Test error.'));
          expect('$error', 'Exception: Test error.');
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# state disconnected', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        await hubConnection.startAsync();

        try {
          HubConnectionState? state;
          hubConnection.onclose((e) => state = hubConnection.state);
          // Typically this would be called by the transport
          connection.onclose!(null);

          expect(state, HubConnectionState.disconnected);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
  });
  group('# keepAlive', () {
    test('# can receive ping messages', () async {
      await VerifyLogger.runAsync((logger) async {
        // Receive the ping mid-invocation so we can see that the rest of the flow works fine

        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          await hubConnection.startAsync();
          final invokeFuture =
              hubConnection.invokeAsync('testMethod', ['arg', 42]);

          connection.receive({'type': MessageType.ping});
          connection.receive({
            'type': MessageType.completion,
            'invocationId': connection.lastInvocationId,
            'result': 'foo'
          });

          expect(await invokeFuture, 'foo');
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# does not terminate if messages are received', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          final timeoutInMilliseconds = 400;
          hubConnection.serverTimeoutInMilliseconds = timeoutInMilliseconds;

          final completer = Completer();
          hubConnection.onclose((e) => completer.complete(e));

          await hubConnection.startAsync();

          final duration = Duration(milliseconds: 10);
          final pingInterval = Timer.periodic(duration,
              (timer) => connection.receive({'type': MessageType.ping}));

          await delayUntilAsync(timeoutInMilliseconds * 2);

          await connection.stopAsync();
          pingInterval.cancel();

          final error = await completer.future;

          expect(error, null);
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
    test('# terminates if no messages received within timeout interval',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = TestConnection();
        final hubConnection = createHubConnection(connection, logger);
        try {
          hubConnection.serverTimeoutInMilliseconds = 100;

          final completer = Completer();
          hubConnection.onclose((e) => completer.complete(e));

          await hubConnection.startAsync();

          final error = await completer.future;

          expect('$error',
              'Exception: Server timeout elapsed without receiving a message from the server.');
        } finally {
          await hubConnection.stopAsync();
        }
      });
    });
  });
}

HubConnection createHubConnection(Connection connection,
    [Logger? logger, HubProtocol? protocol]) {
  return HubConnection.create(
      connection, logger ?? NullLogger(), protocol ?? JsonHubProtocol());
}

class TestProtocol implements HubProtocol {
  @override
  String name;
  @override
  int version;
  @override
  TransferFormat transferFormat;

  void Function(Object data)? onreceive;

  TestProtocol(this.transferFormat)
      : name = 'TestProtocol',
        version = 1,
        onreceive = null;

  @override
  List<HubMessage> parseMessages(Object input, Logger logger) {
    onreceive?.call(input);

    return [];
  }

  @override
  Object writeMessage(HubMessage message) {
    return message;
  }
}

class TestObserver implements StreamSubscriber<dynamic> {
  @override
  bool? closed;
  List<dynamic> itemsReceived;
  final Completer<List<dynamic>> _itemsSource;

  Future<List<dynamic>> get completed {
    return _itemsSource.future;
  }

  TestObserver()
      : closed = false,
        itemsReceived = [],
        _itemsSource = Completer() {
    unawaited(completed.catchError((_) => []));
  }

  @override
  void next(dynamic value) {
    itemsReceived.add(value);
  }

  @override
  void error(Object error) {
    _itemsSource.completeError(error);
  }

  @override
  void complete() {
    _itemsSource.complete(itemsReceived);
  }
}

class NullSubscriber<T> extends Fake implements StreamSubscriber<T> {
  static final _instance = NullSubscriber<Object>._();

  NullSubscriber._();

  factory NullSubscriber() => _instance as NullSubscriber<T>;

  @override
  void next(T value) {}
  @override
  void error(Object err) {}
  @override
  void complete() {}
}
