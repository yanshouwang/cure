import 'dart:async';

import 'package:cure/signalr.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'test_http_client.dart';

final longPollingNegotiateResponse = NegotiateResponse(
  availableTransports: [
    AvailableTransport(
      HTTPTransportType.longPolling,
      [TransferFormat.text, TransferFormat.binary],
    ),
  ],
  connectionId: 'abc123',
  connectionToken: '123abc',
  negotiateVersion: 1,
);

HTTPConnectionOptions get commonHTTPOptions =>
    HTTPConnectionOptions(logMessageContent: true);

// We use a different mapping table here to help catch any unintentional breaking changes.
final ExpectedLogLevelMappings = {
  'trace': LogLevel.trace,
  'debug': LogLevel.debug,
  'info': LogLevel.information,
  'information': LogLevel.information,
  'warn': LogLevel.warning,
  'warning': LogLevel.warning,
  'error': LogLevel.error,
  'critical': LogLevel.critical,
  'none': LogLevel.none
};

class CapturingConsole implements Console {
  List<dynamic> messages = [];

  @override
  void error(dynamic message) {
    messages.add(CapturingConsole._stripPrefix(message));
  }

  @override
  void warn(dynamic message) {
    messages.add(CapturingConsole._stripPrefix(message));
  }

  @override
  void info(dynamic message) {
    messages.add(CapturingConsole._stripPrefix(message));
  }

  @override
  void log(dynamic message) {
    messages.add(CapturingConsole._stripPrefix(message));
  }

  static dynamic _stripPrefix(dynamic input) {
    if (input is String) {
      final from = RegExp(r'\[.*\]\s+');
      input = input.replaceAll(from, '');
    }
    return input;
  }
}

