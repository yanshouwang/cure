import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'base_client.dart';
import 'client.dart';
import 'exceptions.dart';
import 'response.dart';
import 'request.dart';

Client createClient() => _VMClient();

class _VMClient extends BaseClient {
  final HttpClient _client;

  _VMClient() : _client = HttpClient();

  @override
  Future<Response> sendAsync(Request request) async {
    try {
      var hcr = await _client.openUrl(request.method, request.url);
      for (final entry in request.headers.entries) {
        hcr.headers.set(entry.key, entry.value);
      }
      final data = request.encode();
      hcr.contentLength = data.length;
      hcr.add(data);
      final response = await hcr.close();
      final headers = <String, String>{};
      response.headers.forEach((key, values) {
        headers[key] = values.join(',');
      });
      final stream = response.handleError((error) {
        final e = error as HttpException;
        throw ClientException(e.message, e.uri);
      });
      final charset = response.headers.contentType?.charset;
      final encoding = charset == null ? utf8 : Encoding.getByName(charset);
      final content = await encoding.decodeStream(stream);
      return Response(
          response.statusCode, response.reasonPhrase, content, headers);
    } on HttpException catch (e) {
      throw ClientException(e.message, e.uri);
    }
  }

  @override
  void close([bool force = false]) {
    _client.close(force: force);
  }
}
