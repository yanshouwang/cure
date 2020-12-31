import 'package:cure/serialization.dart';
import 'package:cure/signalr.dart';

typedef TestHTTPHandler = dynamic Function(HTTPRequest request,
    Future<HTTPResponse> Function(HTTPRequest request) next);

class TestHTTPClient extends HTTPClient {
  Future<HTTPResponse> Function(HTTPRequest request) _handler;
  List<HTTPRequest> requests;

  TestHTTPClient()
      : requests = [],
        _handler = ((request) => Future.error(
            'Request has no handler: ${request.method} ${request.url}'));

  @override
  Future<HTTPResponse> sendAsync(HTTPRequest request) {
    requests.add(request);
    return _handler(request);
  }

  TestHTTPClient on(TestHTTPHandler handler, [dynamic method, dynamic url]) {
    // TypeScript callers won't be able to do this, because TypeScript checks this for us.
    if (handler == null) {
      throw "Missing required argument: 'handler'";
    }

    final oldHandler = _handler;
    final newHandler = (HTTPRequest request) async {
      if (_matches(method, request.method) && _matches(url, request.url)) {
        final future = handler(request, oldHandler);

        dynamic val;
        if (future is Future<dynamic>) {
          val = await future;
        } else {
          val = future;
        }

        if (val is String) {
          // string payload
          return HTTPResponse(200, 'OK', val);
        } else if (val is HTTPResponse) {
          // HttpResponse payload
          return val;
        } else {
          // JSON payload
          final content = val != null ? JSON.toJSON(val) : val;
          return HTTPResponse(200, 'OK', content);
        }
      } else {
        return await oldHandler(request);
      }
    };
    _handler = newHandler;

    return this;
  }
}

bool _matches(dynamic pattern, String actual) {
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
