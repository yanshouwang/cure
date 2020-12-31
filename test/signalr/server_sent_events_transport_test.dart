import 'dart:async';

import 'package:cure/signalr.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'test_event_source.dart';
import 'test_http_client.dart';

void main() {
  test('# Does not allow non-text formats', () async {
    await VerifyLogger.runAsync((logger) async {
      final sse = ServerSentEventsTransport(
          TestHTTPClient(),
          null,
          logger,
          true,
          (url, {headers, withCredentials}) =>
              TestEventSource(url, headers: headers),
          true,
          {});

      final m = predicate((e) =>
          '$e' ==
          "Exception: The Server-Sent Events transport only supports the 'Text' transfer format");
      final matcher = throwsA(m);
      await expectLater(sse.connectAsync('', TransferFormat.binary), matcher);
    });
  });
  test('# Connect waits for EventSource to be connected', () async {
    await VerifyLogger.runAsync((logger) async {
      final sse = ServerSentEventsTransport(
          TestHTTPClient(),
          null,
          logger,
          true,
          (url, {headers, withCredentials}) =>
              TestEventSource(url, headers: headers),
          true,
          {});

      TestEventSource.eventSourceSet = Completer();

      var connectComplete = false;
      final connectFuture = (() async {
        await sse.connectAsync('http://example.com', TransferFormat.text);
        connectComplete = true;
      })();

      await TestEventSource.eventSourceSet.future;
      await TestEventSource.eventSource.openSet.future;

      expect(connectComplete, false);

      TestEventSource.eventSource.onopen();

      await connectFuture;
      expect(connectComplete, true);
    });
  });
  test('# Connect failure does not call onclose handler', () async {
    await VerifyLogger.runAsync((logger) async {
      final sse = ServerSentEventsTransport(
          TestHTTPClient(),
          null,
          logger,
          true,
          (url, {headers, withCredentials}) =>
              TestEventSource(url, headers: headers),
          true,
          {});
      var closeCalled = false;
      sse.onclose = (error) => closeCalled = true;

      TestEventSource.eventSourceSet = Completer();

      final connectFuture = (() async {
        await sse.connectAsync('http://example.com', TransferFormat.text);
      })();

      await TestEventSource.eventSourceSet.future;
      await TestEventSource.eventSource.openSet.future;

      TestEventSource.eventSource.onerror(null);

      final m = predicate((e) => '$e' == 'Exception: Error occurred');
      final matcher = throwsA(m);

      await expectLater(connectFuture, matcher);
      expect(closeCalled, false);
    });
  });

  [
    ['http://example.com', 'http://example.com?access_token=secretToken'],
    [
      'http://example.com?value=null',
      'http://example.com?value=null&access_token=secretToken'
    ]
  ].forEach((element) {
    final input = element[0];
    final expected = element[1];
    test('# Appends access_token to url $input', () async {
      await VerifyLogger.runAsync((logger) async {
        await createAndStartSSEAsync(logger, input, () => 'secretToken');

        expect(TestEventSource.eventSource.url, expected);
      });
    });
  });

  test('# Sets Authorization header on sends', () async {
    await VerifyLogger.runAsync((logger) async {
      HTTPRequest request;
      final httpClient = TestHTTPClient().on((r, next) {
        request = r;
        return '';
      });

      final sse = await createAndStartSSEAsync(
          logger, 'http://example.com', () => 'secretToken', httpClient);

      await sse.sendAsync('');

      expect(request.headers['Authorization'], 'Bearer secretToken');
      expect(request.url, 'http://example.com');
    });
  });
  test('# Can send data', () async {
    await VerifyLogger.runAsync((logger) async {
      HTTPRequest request;
      final httpClient = TestHTTPClient().on((r, next) {
        request = r;
        return '';
      });

      final sse = await createAndStartSSEAsync(
          logger, 'http://example.com', null, httpClient);

      await sse.sendAsync('send data');

      expect(request.content, 'send data');
    });
  });
  test('# Can receive data', () async {
    await VerifyLogger.runAsync((logger) async {
      final sse = await createAndStartSSEAsync(logger);

      dynamic received;
      sse.onreceive = (data) => received = data;

      TestEventSource.eventSource.ondata('message', 'receive data');

      expect(received, 'receive data');
    });
  });
  test('# Stop closes EventSource and calls onclose', () async {
    await VerifyLogger.runAsync((logger) async {
      final sse = await createAndStartSSEAsync(logger);

      var closeCalled = false;
      sse.onclose = (error) => closeCalled = true;

      await sse.stopAsync();

      expect(closeCalled, true);
      expect(TestEventSource.eventSource.closed, true);
    });
  });
  test('# Can close from EventSource error', () async {
    await VerifyLogger.runAsync((logger) async {
      final sse = await createAndStartSSEAsync(logger);

      var closeCalled = false;
      Exception fail;
      sse.onclose = (e) {
        closeCalled = true;
        fail = e;
      };

      final error = Exception('error');
      TestEventSource.eventSource.onerror(error);

      expect(closeCalled, true);
      expect(TestEventSource.eventSource.closed, true);
      expect(fail, error);
    });
  });
  test('# Send throws if not connected', () async {
    await VerifyLogger.runAsync((logger) async {
      final sse = ServerSentEventsTransport(
          TestHTTPClient(),
          null,
          logger,
          true,
          (url, {headers, withCredentials}) =>
              TestEventSource(url, headers: headers),
          true,
          {});

      final m = predicate((e) =>
          '$e' == 'Exception: Cannot send until the transport is connected');
      final matcher = throwsA(m);
      await expectLater(sse.sendAsync(''), matcher);
    });
  });
  test('# Closes on error from receive', () async {
    await VerifyLogger.runAsync((logger) async {
      final sse = await createAndStartSSEAsync(logger);

      sse.onreceive = (data) => throw Exception('error parsing');

      var closeCalled = false;
      Exception error;
      sse.onclose = (e) {
        closeCalled = true;
        error = e;
      };

      TestEventSource.eventSource.ondata('error', 'some data');

      expect(closeCalled, true);
      expect(TestEventSource.eventSource.closed, true);
      final matcher = predicate((e) => '$e' == 'Exception: error parsing');
      expect(error, matcher);
    });
  });
  test('# Sets user agent header on connect and sends', () async {
    await VerifyLogger.runAsync((logger) async {
      HTTPRequest request;
      final httpClient = TestHTTPClient().on((r, next) {
        request = r;
        return '';
      });

      final sse = await createAndStartSSEAsync(
          logger, 'http://example.com', null, httpClient);

      var userAgent = getUserAgentHeader();
      expect(
          TestEventSource.eventSource.headers['User-Agent'], userAgent.value);
      await sse.sendAsync('');

      userAgent = getUserAgentHeader();
      expect(request.headers['User-Agent'], userAgent.value);
      expect(request.url, 'http://example.com');
    });
  });
  test('# Overwrites library headers with user headers', () async {
    await VerifyLogger.runAsync((logger) async {
      HTTPRequest request;
      final httpClient = TestHTTPClient().on((r, next) {
        request = r;
        return '';
      });

      final headers = {'User-Agent': 'Custom Agent', 'X-HEADER': 'VALUE'};
      final sse = await createAndStartSSEAsync(
          logger, 'http://example.com', null, httpClient, headers);

      expect(TestEventSource.eventSource.headers['User-Agent'], 'Custom Agent');
      expect(TestEventSource.eventSource.headers['X-HEADER'], 'VALUE');
      await sse.sendAsync('');

      expect(request.headers['User-Agent'], 'Custom Agent');
      expect(request.headers['X-HEADER'], 'VALUE');
      expect(request.url, 'http://example.com');
    });
  });
}

Future<ServerSentEventsTransport> createAndStartSSEAsync(Logger logger,
    [String url,
    dynamic Function() accessTokenFactory,
    HTTPClient httpClient,
    Map<String, String> headers]) async {
  TestEventSource.eventSourceSet = Completer();

  final sse = ServerSentEventsTransport(
      httpClient ?? TestHTTPClient(),
      accessTokenFactory,
      logger,
      true,
      (url, {headers, withCredentials}) =>
          TestEventSource(url, headers: headers),
      true,
      headers ?? {});

  final connectFuture =
      sse.connectAsync(url ?? 'http://example.com', TransferFormat.text);

  await TestEventSource.eventSourceSet.future;
  await TestEventSource.eventSource.openSet.future;

  TestEventSource.eventSource.onopen();
  await connectFuture;
  return sse;
}
