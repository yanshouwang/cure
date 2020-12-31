import 'package:cure/signalr.dart';
import 'package:mockito/mockito.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'test_connection.dart';
import 'utils.dart';

void main() {
  test('# Send invocation', () async {
    await VerifyLogger.runAsync((logger) async {
      final connection = TestConnection();

      final hubConnection = createHubConnection(connection, logger);
      try {
        // We don't actually care to wait for the send.
        // Suppress exception and unhandled promise rejection warning.
        unawaited(hubConnection.sendAsync('target', [1]).catchError((_) => {}));

        // Verify the message is sent
        expect(connection.sentData.length, 1);
        expect(connection.parsedSentData[0]['type'],
            MessageType.invocation.toJSON());
        expect(connection.sentData[0].length, 44);
      } finally {
        // Close the connection
        await hubConnection.stopAsync();
      }
    });
  });
  test('# Invoke invocation', () async {
    await VerifyLogger.runAsync((logger) async {
      final connection = TestConnection();

      final hubConnection = createHubConnection(connection, logger);
      try {
        // We don't actually care to wait for the invoke.
        // tslint:disable-next-line:no-floating-promises
        unawaited(hubConnection.invokeAsync('target', [1]).catchError((_) =>
            {})); // Suppress exception and unhandled promise rejection warning.

        // Verify the message is sent
        expect(connection.sentData.length, 1);
        expect(connection.parsedSentData[0]['type'],
            MessageType.invocation.toJSON());
        expect((connection.sentData[0] as String).length, 63);
      } finally {
        // Close the connection
        await hubConnection.stopAsync();
      }
    });
  });
  test('# Stream invocation', () async {
    await VerifyLogger.runAsync((logger) async {
      final connection = TestConnection();

      final hubConnection = createHubConnection(connection, logger);
      try {
        hubConnection.stream('target', [1]);

        // Verify the message is sent
        expect(connection.sentData.length, 1);
        expect(connection.parsedSentData[0]['type'],
            MessageType.streamInvocation.toJSON());
        expect((connection.sentData[0] as String).length, 63);
      } finally {
        // Close the connection
        await hubConnection.stopAsync();
      }
    });
  });
  test('# Upload invocation', () async {
    await VerifyLogger.runAsync((logger) async {
      final connection = TestConnection();

      final hubConnection = createHubConnection(connection, logger);
      try {
        // We don't actually care to wait for the invoke.
        // tslint:disable-next-line:no-floating-promises
        unawaited(hubConnection.invokeAsync('target', [
          1,
          Subject()
        ]).catchError((_) =>
            {})); // Suppress exception and unhandled promise rejection warning.

        // Verify the message is sent
        expect(connection.sentData.length, 1);
        expect(connection.parsedSentData[0]['type'],
            MessageType.invocation.toJSON());
        expect((connection.sentData[0] as String).length, 81);
      } finally {
        // Close the connection
        await hubConnection.stopAsync();
      }
    });
  });
  test('# Upload stream invocation', () async {
    await VerifyLogger.runAsync((logger) async {
      final connection = TestConnection();

      final hubConnection = createHubConnection(connection, logger);
      try {
        hubConnection.stream('target', [1, Subject()]);

        // Verify the message is sent
        expect(connection.sentData.length, 1);
        expect(connection.parsedSentData[0]['type'],
            MessageType.streamInvocation.toJSON());
        expect((connection.sentData[0] as String).length, 81);
      } finally {
        // Close the connection
        await hubConnection.stopAsync();
      }
    });
  });
  test('# Completion message', () async {
    await VerifyLogger.runAsync((logger) async {
      final connection = TestConnection();

      final hubConnection = createHubConnection(connection, logger);
      try {
        final subject = Subject();
        hubConnection.stream('target', [1, subject]);
        subject.complete();

        await delayUntilAsync(1000, () => connection.sentData.length == 2);

        // Verify the message is sent
        expect(connection.sentData.length, 2);
        expect(connection.parsedSentData[1]['type'],
            MessageType.completion.toJSON());
        expect((connection.sentData[1] as String).length, 29);
      } finally {
        // Close the connection
        await hubConnection.stopAsync();
      }
    });
  });
  test('# Cancel message', () async {
    await VerifyLogger.runAsync((logger) async {
      final connection = TestConnection();

      final hubConnection = createHubConnection(connection, logger);
      try {
        hubConnection
            .stream('target', [1])
            .subscribe(FakeSubscriber())
            .dispose();

        await delayUntilAsync(1000, () => connection.sentData.length == 2);

        // Verify the message is sent
        expect(connection.sentData.length, 2);
        expect(connection.parsedSentData[1]['type'],
            MessageType.cancelInvocation.toJSON());
        expect((connection.sentData[1] as String).length, 29);
      } finally {
        // Close the connection
        await hubConnection.stopAsync();
      }
    });
  });
}

HubConnection createHubConnection(Connection connection,
    [Logger logger, HubProtocol protocol]) {
  return HubConnection.create(
      connection, logger ?? NullLogger(), protocol ?? JSONHubProtocol());
}

class FakeSubscriber extends Fake implements StreamSubscriber {
  @override
  void complete() {}
  @override
  void error(error) {}
  @override
  void next(value) {}
}
