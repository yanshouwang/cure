import 'package:cure/signalr.dart';
import 'package:test/test.dart';

void eachTransport(void Function(HTTPTransportType transport) action) {
  final transports = [
    HTTPTransportType.webSockets,
    HTTPTransportType.serverSentEvents,
    HTTPTransportType.longPolling
  ];
  for (var transport in transports) {
    action.call(transport);
  }
}

void eachEndpoint(void Function(String given, String expected) action) {
  final urls = [
    [
      'http://tempuri.org/endpoint/?q=my/Data',
      'http://tempuri.org/endpoint/negotiate?q=my/Data&negotiateVersion=1'
    ],
    [
      'http://tempuri.org/endpoint?q=my/Data',
      'http://tempuri.org/endpoint/negotiate?q=my/Data&negotiateVersion=1'
    ],
    [
      'http://tempuri.org/endpoint',
      'http://tempuri.org/endpoint/negotiate?negotiateVersion=1'
    ],
    [
      'http://tempuri.org/endpoint/',
      'http://tempuri.org/endpoint/negotiate?negotiateVersion=1'
    ]
  ];
  for (var url in urls) {
    action.call(url[0], url[1]);
  }
}

class VerifyLogger implements Logger {
  List<String> unexpectedErrors;
  List<bool Function(String error)> expectedErrors;

  VerifyLogger(List<dynamic> expectedErrors)
      : unexpectedErrors = [],
        expectedErrors = [] {
    for (var element in expectedErrors) {
      if (element is RegExp) {
        this.expectedErrors.add((e) => element.hasMatch(e));
      } else if (element is String) {
        this.expectedErrors.add((e) => element == e);
      } else if (element is bool Function(String error)) {
        this.expectedErrors.add(element);
      } else {
        throw Exception('Wrong element type ${element.runtimeType}');
      }
    }
  }

  static Future<void> runAsync(Future<void> Function(VerifyLogger logger) fn,
      [List<dynamic> expectedErrors = const []]) async {
    final logger = VerifyLogger(expectedErrors);
    await fn(logger);
    final actual = logger.unexpectedErrors.join('\n');
    final matcher = '';
    expect(actual, matcher);
  }

  @override
  void log(LogLevel logLevel, String message) {
    if (logLevel.index >= LogLevel.error.index) {
      if (!expectedErrors.any((fn) => fn(message))) {
        unexpectedErrors.add(message);
      }
    }
  }
}
