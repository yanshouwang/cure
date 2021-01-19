import 'package:cure/signalr.dart';
import 'package:test/test.dart';

import 'test_http_client.dart';

void main() {
  group('# GET', () {
    test('# sets the method and URL appropriately', () async {
      late HttpRequest request;
      final client = TestHttpClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      await client.getAsync('http://localhost');
      expect(request.method, 'GET');
      expect(request.url, 'http://localhost');
    });
    test('# overrides method and url in options', () async {
      late HttpRequest request;
      final client = TestHttpClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      final options = HttpRequest(method: 'OPTIONS', url: 'http://wrong');
      await client.getAsync('http://localhost', options);
      expect(request.method, 'GET');
      expect(request.url, 'http://localhost');
    });
    test('# copies other options', () async {
      late HttpRequest request;
      final testClient = TestHttpClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      final options = HttpRequest(headers: {'X-HEADER': 'VALUE'}, timeout: 42);
      await testClient.getAsync('http://localhost', options);
      expect(request.timeout, 42);
      expect(request.headers, {'X-HEADER': 'VALUE'});
    });
  });
  group('# POST', () {
    test('# sets the method and URL appropriately', () async {
      late HttpRequest request;
      final client = TestHttpClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      await client.postAsync('http://localhost');
      expect(request.method, 'POST');
      expect(request.url, 'http://localhost');
    });
    test('# overrides method and url in options', () async {
      late HttpRequest request;
      final client = TestHttpClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      final options = HttpRequest(method: 'OPTIONS', url: 'http://wrong');
      await client.postAsync('http://localhost', options);
      expect(request.method, 'POST');
      expect(request.url, 'http://localhost');
    });
    test('# copies other options', () async {
      late HttpRequest request;
      final testClient = TestHttpClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      final options = HttpRequest(headers: {'X-HEADER': 'VALUE'}, timeout: 42);
      await testClient.postAsync('http://localhost', options);
      expect(request.timeout, 42);
      expect(request.headers, {'X-HEADER': 'VALUE'});
    });
  });
}
