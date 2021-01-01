import 'dart:async';
import 'dart:typed_data';

import 'package:cure/signalr.dart';
import 'package:cure/sse.dart';
import 'package:cure/ws.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'test_http_client.dart';
import 'test_web_socket.dart';
import 'utils.dart';

HTTPConnectionOptions get commonOptions =>
    HTTPConnectionOptions(logger: NullLogger());

const DEFAULT_CONNECTION_ID = 'abc123';
const DEFAULT_CONNECTION_TOKEN = '123abc';

NegotiateResponse get DEFAULT_NEGOTIATE_RESPONSE => NegotiateResponse(
      availableTransports: [
        AvailableTransport(
          HTTPTransportType.webSockets,
          [TransferFormat.text, TransferFormat.binary],
        ),
        AvailableTransport(
          HTTPTransportType.serverSentEvents,
          [TransferFormat.text],
        ),
        AvailableTransport(
          HTTPTransportType.longPolling,
          [TransferFormat.text, TransferFormat.binary],
        ),
      ],
      connectionId: DEFAULT_CONNECTION_ID,
      connectionToken: DEFAULT_CONNECTION_TOKEN,
      negotiateVersion: 1,
    );

void main() {
  group('# HTTPConnection', () {
    test(
        '# Cannot be created with relative url if document object is not present',
        () {
      final m = predicate((e) => '$e' == "Exception: Cannot resolve '/test'.");
      final matcher = throwsA(m);
      expect(() => HTTPConnection('/test', commonOptions), matcher);
    });
    test(
        '# Cannot be created with relative url if window object is not present',
        () {
      final m = predicate((e) => '$e' == "Exception: Cannot resolve '/test'.");
      final matcher = throwsA(m);
      expect(() => HTTPConnection('/test', commonOptions), matcher);
    });
    test('# Starting connection fails if getting id fails', () async {
      await VerifyLogger.runAsync((logger) async {
        final error = Exception('error');
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient()
                .on((r, next) => Future.error(error), 'POST')
                .on((r, next) => '', 'GET'),
            logger: logger);

        final connection = HTTPConnection('http://tempuri.org', options);

        await expectLater(
            connection.startAsync(TransferFormat.text), throwsA(error));
      }, [
        'Failed to start the connection: Exception: error',
        'Failed to complete negotiation with the server: Exception: error'
      ]);
    });
    test('# Cannot start a running connection', () async {
      await VerifyLogger.runAsync((logger) async {
        final transport = FakeTransport1();
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient()
                .on((r, next) => DEFAULT_NEGOTIATE_RESPONSE, 'POST'),
            logger: logger,
            transport: transport);

        final connection = HTTPConnection('http://tempuri.org', options);
        try {
          await connection.startAsync(TransferFormat.text);

          final m = predicate((e) =>
              '$e' ==
              "Exception: Cannot start an HTTPConnection that is not in the 'disconnected' state.");
          final matcher = throwsA(m);
          await expectLater(
              connection.startAsync(TransferFormat.text), matcher);
        } finally {
          options.transport.onclose.call(null);
          await connection.stopAsync();
        }
      });
    });
    test('# Can start a stopped connection', () async {
      await VerifyLogger.runAsync((logger) async {
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient().on((r, next) {
              final error = Exception('reached negotiate.');
              return Future.error(error);
            }, 'POST').on((r, next) => '', 'GET'),
            logger: logger);

        final connection = HTTPConnection('http://tempuri.org', options);

        final m = predicate((e) => '$e' == 'Exception: reached negotiate.');
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);
      }, [
        'Failed to complete negotiation with the server: Exception: reached negotiate.',
        'Failed to start the connection: Exception: reached negotiate.'
      ]);
    });
    test('# Can stop a starting connection', () async {
      await VerifyLogger.runAsync((logger) async {
        final options = HTTPConnectionOptions(logger: logger);
        final httpClient = TestHTTPClient();
        options.httpClient = httpClient;
        final connection = HTTPConnection('http://tempuri.org', options);
        httpClient.on((r, next) async {
          await connection.stopAsync();
          return '{}';
        }, 'POST').on((r, next) async {
          await connection.stopAsync();
          return '';
        }, 'GET');

        final m = predicate((e) =>
            '$e' ==
            'Exception: The connection was stopped during negotiation.');
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);
      }, [
        'Failed to start the connection: Exception: The connection was stopped during negotiation.'
      ]);
    });
    test('# Cannot send with an un-started connection', () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = HTTPConnection('http://tempuri.org');

        final m = predicate((e) =>
            '$e' ==
            "Exception: Cannot send data if the connection is not in the 'Connected' State.");
        final matcher = throwsA(m);
        await expectLater(connection.sendAsync('YAO MING'), matcher);
      });
    });
    test("# Sending before start doesn't throw synchronously", () async {
      await VerifyLogger.runAsync((logger) async {
        final connection = HTTPConnection('http://tempuri.org');

        try {
          await connection.sendAsync('test').catchError((e) => {});
        } catch (e) {
          expect(false, true);
        }
      });
    });
    test('# Cannot be started if negotiate returns non 200 response', () async {
      await VerifyLogger.runAsync((logger) async {
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient()
                .on((r, next) => HTTPResponse(999), 'POST')
                .on((r, next) => '', 'GET'),
            logger: logger);

        final connection = HTTPConnection('http://tempuri.org', options);
        final m = predicate((e) =>
            '$e' ==
            "Exception: Unexpected status code returned from negotiate '999'");
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);
      }, [
        "Failed to start the connection: Exception: Unexpected status code returned from negotiate '999'"
      ]);
    });
    test('# All transport failure errors get aggregated', () async {
      await VerifyLogger.runAsync((loggerImpl) async {
        var negotiateCount = 0;
        final options = HTTPConnectionOptions(
            webSocket: (url, {protocols, headers}) =>
                throw Exception('There was an error with the transport.'),
            httpClient: TestHTTPClient()
                .on((r, next) {
                  negotiateCount++;
                  return DEFAULT_NEGOTIATE_RESPONSE;
                }, 'POST')
                .on((r, next) => HTTPResponse(200), 'GET')
                .on((r, next) => HTTPResponse(202), 'DELETE'),
            logger: loggerImpl,
            transport: HTTPTransportType.webSockets);

        final connection = HTTPConnection('http://tempuri.org', options);
        final m = predicate((e) =>
            '$e' ==
            "Exception: Unable to connect to the server with any of the available transports. WebSockets failed: Exception: There was an error with the transport. ServerSentEvents failed: Exception: 'ServerSentEvents' is disabled by the client. LongPolling failed: Exception: 'LongPolling' is disabled by the client.");
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);

        expect(negotiateCount, 1);
      }, [
        "Failed to start the transport 'WebSockets': Exception: There was an error with the transport.",
        "Failed to start the connection: Exception: Unable to connect to the server with any of the available transports. WebSockets failed: Exception: There was an error with the transport. ServerSentEvents failed: Exception: 'ServerSentEvents' is disabled by the client. LongPolling failed: Exception: 'LongPolling' is disabled by the client."
      ]);
    });
    test(
        '# Negotiate called again when transport fails to start and falls back',
        () async {
      await VerifyLogger.runAsync((loggerImpl) async {
        var negotiateCount = 0;
        final options = HTTPConnectionOptions(
            eventSource: (_, {headers, withCredentials}) =>
                throw Exception("Don't allow ServerSentEvents."),
            webSocket: (_, {protocols, headers}) =>
                throw Exception("Don't allow Websockets."),
            httpClient: TestHTTPClient()
                .on((r, next) {
                  negotiateCount++;
                  return DEFAULT_NEGOTIATE_RESPONSE;
                }, 'POST')
                .on((r, next) => HTTPResponse(200), 'GET')
                .on((r, next) => HTTPResponse(202), 'DELETE'),
            logger: loggerImpl,
            transport: HTTPTransportType.webSockets.value |
                HTTPTransportType.serverSentEvents.value);

        final connection = HTTPConnection('http://tempuri.org', options);
        final m = predicate((e) =>
            '$e' ==
            "Exception: Unable to connect to the server with any of the available transports. WebSockets failed: Exception: Don't allow Websockets. ServerSentEvents failed: Exception: Don't allow ServerSentEvents. LongPolling failed: Exception: 'LongPolling' is disabled by the client.");
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);

        expect(negotiateCount, 2);
      }, [
        "Failed to start the transport 'WebSockets': Exception: Don't allow Websockets.",
        "Failed to start the transport 'ServerSentEvents': Exception: Don't allow ServerSentEvents.",
        "Failed to start the connection: Exception: Unable to connect to the server with any of the available transports. WebSockets failed: Exception: Don't allow Websockets. ServerSentEvents failed: Exception: Don't allow ServerSentEvents. LongPolling failed: Exception: 'LongPolling' is disabled by the client."
      ]);
    });
    test('# Failed re-negotiate fails start', () async {
      await VerifyLogger.runAsync((logger) async {
        var negotiateCount = 0;
        final options = HTTPConnectionOptions(
            eventSource: (_, {headers, withCredentials}) =>
                throw Exception("Don't allow ServerSentEvents."),
            webSocket: (_, {protocols, headers}) =>
                throw Exception("Don't allow Websockets."),
            httpClient: TestHTTPClient()
                .on((r, next) {
                  negotiateCount++;
                  if (negotiateCount == 2) {
                    throw Exception('negotiate failed');
                  }
                  return DEFAULT_NEGOTIATE_RESPONSE;
                }, 'POST')
                .on((r, next) => HTTPResponse(200), 'GET')
                .on((r, next) => HTTPResponse(202), 'DELETE'),
            logger: logger);

        final connection = HTTPConnection('http://tempuri.org', options);
        final m = predicate((e) => '$e' == 'Exception: negotiate failed');
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);

        expect(negotiateCount, 2);
      }, [
        "Failed to start the transport 'WebSockets': Exception: Don't allow Websockets.",
        'Failed to complete negotiation with the server: Exception: negotiate failed',
        'Failed to start the connection: Exception: negotiate failed'
      ]);
    });
    test('# Can stop a non-started connection', () async {
      await VerifyLogger.runAsync((logger) async {
        final options = HTTPConnectionOptions(logger: logger);
        final connection = HTTPConnection('http://tempuri.org', options);
        await connection.stopAsync();
      });
    });
    test('# Start throws after all transports fail', () async {
      await VerifyLogger.runAsync((logger) async {
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient()
                .on((r, next) => NegotiateResponse(connectionId: '42'), 'POST')
                .on((r, next) => throw Exception('fail'), 'GET'),
            logger: logger);

        final connection =
            HTTPConnection('http://tempuri.org?q=myData', options);
        final m = predicate((e) =>
            '$e' ==
            'Exception: None of the transports supported by the client are supported by the server.');
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);
      }, [
        'Failed to start the connection: Exception: None of the transports supported by the client are supported by the server.'
      ]);
    });
    test("# Preserves user's query string", () async {
      await VerifyLogger.runAsync((logger) async {
        final transport = FakeTransport2();

        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient()
                .on((r, next) => '{ \"connectionId\": \"42\" }', 'POST')
                .on((r, next) => '', 'GET'),
            logger: logger,
            transport: transport);

        final connection =
            HTTPConnection('http://tempuri.org?q=myData', options);
        try {
          final startFuture = connection.startAsync(TransferFormat.text);

          final matcher = completion('http://tempuri.org?q=myData&id=42');
          await expectLater(transport.connectUrl.future, matcher);

          await startFuture;
        } finally {
          options.transport.onclose.call(null);
          await connection.stopAsync();
        }
      });
    });

    eachEndpoint((given, expected) {
      test(
          "# Negotiate request for '$given' puts 'negotiate' at the end of the path",
          () async {
        await VerifyLogger.runAsync((logger) async {
          final negotiate = Completer<String>();
          final options = HTTPConnectionOptions(
              httpClient: TestHTTPClient()
                  .on((r, next) {
                    negotiate.complete(r.url);
                    throw HTTPException(
                        "We don't care how this turns out", 500);
                  }, 'POST')
                  .on((r, next) => HTTPResponse(204), 'GET')
                  .on((r, next) => HTTPResponse(202), 'DELETE'),
              logger: logger);

          final connection = HTTPConnection(given, options);
          try {
            final startFuture = connection.startAsync(TransferFormat.text);

            final matcher1 = completion(expected);
            await expectLater(negotiate.future, matcher1);

            final m = predicate((e) =>
                '$e' ==
                "HTTPException: We don't care how this turns out\nstatusCode: 500");
            final matcher2 = throwsA(m);
            await expectLater(startFuture, matcher2);
          } finally {
            await connection.stopAsync();
          }
        }, [
          "Failed to complete negotiation with the server: HTTPException: We don't care how this turns out\nstatusCode: 500",
          "Failed to start the connection: HTTPException: We don't care how this turns out\nstatusCode: 500"
        ]);
      });
    });

    eachTransport((transport) {
      test(
          '# Cannot be started if requested $transport transport not available on server',
          () async {
        await VerifyLogger.runAsync((logger) async {
          // Clone the default response
          var negotiateResponse = DEFAULT_NEGOTIATE_RESPONSE;

          // Remove the requested transport from the response
          negotiateResponse.availableTransports
              .removeWhere((e) => e.transport == transport);

          final options = HTTPConnectionOptions(
              httpClient: TestHTTPClient()
                  .on((r, next) => negotiateResponse, 'POST')
                  .on((r, next) => HTTPResponse(204), 'GET'),
              logger: logger,
              transport: transport);

          final connection = HTTPConnection('http://tempuri.org', options);

          final m = predicate((e) =>
              '$e' ==
              "Exception: Unable to connect to the server with any of the available transports. ${negotiateResponse.availableTransports[0].transport} failed: Exception: '${negotiateResponse.availableTransports[0].transport}' is disabled by the client. ${negotiateResponse.availableTransports[1].transport} failed: Exception: '${negotiateResponse.availableTransports[1].transport}' is disabled by the client.");
          final matcher = throwsA(m);
          await expectLater(
              connection.startAsync(TransferFormat.text), matcher);
        }, [
          RegExp(
              r"Failed to start the connection: Exception: Unable to connect to the server with any of the available transports. [a-zA-Z]+\b failed: Exception: '[a-zA-Z]+\b' is disabled by the client. [a-zA-Z]+\b failed: Exception: '[a-zA-Z]+\b' is disabled by the client.")
        ]);
      });
    });

    for (var entry in [MapEntry('null', null), MapEntry('0', 0)]) {
      test('# Can be started when transport mask is ${entry.key}', () async {
        FakeWebSocket1.wsSet = Completer();
        final ws = (url, {protocols, headers}) => FakeWebSocket1();

        await VerifyLogger.runAsync((logger) async {
          final options = HTTPConnectionOptions(
            webSocket: ws,
            httpClient: TestHTTPClient()
                .on((r, next) => DEFAULT_NEGOTIATE_RESPONSE, 'POST')
                .on((r, next) => HTTPResponse(200), 'GET')
                .on((r, next) => HTTPResponse(202), 'DELETE'),
            logger: logger,
            transport: entry.value,
          );

          final connection = HTTPConnection('http://tempuri.org', options);

          final startFuture = connection.startAsync(TransferFormat.text);
          await FakeWebSocket1.wsSet.future;
          await FakeWebSocket1.ws.sync.waitToContinueAsync();
          FakeWebSocket1.ws.websocketOpen();
          await startFuture;

          await connection.stopAsync();
        });
      });
    }

    test(
        '# Cannot be started if no transport available on server and no transport requested',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient()
                .on((r, next) => NegotiateResponse(connectionId: '42'), 'POST')
                .on((r, next) => '', 'GET'),
            logger: logger);

        final connection = HTTPConnection('http://tempuri.org', options);
        final m = predicate((e) =>
            '$e' ==
            'Exception: None of the transports supported by the client are supported by the server.');
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);
      }, [
        'Failed to start the connection: Exception: None of the transports supported by the client are supported by the server.'
      ]);
    });
    test(
        '# Does not send negotiate request if WebSockets transport requested explicitly and skipNegotiation is true',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final options = HTTPConnectionOptions(
          webSocket: (url, {protocols, headers}) =>
              throw Exception('WebSocket constructor called.'),
          httpClient: TestHTTPClient()
              .on((r, next) => throw Exception('Should not be called'), 'POST')
              .on((r, next) => throw Exception('Should not be called'), 'GET'),
          logger: logger,
          skipNegotiation: true,
          transport: HTTPTransportType.webSockets,
        );

        final connection = HTTPConnection('http://tempuri.org', options);
        final m = predicate(
            (e) => '$e' == 'Exception: WebSocket constructor called.');
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);
      }, [
        'Failed to start the connection: Exception: WebSocket constructor called.'
      ]);
    });
    test(
        '# Does not start non WebSockets transport if requested explicitly and skipNegotiation is true',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient(),
            logger: logger,
            skipNegotiation: true,
            transport: HTTPTransportType.longPolling);

        final connection = HTTPConnection('http://tempuri.org', options);
        final m = predicate((e) =>
            '$e' ==
            'Exception: Negotiation can only be skipped when using the WebSocket transport directly.');
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);
      }, [
        'Failed to start the connection: Exception: Negotiation can only be skipped when using the WebSocket transport directly.'
      ]);
    });
    test('# Redirects to url when negotiate returns it', () async {
      await VerifyLogger.runAsync((logger) async {
        // HACK: Looks like we shoud wait until Client received the last request.
        final completer = Completer();

        var firstNegotiate = true;
        var firstPoll = true;
        final httpClient = TestHTTPClient().on(
          (r, next) {
            if (firstNegotiate) {
              firstNegotiate = false;
              return NegotiateResponse(url: 'https://another.domain.url/chat');
            }
            return NegotiateResponse(
              availableTransports: [
                AvailableTransport(
                  HTTPTransportType.longPolling,
                  [TransferFormat.text],
                )
              ],
              connectionId: '0rge0d00-0040-0030-0r00-000q00r00e00',
            );
          },
          'POST',
          RegExp('/negotiate'),
        ).on((r, next) {
          if (firstPoll) {
            firstPoll = false;
            return '';
          }
          return HTTPResponse(204, 'No Content', '');
        }, 'GET').on((r, next) => HTTPResponse(202), 'DELETE');

        final options = HTTPConnectionOptions(
          httpClient: httpClient,
          logger: logger,
          transport: HTTPTransportType.longPolling,
        );

        final connection = HTTPConnection('http://tempuri.org', options);
        connection.onclose = (error) => completer.complete();
        try {
          await connection.startAsync(TransferFormat.text);
          await completer.future;

          expect(httpClient.requests.length, 4);
          expect(httpClient.requests[0].url,
              'http://tempuri.org/negotiate?negotiateVersion=1');
          expect(httpClient.requests[1].url,
              'https://another.domain.url/chat/negotiate?negotiateVersion=1');
          final matcher = matches(
              r'^https://another\.domain\.url/chat\?id=0rge0d00-0040-0030-0r00-000q00r00e00');
          expect(httpClient.requests[2].url, matcher);
          expect(httpClient.requests[3].url, matcher);
        } finally {
          await connection.stopAsync();
        }
      });
    });
    test('# Fails to start if negotiate redirects more than 100 times',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final httpClient = TestHTTPClient().on(
          (r, next) =>
              NegotiateResponse(url: 'https://another.domain.url/chat'),
          'POST',
          RegExp('/negotiate'),
        );

        final options = HTTPConnectionOptions(
            httpClient: httpClient,
            logger: logger,
            transport: HTTPTransportType.longPolling);

        final connection = HTTPConnection('http://tempuri.org', options);
        final m = predicate(
            (e) => '$e' == 'Exception: Negotiate redirection limit exceeded.');
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);
      }, [
        'Failed to start the connection: Exception: Negotiate redirection limit exceeded.'
      ]);
    });
    test('# Redirects to url when negotiate returns it with access token',
        () async {
      await VerifyLogger.runAsync((logger) async {
        // HACK: Looks like we shoud wait until Client received the last request.
        final completer = Completer();

        var firstNegotiate = true;
        var firstPoll = true;
        final httpClient = TestHTTPClient().on((r, next) {
          if (firstNegotiate) {
            firstNegotiate = false;

            if (r.headers != null &&
                r.headers['Authorization'] != 'Bearer firstSecret') {
              return HTTPResponse(401, 'Unauthorized', '');
            }

            return NegotiateResponse(
              url: 'https://another.domain.url/chat',
              accessToken: 'secondSecret',
            );
          }

          if (r.headers != null &&
              r.headers['Authorization'] != 'Bearer secondSecret') {
            return HTTPResponse(401, 'Unauthorized', '');
          }

          return NegotiateResponse(
            availableTransports: [
              AvailableTransport(
                HTTPTransportType.longPolling,
                [TransferFormat.text],
              )
            ],
            connectionId: '0rge0d00-0040-0030-0r00-000q00r00e00',
          );
        }, 'POST', RegExp('/negotiate')).on((r, next) {
          if (r.headers != null &&
              r.headers['Authorization'] != 'Bearer secondSecret') {
            return HTTPResponse(401, 'Unauthorized', '');
          }

          if (firstPoll) {
            firstPoll = false;
            return '';
          }
          return HTTPResponse(204, 'No Content', '');
        }, 'GET').on((r, next) => HTTPResponse(202), 'DELETE');

        final options = HTTPConnectionOptions(
          accessTokenFactory: () => Future.value('firstSecret'),
          httpClient: httpClient,
          logger: logger,
          transport: HTTPTransportType.longPolling,
        );

        final connection = HTTPConnection('http://tempuri.org', options);
        connection.onclose = (e) => completer.complete();
        try {
          await connection.startAsync(TransferFormat.text);
          await completer.future;

          expect(httpClient.requests.length, 4);
          expect(httpClient.requests[0].url,
              'http://tempuri.org/negotiate?negotiateVersion=1');
          expect(httpClient.requests[1].url,
              'https://another.domain.url/chat/negotiate?negotiateVersion=1');
          final matcher = matches(
              r'^https://another\.domain\.url/chat\?id=0rge0d00-0040-0030-0r00-000q00r00e00');
          expect(httpClient.requests[2].url, matcher);
          expect(httpClient.requests[3].url, matcher);
        } finally {
          await connection.stopAsync();
        }
      });
    });
    test('# Throws error if negotiate response has error', () async {
      await VerifyLogger.runAsync((logger) async {
        final httpClient = TestHTTPClient().on(
          (r, next) => NegotiateResponse(error: 'Negotiate error.'),
          'POST',
          RegExp('/negotiate'),
        );

        final options = HTTPConnectionOptions(
            httpClient: httpClient,
            logger: logger,
            transport: HTTPTransportType.longPolling);

        final connection = HTTPConnection('http://tempuri.org', options);
        final m = predicate((e) => '$e' == 'Exception: Negotiate error.');
        final matcher = throwsA(m);
        await expectLater(connection.startAsync(TransferFormat.text), matcher);
      }, ['Failed to start the connection: Exception: Negotiate error.']);
    });
    test(
        '# Authorization header removed when token factory returns null and using LongPolling',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final availableTransport = AvailableTransport(
          HTTPTransportType.longPolling,
          [TransferFormat.text],
        );

        // HACK: Looks like we shoud wait until Client received the last request.
        final completer = Completer();

        var httpClientGetCount = 0;
        var accessTokenFactoryCount = 0;
        final options = HTTPConnectionOptions(
          accessTokenFactory: () {
            accessTokenFactoryCount++;
            if (accessTokenFactoryCount == 1) {
              return Future.value('A token value');
            } else {
              // Return a null value after the first call to test the header being removed
              return Future.value(null);
            }
          },
          httpClient: TestHTTPClient()
              .on(
                  (r, next) => NegotiateResponse(
                        connectionId: '42',
                        availableTransports: [availableTransport],
                      ),
                  'POST')
              .on((r, next) {
            httpClientGetCount++;
            final authorizationValue = r.headers['Authorization'];
            if (httpClientGetCount == 1) {
              if (authorizationValue != null) {
                fail(
                    'First long poll request should have a authorization header.');
              }
              // First long polling request must succeed so start completes
              return '';
            } else {
              // Check second long polling request has its header removed
              if (authorizationValue != null) {
                fail(
                    'Second long poll request should have no authorization header.');
              }
              completer.complete();
            }
          }, 'GET').on((r, next) => HTTPResponse(202), 'DELETE'),
          logger: logger,
        );

        final connection = HTTPConnection('http://tempuri.org', options);
        try {
          await connection.startAsync(TransferFormat.text);
          await completer.future;

          final matcher = greaterThanOrEqualTo(2);
          expect(httpClientGetCount, matcher);
          expect(accessTokenFactoryCount, matcher);
        } finally {
          await connection.stopAsync();
        }
      });
    });
    test('# Sets inherentKeepAlive feature when using LongPolling', () async {
      await VerifyLogger.runAsync((logger) async {
        final availableTransport = AvailableTransport(
          HTTPTransportType.longPolling,
          [TransferFormat.text],
        );

        var httpClientGetCount = 0;
        final options = HTTPConnectionOptions(
          httpClient: TestHTTPClient()
              .on(
                  (r, next) => NegotiateResponse(
                        connectionId: '42',
                        availableTransports: [availableTransport],
                      ),
                  'POST')
              .on((r, next) {
            httpClientGetCount++;
            if (httpClientGetCount == 1) {
              // First long polling request must succeed so start completes
              return '';
            }
          }, 'GET').on((r, next) => HTTPResponse(202), 'DELETE'),
          logger: logger,
        );

        final connection = HTTPConnection('http://tempuri.org', options);
        try {
          await connection.startAsync(TransferFormat.text);
          expect(connection.features['inherentKeepAlive'], true);
        } finally {
          await connection.stopAsync();
        }
      });
    });
    test('# Transport handlers set before start', () async {
      await VerifyLogger.runAsync((logger) async {
        final availableTransport = AvailableTransport(
          HTTPTransportType.longPolling,
          [TransferFormat.text],
        );
        var handlersSet = false;

        var httpClientGetCount = 0;
        final httpClient = TestHTTPClient();
        final options =
            HTTPConnectionOptions(httpClient: httpClient, logger: logger);

        final connection = HTTPConnection('http://tempuri.org', options);
        httpClient
            .on(
                (r, next) => NegotiateResponse(
                      connectionId: '42',
                      availableTransports: [availableTransport],
                    ),
                'POST')
            .on((r, next) {
          httpClientGetCount++;
          if (httpClientGetCount == 1) {
            if (connection.transport.onreceive != null &&
                connection.transport.onclose != null) {
              handlersSet = true;
            }
            // First long polling request must succeed so start completes
            return '';
          }
        }, 'GET').on((r, next) => HTTPResponse(202), 'DELETE');
        connection.onreceive = (data) => null;
        try {
          await connection.startAsync(TransferFormat.text);
        } finally {
          await connection.stopAsync();
        }

        expect(handlersSet, true);
      });
    });
    test('# Transport handlers set before start for custom transports',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final availableTransport = AvailableTransport(
          HTTPTransportType.none,
          [TransferFormat.text],
        );
        final transport = FakeTransport3();
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient().on(
                (r, next) => NegotiateResponse(
                      connectionId: '42',
                      availableTransports: [availableTransport],
                    ),
                'POST'),
            logger: logger,
            transport: transport);

        final connection = HTTPConnection('http://tempuri.org', options);
        connection.onreceive = (data) => null;
        try {
          await connection.startAsync(TransferFormat.text);
        } finally {
          await connection.stopAsync();
        }

        expect(transport.handlersSet, true);
      });
    });
    test('# Missing negotiateVersion ignores connectionToken', () async {
      await VerifyLogger.runAsync((logger) async {
        final availableTransport = AvailableTransport(
          HTTPTransportType.none,
          [TransferFormat.text],
        );
        final transport = FakeTransport4();
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient().on(
                (r, next) => NegotiateResponse(
                      connectionId: '42',
                      connectionToken: 'token',
                      availableTransports: [availableTransport],
                    ),
                'POST'),
            logger: logger,
            transport: transport);

        final connection = HTTPConnection('http://tempuri.org', options);
        connection.onreceive = (data) => null;
        try {
          await connection.startAsync(TransferFormat.text);
          expect(connection.connectionId, '42');
        } finally {
          await connection.stopAsync();
        }
      });
    });
    test('# Negotiate version 0 ignores connectionToken', () async {
      await VerifyLogger.runAsync((logger) async {
        final availableTransport = AvailableTransport(
          HTTPTransportType.none,
          [TransferFormat.text],
        );
        final transport = FakeTransport4();
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient().on(
                (r, next) => NegotiateResponse(
                      connectionId: '42',
                      connectionToken: 'token',
                      negotiateVersion: 0,
                      availableTransports: [availableTransport],
                    ),
                'POST'),
            logger: logger,
            transport: transport);

        final connection = HTTPConnection('http://tempuri.org', options);
        connection.onreceive = (data) => null;
        try {
          await connection.startAsync(TransferFormat.text);
          expect(connection.connectionId, '42');
        } finally {
          await connection.stopAsync();
        }
      });
    });
    test(
        '# Negotiate version 1 uses connectionToken for url and connectionId for property',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final availableTransport = AvailableTransport(
          HTTPTransportType.none,
          [TransferFormat.text],
        );
        final transport = FakeTransport5();
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient().on(
                (r, next) => NegotiateResponse(
                      connectionId: '42',
                      connectionToken: 'token',
                      negotiateVersion: 1,
                      availableTransports: [availableTransport],
                    ),
                'POST'),
            logger: logger,
            transport: transport);

        final connection = HTTPConnection('http://tempuri.org', options);
        connection.onreceive = (data) => null;
        try {
          await connection.startAsync(TransferFormat.text);
          expect(connection.connectionId, '42');
          expect(transport.connectUrl, 'http://tempuri.org?id=token');
        } finally {
          await connection.stopAsync();
        }
      });
    });
    test('# NegotiateVersion query string not added if already present',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final fakeTransport = FakeTransport2();

        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient()
                .on((r, next) => '{ \"connectionId\": \"42\" }', 'POST',
                    'http://tempuri.org/negotiate?negotiateVersion=42')
                .on((r, next) => '', 'GET'),
            logger: logger,
            transport: fakeTransport);

        final connection =
            HTTPConnection('http://tempuri.org?negotiateVersion=42', options);
        try {
          final startFuture = connection.startAsync(TransferFormat.text);

          final connectUrl = await fakeTransport.connectUrl.future;
          expect(connectUrl, 'http://tempuri.org?negotiateVersion=42&id=42');

          await startFuture;
        } finally {
          options.transport.onclose(null);
          await connection.stopAsync();
        }
      });
    });
    test(
        '# NegotiateVersion query string not added if already present after redirect',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final fakeTransport = FakeTransport2();

        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient()
                .on((r, next) => '{ \"url\": \"http://redirect.org\" }', 'POST',
                    'http://tempuri.org/negotiate?negotiateVersion=1')
                .on(
                  (r, next) => '{ \"connectionId\": \"42\"}',
                  'POST',
                  'http://redirect.org/negotiate?negotiateVersion=1',
                )
                .on((r, next) => '', 'GET'),
            logger: logger,
            transport: fakeTransport);

        final connection = HTTPConnection('http://tempuri.org', options);
        try {
          final startFuture = connection.startAsync(TransferFormat.text);

          final connectUrl = await fakeTransport.connectUrl.future;
          expect(connectUrl, 'http://redirect.org?id=42');

          await startFuture;
        } finally {
          options.transport.onclose(null);
          await connection.stopAsync();
        }
      });
    });
    test('# Fallback changes connectionId property', () async {
      await VerifyLogger.runAsync((logger) async {
        // HACK: Looks like we shoud wait until Client received the last request.
        final completer = Completer();

        final availableTransports = [
          AvailableTransport(
            HTTPTransportType.webSockets,
            [TransferFormat.text],
          ),
          AvailableTransport(
            HTTPTransportType.longPolling,
            [TransferFormat.text],
          ),
        ];
        var negotiateCount = 0;
        var getCount = 0;
        HTTPConnection connection;
        String connectionId;
        final options = HTTPConnectionOptions(
            webSocket: (url, {protocols, headers}) =>
                TestWebSocket(url, protocols: protocols, headers: headers),
            httpClient: TestHTTPClient().on((r, next) {
              negotiateCount++;
              return NegotiateResponse(
                connectionId: negotiateCount.toString(),
                connectionToken: 'token',
                negotiateVersion: 1,
                availableTransports: availableTransports,
              );
            }, 'POST').on((r, next) {
              getCount++;
              if (getCount == 1) {
                return HTTPResponse(200);
              }
              connectionId = connection.connectionId;
              return HTTPResponse(204);
            }, 'GET').on((r, next) => HTTPResponse(202), 'DELETE'),
            logger: logger);

        TestWebSocket.wsSet = Completer();

        connection = HTTPConnection('http://tempuri.org', options);
        connection.onclose = (e) => completer.complete();
        final startFuture = connection.startAsync(TransferFormat.text);

        await TestWebSocket.wsSet.future;
        await TestWebSocket.ws.closeSet.future;
        final error = Exception('There was an error with the transport.');
        TestWebSocket.ws.onerror(error);

        try {
          await startFuture;
          await completer.future;
          // ignore: empty_catches
        } catch (e) {}

        expect(negotiateCount, 2);
        expect(connectionId, '2');
      }, [
        "Failed to start the transport 'WebSockets': Exception: There was an error with the transport."
      ]);
    });
    test('# User agent header set on negotiate', () async {
      await VerifyLogger.runAsync((logger) async {
        var userAgentValue = '';
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient().on((r, next) {
              userAgentValue = r.headers['User-Agent'];
              return HTTPResponse(200, '', '{\"error\":\"nope\"}');
            }, 'POST'),
            logger: logger);

        final connection = HTTPConnection('http://tempuri.org', options);
        try {
          await connection.startAsync(TransferFormat.text);
          // ignore: empty_catches
        } catch (e) {} finally {
          await connection.stopAsync();
        }

        final userAgent = getUserAgentHeader();
        expect(userAgentValue, userAgent.value);
      }, ['Failed to start the connection: Exception: nope']);
    });
    test('# Overwrites library headers with user headers on negotiate',
        () async {
      await VerifyLogger.runAsync((logger) async {
        final headers = {'User-Agent': 'Custom Agent', 'X-HEADER': 'VALUE'};
        final options = HTTPConnectionOptions(
            headers: headers,
            httpClient: TestHTTPClient().on((r, next) {
              expect(r.headers, headers);
              return HTTPResponse(200, '', '{\"error\":\"nope\"}');
            }, 'POST'),
            logger: logger);

        final connection = HTTPConnection('http://tempuri.org', options);
        try {
          await connection.startAsync(TransferFormat.text);
          // ignore: empty_catches
        } catch (e) {} finally {
          await connection.stopAsync();
        }
      }, ['Failed to start the connection: Exception: nope']);
    });
    test('# LogMessageContent displays correctly with binary data', () async {
      await VerifyLogger.runAsync((logger) async {
        final availableTransport = AvailableTransport(
          HTTPTransportType.longPolling,
          [TransferFormat.text, TransferFormat.binary],
        );

        var sentMessage = '';
        final captureLogger = MockLogger();
        when(captureLogger.log(any, any)).thenAnswer((i) {
          final logLevel = i.positionalArguments[0];
          final message = i.positionalArguments[1];
          if (logLevel == LogLevel.trace &&
              message.indexOf('data of length') > 0) {
            sentMessage = message;
          }

          logger.log(logLevel, message);
        });

        var httpClientGetCount = 0;
        final options = HTTPConnectionOptions(
            httpClient: TestHTTPClient()
                .on(
                    (r, next) => NegotiateResponse(
                          connectionId: '42',
                          availableTransports: [availableTransport],
                        ),
                    'POST')
                .on((r, next) {
              httpClientGetCount++;
              if (httpClientGetCount == 1) {
                // First long polling request must succeed so start completes
                return '';
              }
              return Future.value();
            }, 'GET').on((r, next) => HTTPResponse(202), 'DELETE'),
            logMessageContent: true,
            logger: captureLogger,
            transport: HTTPTransportType.longPolling);

        final connection = HTTPConnection('http://tempuri.org', options);
        connection.onreceive = (data) => null;
        try {
          await connection.startAsync(TransferFormat.binary);
          final data =
              Uint8List.fromList([0x68, 0x69, 0x20, 0x3a, 0x29]).buffer;
          await connection.sendAsync(data);
        } finally {
          await connection.stopAsync();
        }

        expect(sentMessage,
            "(LongPolling transport) sending data. Binary data of length 5. Content: '0x68 0x69 0x20 0x3a 0x29'.");
      });
    });
    test('# Send after restarting connection works', () async {
      await VerifyLogger.runAsync((logger) async {
        final options = HTTPConnectionOptions(
            webSocket: (url, {protocols, headers}) =>
                TestWebSocket(url, protocols: protocols, headers: headers),
            httpClient: TestHTTPClient()
                .on((r, next) => DEFAULT_NEGOTIATE_RESPONSE, 'POST')
                .on((r, next) => '', 'GET'),
            logger: logger);

        final connection = HTTPConnection('http://tempuri.org', options);
        final closeCompleter = Completer<void>();
        connection.onclose = (e) => closeCompleter.complete();

        TestWebSocket.wsSet = Completer();
        var startFuture = connection.startAsync(TransferFormat.text);
        await TestWebSocket.wsSet.future;
        await TestWebSocket.ws.openSet.future;
        TestWebSocket.ws.onopen();
        await startFuture;

        await connection.sendAsync('text');
        TestWebSocket.ws.close();
        TestWebSocket.wsSet = Completer();

        await closeCompleter.future;

        startFuture = connection.startAsync(TransferFormat.text);
        await TestWebSocket.wsSet.future;
        TestWebSocket.ws.onopen();
        await startFuture;
        await connection.sendAsync('text');
      });
    });
    group('# Constructor', () {
      test('# Throws if no url is provided', () {
        final m = predicate(
            (e) => '$e' == "Exception: The 'url' argument is required.");
        final matcher = throwsA(m);
        expect(() => HTTPConnection(null), matcher);
      });
      test('# Uses EventSource constructor from options if provided', () async {
        await VerifyLogger.runAsync((logger) async {
          final options = HTTPConnectionOptions(
              eventSource: (url, {headers, withCredentials}) =>
                  FakeEventSource1(),
              httpClient: TestHTTPClient().on((r, next) {
                return NegotiateResponse(
                  availableTransports: [
                    AvailableTransport(
                      HTTPTransportType.serverSentEvents,
                      [TransferFormat.text],
                    ),
                  ],
                  connectionId: DEFAULT_CONNECTION_ID,
                );
              }, 'POST'),
              logger: logger,
              transport: HTTPTransportType.serverSentEvents);

          final connection = HTTPConnection('http://tempuri.org', options);

          final m = predicate((e) =>
              '$e' ==
              'Exception: Unable to connect to the server with any of the available transports. ServerSentEvents failed: Exception: EventSource constructor called.');
          final matcher = throwsA(m);
          await expectLater(
              connection.startAsync(TransferFormat.text), matcher);

          expect(eventSourceConstructorCalled, true);
        }, [
          "Failed to start the transport 'ServerSentEvents': Exception: EventSource constructor called.",
          'Failed to start the connection: Exception: Unable to connect to the server with any of the available transports. ServerSentEvents failed: Exception: EventSource constructor called.'
        ]);
      });
      test('# Uses WebSocket constructor from options if provided', () async {
        await VerifyLogger.runAsync((logger) async {
          final options = HTTPConnectionOptions(
              webSocket: (url, {protocols, headers}) => FakeWebSocket2(),
              logger: logger,
              skipNegotiation: true,
              transport: HTTPTransportType.webSockets);

          final connection = HTTPConnection('http://tempuri.org', options);

          final m = predicate(
              (e) => '$e' == 'Exception: WebSocket constructor called.');
          final matcher = throwsA(m);
          await expectLater(connection.startAsync(), matcher);
        }, [
          'Failed to start the connection: Exception: WebSocket constructor called.'
        ]);
      });
    });
    group('# StartAsync', () {
      test('# Throws if trying to connect to an ASP.NET Signalr Server',
          () async {
        await VerifyLogger.runAsync((logger) async {
          final options = HTTPConnectionOptions(
              httpClient: TestHTTPClient()
                  .on(
                      (r, next) => '{\"Url\":\"/signalr\",'
                          '\"ConnectionToken\":\"X97dw3uxW4NPPggQsYVcNcyQcuz4w2\",'
                          '\"ConnectionId\":\"05265228-1e2c-46c5-82a1-6a5bcc3f0143\",'
                          '\"KeepAliveTimeout\":10.0,'
                          '\"DisconnectTimeout\":5.0,'
                          '\"TryWebSockets\":true,'
                          '\"ProtocolVersion\":\"1.5\",'
                          '\"TransportConnectTimeout\":30.0,'
                          '\"LongPollDelay\":0.0}',
                      'POST')
                  .on((r, next) => '', 'GET'),
              logger: logger);

          final connection = HTTPConnection('http://tempuri.org', options);
          var receivedError = false;
          try {
            await connection.startAsync(TransferFormat.text);
          } catch (error) {
            final actual = '$error';
            final matcher =
                'Exception: Detected a connection attempt to an ASP.NET Signalr Server. This client only supports connecting to an ASP.NET Core Signalr Server. See https://aka.ms/signalr-core-differences for details.';
            expect(actual, matcher);
            receivedError = true;
          } finally {
            await connection.stopAsync();
          }
          expect(receivedError, true);
        }, [
          'Failed to start the connection: Exception: Detected a connection attempt to an ASP.NET Signalr Server. This client only supports connecting to an ASP.NET Core Signalr Server. See https://aka.ms/signalr-core-differences for details.'
        ]);
      });
    });
  });
  group('# TransportSendQueue', () {
    test('# Sends data when not currently sending', () async {
      final transport = MockTransport();

      when(transport.sendAsync(any)).thenAnswer((_) => Future.value());
      final queue = TransportSendQueue(transport);

      await queue.sendAsync('Hello');
      verify(transport.sendAsync('Hello')).called(1);
      await queue.stopAsync();
    });
    test('# Sends buffered data on fail', () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      final completer3 = Completer<void>();
      final transport = MockTransport();
      when(transport.sendAsync(any)).thenAnswer((_) async {
        when(transport.sendAsync(any)).thenAnswer((_) => Future.value());
        await completer1.future;
        completer2.complete();
        await completer3.future;
      });

      final queue = TransportSendQueue(transport);

      final first = queue.sendAsync('Hello');
      // This should allow first to enter transport.send
      completer1.complete();
      // Wait until we're inside transport.send
      await completer2.future;

      // This should get queued.
      final second = queue.sendAsync('world');

      final error = Exception('Test error');
      completer3.completeError(error);
      final m = predicate((e) => '$e' == 'Exception: Test error');
      final matcher = throwsA(m);
      await expectLater(first, matcher);

      await second;

      var captured = verify(transport.sendAsync(captureAny)).captured;
      expect(captured.length, 2);
      expect(captured[0], 'Hello');
      expect(captured[1], 'world');

      await queue.stopAsync();
    });
    test('# Rejects future for buffered sends', () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      final completer3 = Completer<void>();
      final transport = MockTransport();
      when(transport.sendAsync(any)).thenAnswer((_) async {
        when(transport.sendAsync(any)).thenAnswer((_) {
          final error = Exception('Test error');
          return Future.error(error);
        });
        await completer1.future;
        completer2.complete();
        await completer3.future;
      });

      final queue = TransportSendQueue(transport);

      final first = queue.sendAsync('Hello');
      // This should allow first to enter transport.send
      completer1.complete();
      // Wait until we're inside transport.send
      await completer2.future;

      // This should get queued.
      final second = queue.sendAsync('world');

      completer3.complete();

      await first;
      await expectLater(second, throwsException);

      final captured = verify(transport.sendAsync(captureAny)).captured;
      expect(captured.length, 2);
      expect(captured[0], 'Hello');
      expect(captured[1], 'world');

      await queue.stopAsync();
    });
    test('# Concatenates string sends', () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      final completer3 = Completer<void>();
      final transport = MockTransport();
      when(transport.sendAsync(any)).thenAnswer((_) async {
        when(transport.sendAsync(any)).thenAnswer((_) => Future.value());
        await completer1.future;
        completer2.complete();
        await completer3.future;
      });
      final queue = TransportSendQueue(transport);

      final first = queue.sendAsync('Hello');
      // This should allow first to enter transport.send
      completer1.complete();
      // Wait until we're inside transport.send
      await completer2.future;

      // These two operations should get queued.
      final second = queue.sendAsync('world');
      final third = queue.sendAsync('!');

      completer3.complete();

      await Future.wait([first, second, third]);

      final captured = verify(transport.sendAsync(captureAny)).captured;
      expect(captured.length, 2);
      expect(captured[0], 'Hello');
      expect(captured[1], 'world!');

      await queue.stopAsync();
    });
    test('# Concatenates buffered ArrayBuffer', () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      final completer3 = Completer<void>();
      final transport = MockTransport();
      when(transport.sendAsync(any)).thenAnswer((_) async {
        when(transport.sendAsync(any)).thenAnswer((_) => Future.value());
        await completer1.future;
        completer2.complete();
        await completer3.future;
      });

      final queue = TransportSendQueue(transport);

      final data1 = Uint8List.fromList([4, 5, 6]).buffer;
      final first = queue.sendAsync(data1);
      // This should allow first to enter transport.send
      completer1.complete();
      // Wait until we're inside transport.send
      await completer2.future;

      // These two operations should get queued.
      final data2 = Uint8List.fromList([7, 8, 10]).buffer;
      final second = queue.sendAsync(data2);
      final data3 = Uint8List.fromList([12, 14]).buffer;
      final third = queue.sendAsync(data3);

      completer3.complete();

      await Future.wait([first, second, third]);

      final captured = verify(transport.sendAsync(captureAny)).captured;
      expect(captured.length, 2);
      expect(captured[0].asUint8List().toList(), [4, 5, 6]);
      expect(captured[1].asUint8List().toList(), [7, 8, 10, 12, 14]);

      await queue.stopAsync();
    });
    test('# Throws if mixed data is queued', () async {
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();
      final completer3 = Completer<void>();
      final transport = MockTransport();
      when(transport.sendAsync(any)).thenAnswer((_) async {
        when(transport.sendAsync(any)).thenAnswer((_) => Future.value());
        await completer1.future;
        completer2.complete();
        await completer3.future;
      });

      final queue = TransportSendQueue(transport);

      final data1 = Uint8List.fromList([4, 5, 6]).buffer;
      final first = queue.sendAsync(data1);
      // This should allow first to enter transport.send
      completer1.complete();
      // Wait until we're inside transport.send
      await completer2.future;

      // These two operations should get queued.
      final data2 = Uint8List.fromList([7, 8, 10]).buffer;
      final second = queue.sendAsync(data2);
      expect(() => queue.sendAsync('A string!'), throwsException);

      completer3.complete();

      await Future.wait([first, second]);
      await queue.stopAsync();
    });
    test('# Rejects pending futures on stop', () async {
      final completer = Completer();
      final transport = MockTransport();
      when(transport.sendAsync(any))
          .thenAnswer((_) async => await completer.future);

      final queue = TransportSendQueue(transport);

      final send = queue.sendAsync('Test');
      await queue.stopAsync();

      final m = predicate((e) => '$e' == 'Exception: Connection stopped.');
      final matcher = throwsA(m);
      await expectLater(send, matcher);
    });
    test('# Prevents additional sends after stop', () async {
      final completer = Completer();
      final transport = MockTransport();
      when(transport.sendAsync(any))
          .thenAnswer((_) async => await completer.future);

      final queue = TransportSendQueue(transport);

      await queue.stopAsync();
      final m = predicate((e) => '$e' == 'Exception: Connection stopped.');
      final matcher = throwsA(m);
      await expectLater(queue.sendAsync('test'), matcher);
    });
  });
}

