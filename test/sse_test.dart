import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:cure/sse.dart';

void main() {
  test("# open and close connection when listening on 'events'", () async {
    final completer = Completer<void>();

    final server = await HttpServer.bind('localhost', 0);
    final values = [
      'retry:3000',
      'id:34',
      'data:example data',
      '',
    ];
    server.listen((request) {
      request.response.bufferOutput = false;
      values.forEach((line) {
        request.response.write('$line\n');
      });
    });

    final url = 'http://${server.address.host}:${server.port}';
    final client = EventSource.connect(url);
    client.onopen = () => expect(client.readyState, EventSource.OPEN);
    client.ondata = (event, data) {
      expect(event, 'message');
      expect(data, data);
      client.close();
      server.close();
      completer.complete();
    };

    await completer.future;
  });
  test('# reconnects with Last-Event-ID', () async {
    final completer = Completer<void>();

    var server = await HttpServer.bind('localhost', 0);
    final values = [
      'event:first',
      'retry:500',
      'id:10',
      'data:example',
      '',
    ];
    server.listen((request) {
      request.response.bufferOutput = false;
      values.forEach((line) {
        request.response.write('$line\n');
      });
    });

    final url = 'http://${server.address.host}:${server.port}';
    final client = EventSource.connect(url);
    client.onopen = () => expect(client.readyState, EventSource.OPEN);
    client.ondata = (event, data) async {
      if (event == 'first') {
        expect(data, 'example');
        // Kill the connection
        final port = server.port;
        await server.close(force: true);
        server = await HttpServer.bind('localhost', port);
        server.listen((request) {
          expect(request.headers.value('Last-Event-ID'), equals('10'));
          request.response.bufferOutput = false;
          request.response.write('data:back\n\n');
        });
      } else {
        expect(data, 'back');
        client.close();
        await server.close();
        completer.complete();
      }
    };
    await completer.future;
  });
}
