import 'package:cure/convert.dart';
import 'package:cure/http.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  setUp(() => startServer());
  tearDown(() => stopServer());

  test('# HEAD', () async {
    final client = Client();
    try {
      final response = await client.headAsync(serverURL);
      expect(response.statusCode, 200);
      expect(response.content, '');
    } finally {
      client.close();
    }
  });

  test('# GET', () async {
    final client = Client();
    try {
      final headers = {
        'X-Random-Header': 'Value',
        'X-Other-Header': 'Other Value',
        'User-Agent': 'Dart',
      };
      final response = await client.getAsync(serverURL, headers);
      expect(response.statusCode, 200);
      final headers1 = {
        'content-length': ['0'],
        'accept-encoding': ['gzip'],
        'user-agent': ['Dart'],
        'x-random-header': ['Value'],
        'x-other-header': ['Other Value'],
      };
      final actual = json.decode(response.content!);
      final matcher = {
        'method': 'GET',
        'path': '/',
        'headers': headers1,
      };
      expect(actual, matcher);
    } finally {
      client.close();
    }
  });

  test('# POST', () async {
    final client = Client();
    try {
      final headers = {
        'X-Random-Header': 'Value',
        'X-Other-Header': 'Other Value',
        'User-Agent': 'Dart',
      };
      final content = 'CONTENT';
      final response =
          await client.postAsync(serverURL, content, ContentType.text, headers);
      expect(response.statusCode, 200);
      final headers1 = {
        'content-type': ['text/plain; charset=utf-8'],
        'content-length': ['7'],
        'accept-encoding': ['gzip'],
        'user-agent': ['Dart'],
        'x-random-header': ['Value'],
        'x-other-header': ['Other Value']
      };
      final actual = json.decode(response.content!);
      final matcher = {
        'method': 'POST',
        'path': '/',
        'headers': headers1,
        'content': content
      };
      expect(actual, matcher);
    } finally {
      client.close();
    }
  });

  test('# PUT', () async {
    final client = Client();
    try {
      final headers = {
        'X-Random-Header': 'Value',
        'X-Other-Header': 'Other Value',
        'User-Agent': 'Dart',
      };
      final content = 'CONTENT';
      final response =
          await client.putAsync(serverURL, content, ContentType.text, headers);
      expect(response.statusCode, 200);
      final headers1 = {
        'content-type': ['text/plain; charset=utf-8'],
        'content-length': ['7'],
        'accept-encoding': ['gzip'],
        'user-agent': ['Dart'],
        'x-random-header': ['Value'],
        'x-other-header': ['Other Value']
      };
      final actual = json.decode(response.content!);
      final matcher = {
        'method': 'PUT',
        'path': '/',
        'headers': headers1,
        'content': content
      };
      expect(actual, matcher);
    } finally {
      client.close();
    }
  });

  test('# PATCH', () async {
    final client = Client();
    try {
      final headers = {
        'X-Random-Header': 'Value',
        'X-Other-Header': 'Other Value',
        'User-Agent': 'Dart',
      };
      final content = 'CONTENT';
      final response = await client.patchAsync(
          serverURL, content, ContentType.text, headers);
      expect(response.statusCode, 200);
      final headers1 = {
        'content-type': ['text/plain; charset=utf-8'],
        'content-length': ['7'],
        'accept-encoding': ['gzip'],
        'user-agent': ['Dart'],
        'x-random-header': ['Value'],
        'x-other-header': ['Other Value']
      };
      final actual = json.decode(response.content!);
      final matcher = {
        'method': 'PATCH',
        'path': '/',
        'headers': headers1,
        'content': content
      };
      expect(actual, matcher);
    } finally {
      client.close();
    }
  });

  test('# DELETE', () async {
    final client = Client();
    try {
      final headers = {
        'X-Random-Header': 'Value',
        'X-Other-Header': 'Other Value',
        'User-Agent': 'Dart',
      };
      final response = await client.deleteAsync(serverURL, headers);
      expect(response.statusCode, 200);
      final headers1 = {
        'content-length': ['0'],
        'accept-encoding': ['gzip'],
        'user-agent': ['Dart'],
        'x-random-header': ['Value'],
        'x-other-header': ['Other Value'],
      };
      final actual = json.decode(response.content!);
      final matcher = {
        'method': 'DELETE',
        'path': '/',
        'headers': headers1,
      };
      expect(actual, matcher);
    } finally {
      client.close();
    }
  });
}