class MockTransport extends Mock implements Transport {}

class MockLogger extends Mock implements Logger {}

class FakeTransport1 extends Fake implements Transport {
  @override
  void Function(Exception error) onclose;
  @override
  void Function(dynamic data) onreceive;

  @override
  Future<void> connectAsync(String url, TransferFormat transferFormat) {
    return Future.value();
  }

  @override
  Future<void> sendAsync(data) {
    return Future.value();
  }

  @override
  Future<void> stopAsync() {
    return Future.value();
  }
}

class FakeTransport2 extends Fake implements Transport {
  final Completer<String> connectUrl;
  @override
  void Function(Exception error) onclose;
  @override
  void Function(dynamic data) onreceive;

  FakeTransport2() : connectUrl = Completer();

  @override
  Future<void> connectAsync(String url, TransferFormat transferFormat) {
    connectUrl.complete(url);
    return Future.value();
  }

  @override
  Future<void> sendAsync(data) {
    return Future.value();
  }

  @override
  Future<void> stopAsync() {
    return Future.value();
  }
}

class FakeTransport3 extends Fake implements Transport {
  bool handlersSet;
  @override
  void Function(Exception error) onclose;
  @override
  void Function(dynamic data) onreceive;

  FakeTransport3() : handlersSet = false;

  @override
  Future<void> connectAsync(String url, TransferFormat transferFormat) {
    if (onreceive != null && onclose != null) {
      handlersSet = true;
    }
    return Future.value();
  }

