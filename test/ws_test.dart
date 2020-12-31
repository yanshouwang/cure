import 'dart:async';
import 'dart:io';

import 'package:cure/ws.dart';
import 'package:test/test.dart';

void main() {
  test('# A client can communicate with a WebSocket server', () async {
    final completer = Completer<void>();

    var httpServer = await HttpServer.bind('localhost', 0);
    httpServer.listen((request) async {
      final server = await WebSocketTransformer.upgrade(request);
      server.add('hello!');
      server.listen((request) {
        expect(request, equals('ping'));
        server.add('pong');
        server.close();
      });
    });

    final url = 'ws://localhost:${httpServer.port}';
    final client = WebSocket.connect(url);

    client.onopen = () => expect(client.readyState, WebSocket.OPEN);
    client.onerror = (error) => fail('$error');
    var n = 0;
    client.ondata = (data) {
      if (n == 0) {
        expect(data, equals('hello!'));
        client.send('ping');
      } else if (n == 1) {
        expect(data, equals('pong'));
        client.close();
      } else {
        fail('Only expected two messages.');
      }
      n++;
    };
    client.onclose = (code, reason) => completer.complete();

    await completer.future;
  });
}
