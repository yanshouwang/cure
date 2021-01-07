import 'dart:async';
import 'dart:typed_data';

import 'package:cure/signalr.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import 'common.dart';
import 'test_http_client.dart';
import 'test_web_socket.dart';

void main() {
  test('# set websocket binarytype to arraybuffer on Binary transferformat',
      () async {
    await VerifyLogger.runAsync((logger) async {
      await createAndStartWebSocketAsync(
          logger, 'http://example.com', null, TransferFormat.binary);
      expect(TestWebSocket.ws.binaryType, 'arraybuffer');
    });
  });
  test('# connect waits for WebSocket to be connected', () async {
    await VerifyLogger.runAsync((logger) async {
      final transport = createWebSocket(logger, null);

      var connectComplete = false;
      final connectFuture = (() async {
        await transport.connectAsync('http://example.com', TransferFormat.text);
        connectComplete = true;
      }).call();

      await TestWebSocket.ws.openSet.future;
      expect(connectComplete, false);
      TestWebSocket.ws.onopen();
      await connectFuture;
      expect(connectComplete, true);
    });
  });
  test('# connect fails if there is error during connect', () async {
    await VerifyLogger.runAsync((logger) async {
      final transport = createWebSocket(logger, null);

      var connectComplete = false;
      final connectFuture = (() async {
        await transport.connectAsync('http://example.com', TransferFormat.text);
        connectComplete = true;
      }).call();

      await TestWebSocket.ws.closeSet.future;

      expect(connectComplete, false);

      final error = Exception('There was an error with the transport.');
      TestWebSocket.ws.onerror(error);

      final mathcer = throwsA(error);
      await expectLater(connectFuture, mathcer);
      expect(connectComplete, false);
    });
  });
  test('# connect failure does not call onclose handler', () async {
    await VerifyLogger.runAsync((logger) async {
      final transport = createWebSocket(logger, null);

      var closeCalled = false;
      transport.onclose = (_) => closeCalled = true;

      var connectComplete = false;
      final connectFuture = (() async {
        await transport.connectAsync('http://example.com', TransferFormat.text);
        connectComplete = true;
      }).call();

      await TestWebSocket.ws.closeSet.future;

      expect(connectComplete, false);

      TestWebSocket.ws.onclose(null, null);

      final error = Exception('There was an error with the transport.');
      final m = predicate((e) => '$e' == '$error');
      final matcher = throwsA(m);
      await expectLater(connectFuture, matcher);
      expect(connectComplete, false);
      expect(closeCalled, false);
    });
  });
  group('# generates correct WebSocket URL with access_token', () {
    final items = [
      MapEntry(
          'http://example.com', 'ws://example.com?access_token=secretToken'),
      MapEntry('http://example.com?value=null',
          'ws://example.com?value=null&access_token=secretToken'),
      MapEntry('https://example.com?value=null',
          'wss://example.com?value=null&access_token=secretToken')
    ];
    for (var item in items) {
      test('# ${item.key}', () async {
        await VerifyLogger.runAsync((logger) async {
          await createAndStartWebSocketAsync(
              logger, item.key, () => Future.value('secretToken'));
          expect(TestWebSocket.ws.url, item.value);
        });
      });
    }
  });
  group('# generates correct WebSocket URL', () {
    final items = [
      MapEntry('http://example.com', 'ws://example.com'),
      MapEntry('http://example.com?value=null', 'ws://example.com?value=null'),
      MapEntry('https://example.com?value=null', 'wss://example.com?value=null')
    ];
    for (var item in items) {
      test('# ${item.key}', () async {
        await VerifyLogger.runAsync((logger) async {
          await createAndStartWebSocketAsync(logger, item.key, null);
          expect(TestWebSocket.ws.url, item.value);
        });
      });
    }
  });
  test('# can receive data', () async {
    await VerifyLogger.runAsync((logger) async {
      final webSocket = await createAndStartWebSocketAsync(logger);

      Object received;
      webSocket.onreceive = (data) => received = data;

      TestWebSocket.ws.ondata('receive data');

      expect(received, isA<String>());
      expect(received, 'receive data');
    });
  });
  test('# is closed from WebSocket onclose with error', () async {
    await VerifyLogger.runAsync((logger) async {
      final transport = await createAndStartWebSocketAsync(logger);

      var closeCalled = false;
      Exception error;
      transport.onclose = (e) {
        closeCalled = true;
        error = e;
      };

      final code = 1;
      final reason = 'just cause';
      TestWebSocket.ws.onclose(code, reason);

      expect(closeCalled, true);
      final error1 =
          Exception('WebSocket closed with status code: 1 (just cause).');
      final m1 = predicate((e) => '$e' == '$error1');
      expect(error, m1);

      final error2 = Exception('WebSocket is not in the OPEN state');
      final m2 = predicate((e) => '$e' == '$error2');
      final matcher = throwsA(m2);
      await expectLater(transport.sendAsync(''), matcher);
    });
  });
  test('# is closed from WebSocket onclose', () async {
    await VerifyLogger.runAsync((logger) async {
      final transport = await createAndStartWebSocketAsync(logger);

      var closeCalled = false;
      Exception error;
      transport.onclose = (e) {
        closeCalled = true;
        error = e;
      };

      final code = 1000;
      final reason = 'success';
      TestWebSocket.ws.onclose(code, reason);

      expect(closeCalled, true);
      expect(error, null);

      final error1 = Exception('WebSocket is not in the OPEN state');
      final m = predicate((e) => '$e' == '$error1');
      final matcher = throwsA(m);
      await expectLater(transport.sendAsync(''), matcher);
    });
  });
  test('# is closed from Transport stop', () async {
    await VerifyLogger.runAsync((logger) async {
      final transport = await createAndStartWebSocketAsync(logger);

      var closeCalled = false;
      Exception error;
      transport.onclose = (e) {
        closeCalled = true;
        error = e;
      };

      await transport.stopAsync();

      expect(closeCalled, true);
      expect(error, null);

      final error1 = Exception('WebSocket is not in the OPEN state');
      final m = predicate((e) => '$e' == '$error1');
      final matcher = throwsA(m);
      await expectLater(transport.sendAsync(''), matcher);
    });
  });
  group('# can send data', () {
    final elements = [
      Tuple2(TransferFormat.text, 'send data'),
      Tuple2(TransferFormat.binary, Uint8List.fromList([0, 1, 3]))
    ];
    for (var element in elements) {
      test('# send ${element.item1}', () async {
        await VerifyLogger.runAsync((logger) async {
          final webSocket = await createAndStartWebSocketAsync(
              logger, 'http://example.com', null, element.item1);

          //MockWebSocket.ws.readyState = WebSocket.OPEN;
          await webSocket.sendAsync(element.item2);

          expect(TestWebSocket.ws.receivedData.length, 1);
          expect(TestWebSocket.ws.receivedData[0], element.item2);
        });
      });
    }
  });
  test('# sets user agent header on connect', () async {
    await VerifyLogger.runAsync((logger) async {
      final transport = await createAndStartWebSocketAsync(logger);

      var closeCalled = false;
      Exception error;
      transport.onclose = (e) {
        closeCalled = true;
        error = e;
      };

      final userAgent = getUserAgentHeader();
      expect(TestWebSocket.ws.headers['User-Agent'], userAgent.value);

      await transport.stopAsync();

      expect(closeCalled, true);
      expect(error, null);

      final m = predicate(
          (e) => '$e' == 'Exception: WebSocket is not in the OPEN state');
      final matcher = throwsA(m);
      await expectLater(transport.sendAsync(''), matcher);
    });
  });
  test('# overwrites library headers with user headers', () async {
    await VerifyLogger.runAsync((logger) async {
      final headers = {'User-Agent': 'Custom Agent', 'X-HEADER': 'VALUE'};
      final transport =
          await createAndStartWebSocketAsync(logger, null, null, null, headers);

      var closeCalled = false;
      Exception error;
      transport.onclose = (e) {
        closeCalled = true;
        error = e;
      };

      expect(TestWebSocket.ws.headers['User-Agent'], 'Custom Agent');
      expect(TestWebSocket.ws.headers['X-HEADER'], 'VALUE');

      await transport.stopAsync();

      expect(closeCalled, true);
      expect(error, null);

      final error1 = Exception('WebSocket is not in the OPEN state');
      final m = predicate((e) => '$e' == '$error1');
      final matcher = throwsA(m);
      await expectLater(transport.sendAsync(''), matcher);
    });
  });
  test("# is closed from 'onreceive' callback throwing", () async {
    await VerifyLogger.runAsync((logger) async {
      final transport = await createAndStartWebSocketAsync(logger);

      var closeCalled = false;
      Exception error;
      transport.onclose = (e) {
        closeCalled = true;
        error = e;
      };

      final error1 = Exception('callback error');
      transport.onreceive = (data) {
        throw error1;
      };

      final data = 'receive data';
      TestWebSocket.ws.ondata(data);

      expect(closeCalled, true);
      expect(error, error1);

      final error2 = Exception('WebSocket is not in the OPEN state');
      final m = predicate((e) => '$e' == '$error2');
      final matcher = throwsA(m);
      await expectLater(transport.sendAsync(''), matcher);
    });
  });
  test(
      'does not run onclose callback if Transport does not fully connect and exits',
      () async {
    await VerifyLogger.runAsync((logger) async {
      final webSocket = createWebSocket(logger);

      final connectPromise =
          webSocket.connectAsync('http://example.com', TransferFormat.text);

      await TestWebSocket.ws.closeSet.future;

      var closeCalled = false;
      Exception error;
      webSocket.onclose = (e) {
        closeCalled = true;
        error = e;
      };

      final code = 1;
      final reason = 'just cause';
      TestWebSocket.ws.onclose(code, reason);

      expect(closeCalled, false);
      expect(error, null);

      final error1 = Exception('There was an error with the transport.');
      TestWebSocket.ws.onerror(error1);
      final m = predicate((e) => '$e' == '$error1');
      final matcher = throwsA(m);
      await expectLater(connectPromise, matcher);
    });
  });
}

WebSocketTransport createWebSocket(Logger logger,
    [Future<String> Function() accessTokenFactory,
    Map<String, String> headers]) {
  TestWebSocket.wsSet = Completer<void>();
  final transprot = WebSocketTransport(
      TestHttpClient(),
      accessTokenFactory,
      logger,
      true,
      (url, {protocols, headers}) =>
          TestWebSocket(url, protocols: protocols, headers: headers),
      headers ?? {});
  return transprot;
}

Future<WebSocketTransport> createAndStartWebSocketAsync(Logger logger,
    [String url,
    Future<String> Function() accessTokenFactory,
    TransferFormat format,
    Map<String, String> headers]) async {
  final transprot = createWebSocket(logger, accessTokenFactory, headers);
  final connectFuture = transprot.connectAsync(
      url ?? 'http://example.com', format ?? TransferFormat.text);

  await TestWebSocket.wsSet.future;
  await TestWebSocket.ws.openSet.future;
  TestWebSocket.ws.onopen();
  await connectFuture;

  return transprot;
}