  @override
  Future<void> sendAsync(data) {
    return Future.value();
  }

  @override
  Future<void> stopAsync() {
    onclose?.call(null);
    return Future.value();
  }
}

class FakeTransport4 extends Fake implements Transport {
  @override
  void Function(Exception error) onclose;
  @override
  void Function(dynamic data) onreceive;

  @override
  Future<void> connectAsync(String url, TransferFormat transferFormat) {
    return Future.value();
  }

  @override
  Future<void> sendAsync(data) {
    return Future.value();
  }

  @override
  Future<void> stopAsync() {
    onclose?.call(null);
    return Future.value();
  }
}

class FakeTransport5 extends Fake implements Transport {
  String connectUrl;
  @override
  void Function(Exception error) onclose;
  @override
  void Function(dynamic data) onreceive;

  FakeTransport5() : connectUrl = '';

  @override
  Future<void> connectAsync(String url, TransferFormat transferFormat) {
    connectUrl = url;
    return Future.value();
  }

  @override
  Future<void> sendAsync(data) {
    return Future.value();
  }

  @override
  Future<void> stopAsync() {
    onclose?.call(null);
    return Future.value();
  }
}

class FakeWebSocket1 extends Fake implements WebSocket {
  static FakeWebSocket1 ws;
  static Completer<void> wsSet;

  @override
  void Function(Exception error) onerror;
  @override
  void Function(dynamic data) ondata;
  @override
  void Function(int code, String reason) onclose;

  dynamic Function() websocketOpen;
  final SyncPoint sync;

  void Function() _onopen;
  var openSet = Completer<void>();
  @override
  void Function() get onopen {
    return _onopen;
  }

  @override
  set onopen(void Function() value) {
    _onopen = value;
    websocketOpen = () => _onopen();
    sync.$continue();
  }

  @override
  void close([int code, String reason]) {}

  FakeWebSocket1()
      : sync = SyncPoint(),
        _onopen = null {
    ws = this;
    wsSet.complete();
  }
}

class FakeWebSocket2 extends Fake implements WebSocket {
  FakeWebSocket2() {
    throw Exception('WebSocket constructor called.');
  }
}

var eventSourceConstructorCalled = false;

class FakeEventSource1 extends Fake implements EventSource {
  FakeEventSource1() {
    eventSourceConstructorCalled = true;
    throw Exception('EventSource constructor called.');
  }
}
