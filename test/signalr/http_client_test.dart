import 'package:cure/signalr.dart';
import 'package:test/test.dart';

import 'test_http_client.dart';

void main() {
  group('# GET', () {
    test('# Sets the method and URL appropriately', () async {
      HTTPRequest request;
      final client = TestHTTPClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      await client.getAsync('http://localhost');
      expect(request.method, 'GET');
      expect(request.url, 'http://localhost');
    });
    test('# Overrides method and url in options', () async {
      HTTPRequest request;
      final client = TestHTTPClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      final options = HTTPRequest(method: 'OPTIONS', url: 'http://wrong');
      await client.getAsync('http://localhost', options);
      expect(request.method, 'GET');
      expect(request.url, 'http://localhost');
    });
    test('# Copies other options', () async {
      HTTPRequest request;
      final testClient = TestHTTPClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      final options = HTTPRequest(headers: {'X-HEADER': 'VALUE'}, timeout: 42);
      await testClient.getAsync('http://localhost', options);
      expect(request.timeout, 42);
      expect(request.headers, {'X-HEADER': 'VALUE'});
    });
  });
  group('# POST', () {
    test('# Sets the method and URL appropriately', () async {
      HTTPRequest request;
      final client = TestHTTPClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      await client.postAsync('http://localhost');
      expect(request.method, 'POST');
      expect(request.url, 'http://localhost');
    });
    test('# Overrides method and url in options', () async {
      HTTPRequest request;
      final client = TestHTTPClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      final options = HTTPRequest(method: 'OPTIONS', url: 'http://wrong');
      await client.postAsync('http://localhost', options);
      expect(request.method, 'POST');
      expect(request.url, 'http://localhost');
    });
    test('# Copies other options', () async {
      HTTPRequest request;
      final testClient = TestHTTPClient().on((r, next) {
        request = r;
        return Future.value('');
      });

      final options = HTTPRequest(headers: {'X-HEADER': 'VALUE'}, timeout: 42);
      await testClient.postAsync('http://localhost', options);
      expect(request.timeout, 42);
      expect(request.headers, {'X-HEADER': 'VALUE'});
    });
  });
}