void main() {
  for (final val in [null, '']) {
    test('# WithUrl throws if url is $val', () {
      final builder = HubConnectionBuilder();
      final other = RegExp(
          r"Exception: The 'url' argument (is required|should not be empty).");
      final m = predicate((e) => '$e'.contains(other));
      final matcher = throwsA(m);
      expect(() => builder.withURL(val), matcher);
    });
  }
  test('# WithHubProtocol throws if protocol is null', () {
    final builder = HubConnectionBuilder();
    final m = predicate(
        (e) => '$e' == "Exception: The 'protocol' argument is required.");
    final matcher = throwsA(m);
    expect(() => builder.withHubProtocol(null), matcher);
  });
  test('# Builds HubConnection with HTTPConnection using provided URL',
      () async {
    await VerifyLogger.runAsync((logger) async {
      final pollSent = Completer<HTTPRequest>();
      final pollCompleted = Completer<HTTPResponse>();
      final testClient =
          createTestClient(pollSent, pollCompleted.future).on((r, next) {
        // Respond from the poll with the handshake response
        pollCompleted.complete(HTTPResponse(204, 'No Content', '{}'));
        return HTTPResponse(202);
      }, 'POST', 'http://example.com?id=123abc');
      final connection = createConnectionBuilder()
          .withURL(
              'http://example.com',
              commonHTTPOptions
                ..httpClient = testClient
                ..logger = logger)
          .build();

      final m = predicate((e) =>
          '$e' ==
          'Exception: The underlying connection was closed before the hub handshake could complete.');
      final matcher1 = throwsA(m);
      await expectLater(connection.startAsync(), matcher1);
      expect(connection.state, HubConnectionState.disconnected);
      final re = RegExp(r'http://example\.com\?id=123abc.*');
      final matcher2 = matches(re);
      expect((await pollSent.future).url, matcher2);
    });
  });
  test('# Can configure transport type', () async {
    final protocol = TestProtocol();

    final builder = createConnectionBuilder()
        .withURL('http://example.com', HTTPTransportType.webSockets)
        .withHubProtocol(protocol);
    expect(
        builder.httpConnectionOptions.transport, HTTPTransportType.webSockets);
  });
  test('# Can configure hub protocol', () async {
    await VerifyLogger.runAsync((logger) async {
      final protocol = TestProtocol();

      final pollSent = Completer<HTTPRequest>();
      final pollCompleted = Completer<HTTPResponse>();
      HTTPRequest negotiateRequest;
      final testClient = createTestClient(pollSent, pollCompleted.future).on(
        (r, next) {
          // Respond from the poll with the handshake response
          negotiateRequest = r;
          pollCompleted.complete(HTTPResponse(204, 'No Content', '{}'));
          return HTTPResponse(202);
        },
        'POST',
        'http://example.com?id=123abc',
      );

      final connection = createConnectionBuilder()
          .withURL(
              'http://example.com',
              commonHTTPOptions
                ..httpClient = testClient
                ..logger = logger)
          .withHubProtocol(protocol)
          .build();

      final m = predicate((e) =>
          '$e' ==
          'Exception: The underlying connection was closed before the hub handshake could complete.');
      final matcher = throwsA(m);
      await expectLater(connection.startAsync(), matcher);
      expect(connection.state, HubConnectionState.disconnected);

      expect(negotiateRequest.content,
          '{"protocol":"${protocol.name}","version":1}\x1E');
    });
  });
  group('# ConfigureLogging', () {
    void testLogLevels(Logger logger, LogLevel minLevel) {
      final capturingConsole = CapturingConsole();
      (logger as ConsoleLogger).outputConsole = capturingConsole;

      for (var level = LogLevel.trace.index;
          level < LogLevel.none.index;
          level++) {
        final message = 'Message at LogLevel.${LogLevel.values[level]}';
        final expectedMessage =
            '${LogLevel.values[level]}: Message at LogLevel.${LogLevel.values[level]}';
        logger.log(LogLevel.values[level], message);

        var matcher = contains(expectedMessage);
        if (level >= minLevel.index) {
          expect(capturingConsole.messages, matcher);
        } else {
          matcher = isNot(matcher);
          expect(capturingConsole.messages, matcher);
        }
      }
    }

    test('# Throws if logger is null', () {
      final builder = HubConnectionBuilder();
      final m = predicate(
          (e) => '$e' == "Exception: The 'logging' argument is required.");
      final matcher = throwsA(m);
      expect(() => builder.configureLogging(null), matcher);
    });

    [
      LogLevel.none,
      LogLevel.critical,
      LogLevel.error,
      LogLevel.warning,
      LogLevel.information,
      LogLevel.debug,
      LogLevel.trace,
    ].forEach((minLevel) {
      test('# Accepts LogLevel.${minLevel}', () async {
        final builder = HubConnectionBuilder().configureLogging(minLevel);

        final matcher = isA<ConsoleLogger>();
        expect(builder.logger, matcher);

        testLogLevels(builder.logger, minLevel);
      });
    });

    test('# Allows logger to be replaced', () async {
      var loggedMessages = 0;
      final logger = MockLogger();
      when(logger.log(any, any)).thenAnswer((_) => loggedMessages += 1);
      final pollSent = Completer<HTTPRequest>();
      final pollCompleted = Completer<HTTPResponse>();
      final testClient =
          createTestClient(pollSent, pollCompleted.future).on((r, next) {
        // Respond from the poll with the handshake response
        pollCompleted.complete(HTTPResponse(204, 'No Content', '{}'));
        return HTTPResponse(202);
      }, 'POST', 'http://example.com?id=123abc');
      final connection = createConnectionBuilder(logger)
          .withURL(
              'http://example.com', commonHTTPOptions..httpClient = testClient)
          .build();

      try {
        await connection.startAsync();
      } catch (_) {
        // Ignore failures
      }

      final matcher = greaterThan(0);
      expect(loggedMessages, matcher);
    });
    test('# Configures logger for both HTTPConnection and HubConnection',
        () async {
      final pollSent = Completer<HTTPRequest>();
      final pollCompleted = Completer<HTTPResponse>();
      final testClient =
          createTestClient(pollSent, pollCompleted.future).on((r, next) {
        // Respond from the poll with the handshake response
        pollCompleted.complete(HTTPResponse(204, 'No Content', '{}'));
        return HTTPResponse(202);
      }, 'POST', 'http://example.com?id=123abc');
      final logger = CaptureLogger();
      final connection = createConnectionBuilder(logger)
          .withURL(
              'http://example.com', commonHTTPOptions..httpClient = testClient)
          .build();

      try {
        await connection.startAsync();
      } catch (_) {
        // Ignore failures
      }

      // A HubConnection message
      // An HTTPConnection message
      final matcher = containsAll([
        'Starting HubConnection.',
        "Starting connection with transfer format 'Text'."
      ]);
      expect(logger.messages, matcher);
    });
    test('# Does not replace HTTPConnectionOptions logger if provided',
        () async {
      final pollSent = Completer<HTTPRequest>();
      final pollCompleted = Completer<HTTPResponse>();
      final testClient =
          createTestClient(pollSent, pollCompleted.future).on((r, next) {
        // Respond from the poll with the handshake response
        pollCompleted.complete(HTTPResponse(204, 'No Content', '{}'));
        return HTTPResponse(202);
      }, 'POST', 'http://example.com?id=123abc');
      final hubConnectionLogger = CaptureLogger();
      final httpConnectionLogger = CaptureLogger();
      final connection = createConnectionBuilder(hubConnectionLogger)
          .withURL(
              'http://example.com',
              HTTPConnectionOptions(
                httpClient: testClient,
                logger: httpConnectionLogger,
              ))
          .build();

      try {
        await connection.startAsync();
      } catch (_) {
        // Ignore failures
      }

      var matcher = contains('Starting HubConnection.');
      // A HubConnection message
      expect(hubConnectionLogger.messages, matcher);
      matcher = isNot(matcher);
      expect(httpConnectionLogger.messages, matcher);

      matcher = contains("Starting connection with transfer format 'Text'.");
      // An HTTPConnection message
      expect(httpConnectionLogger.messages, matcher);
      matcher = isNot(matcher);
      expect(hubConnectionLogger.messages, matcher);
    });
  });
  test('# ReconnectPolicy undefined by default', () {
    final builder = HubConnectionBuilder().withURL('http://example.com');
    expect(builder.reconnectPolicy, isNull);
  });
  test('# WithAutomaticReconnect throws if reconnectPolicy is already set', () {
    final builder = HubConnectionBuilder().withAutomaticReconnect();
    final m = predicate(
        (e) => '$e' == 'Exception: A reconnectPolicy has already been set.');
    final matcher = throwsA(m);
    expect(() => builder.withAutomaticReconnect(), matcher);
  });
  test(
      '# WithAutomaticReconnect uses default retryDelays when called with no arguments',
      () {
    // From DefaultReconnectPolicy.ts
    final DEFAULT_RETRY_DELAYS_IN_MILLISECONDS = [0, 2000, 10000, 30000, null];
    final builder = HubConnectionBuilder().withAutomaticReconnect();

    var retryCount = 0;
    for (final delay in DEFAULT_RETRY_DELAYS_IN_MILLISECONDS) {
      final retryContext = RetryContext(retryCount++, 0, Exception());

      expect(builder.reconnectPolicy.nextRetryDelayInMilliseconds(retryContext),
          delay);
    }
  });
  test('# WithAutomaticReconnect uses custom retryDelays when provided', () {
    final customRetryDelays = [3, 1, 4, 1, 5, 9];
    final builder =
        HubConnectionBuilder().withAutomaticReconnect(customRetryDelays);

    var retryCount = 0;
    for (final delay in customRetryDelays) {
      final retryContext = RetryContext(retryCount++, 0, Exception());

      expect(builder.reconnectPolicy.nextRetryDelayInMilliseconds(retryContext),
          delay);
    }

    final retryContextFinal = RetryContext(retryCount++, 0, Exception());

    expect(
        builder.reconnectPolicy.nextRetryDelayInMilliseconds(retryContextFinal),
        null);
  });
  test('# WithAutomaticReconnect uses a custom IRetryPolicy when provided', () {
    final customRetryDelays = [127, 0, 0, 1];
    final builder = HubConnectionBuilder()
        .withAutomaticReconnect(DefaultReconnectPolicy(customRetryDelays));

    var retryCount = 0;
    for (final delay in customRetryDelays) {
      final retryContext = RetryContext(retryCount++, 0, Exception());

      expect(builder.reconnectPolicy.nextRetryDelayInMilliseconds(retryContext),
          delay);
    }

    final retryContextFinal = RetryContext(retryCount++, 0, Exception());

    expect(
        builder.reconnectPolicy.nextRetryDelayInMilliseconds(retryContextFinal),
        null);
  });
}

