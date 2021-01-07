import 'package:cure/convert.dart';
import 'package:cure/signalr.dart';

typedef TestHttpHandler = dynamic Function(HttpRequest request,
    Future<HttpResponse> Function(HttpRequest request) next);

class TestHttpClient extends HttpClient {
  Future<HttpResponse> Function(HttpRequest request) _handler;
  List<HttpRequest> requests;

  TestHttpClient()
      : requests = [],
        _handler = ((request) => Future.error(
            'Request has no handler: ${request.method} ${request.url}'));

  @override
  Future<HttpResponse> sendAsync(HttpRequest request) {
    requests.add(request);
    return _handler(request);
  }

  TestHttpClient on(TestHttpHandler handler, [Object method, Object url]) {
    // TypeScript callers won't be able to do this, because TypeScript checks this for us.
    if (handler == null) {
      throw "Missing required argument: 'handler'";
    }

    final oldHandler = _handler;
    final newHandler = (HttpRequest request) async {
      if (_matches(method, request.method) && _matches(url, request.url)) {
        final future = handler(request, oldHandler);

        Object val;
        if (future is Future<Object>) {
          val = await future;
        } else {
          val = future;
        }

        if (val is String) {
          // string payload
          return HttpResponse(200, 'OK', val);
        } else if (val is HttpResponse) {
          // HttpResponse payload
          return val;
        } else {
          // JSON payload
          final content = val != null ? json.encode(val) : val;
          return HttpResponse(200, 'OK', content);
        }
      } else {
        return await oldHandler(request);
      }
    };
    _handler = newHandler;

    return this;
  }
}

bool _matches(Object pattern, String actual) {
  // Null or undefined pattern matches all.
  if (pattern == null) {
    return true;
  }

  if (pattern is RegExp) {
    return pattern.hasMatch(actual);
  } else {
    return actual == pattern;
  }
}