class MockLogger extends Mock implements Logger {}

class CaptureLogger implements Logger {
  List<String> messages;

  CaptureLogger() : messages = [];

  @override
  void log(LogLevel logLevel, String message) {
    messages.add(message);
  }
}

class TestProtocol implements HubProtocol {
  @override
  String name;
  @override
  int version;
  @override
  TransferFormat transferFormat;

  TestProtocol()
      : name = 'test',
        version = 1,
        transferFormat = TransferFormat.text;

  @override
  List<HubMessage> parseMessages(dynamic input, Logger logger) {
    throw Exception('Method not implemented.');
  }

  @override
  dynamic writeMessage(HubMessage message) {
    // builds ping message in the 'hubConnection' finalructor
    return '';
  }
}

HubConnectionBuilder createConnectionBuilder([Logger logger]) {
  // We don't want to spam test output with logs. This can be changed as needed
  return HubConnectionBuilder().configureLogging(logger ?? NullLogger());
}

TestHTTPClient createTestClient(
    Completer<HTTPRequest> pollSent, Future<HTTPResponse> pollCompleted,
    [dynamic negotiateResponse]) {
  var firstRequest = true;
  return TestHTTPClient()
      .on(
    (r, next) => negotiateResponse ?? longPollingNegotiateResponse,
    'POST',
    'http://example.com/negotiate?negotiateVersion=1',
  )
      .on(
    (r, next) {
      if (firstRequest) {
        firstRequest = false;
        return HTTPResponse(200);
      } else {
        pollSent.complete(r);
        return pollCompleted;
      }
    },
    'GET',
    RegExp(r'http://example\.com\?id=123abc&_=.*'),
  );
}
