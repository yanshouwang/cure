import 'dart:typed_data';

import 'http_client.dart';
import 'logger.dart';
import 'stream.dart';
import 'utils_stub.dart'
    if (dart.library.html) 'utils_html.dart'
    if (dart.library.io) 'utils_io.dart' as utils;
import 'subject.dart';

/// The version of the Signalr client.
const VERSION = '5.0.0-dev';

class Arg {
  static void isRequired(dynamic val, String name) {
    if (val == null) {
      throw Exception("The '${name}' argument is required.");
    }
  }

  static void isNotEmpty(String val, String name) {
    final re = RegExp(r'^\s*$');
    if (val == null || re.hasMatch(val)) {
      throw Exception("The '${name}' argument should not be empty.");
    }
  }

  static void isIn(dynamic val, List<dynamic> values, String name) {
    if (!values.contains(val)) {
      throw Exception('Unknown ${name} value: ${val}.');
    }
  }
}

class Platform {
  static bool get isWeb => utils.isWeb;
  static bool get isVM => utils.isVM;
}

String getDataDetail(dynamic data, bool includeContent) {
  var detail = '';
  if (data is ByteBuffer) {
    detail = 'Binary data of length ${data.lengthInBytes}';
    if (includeContent) {
      detail += ". Content: '${data.format()}'";
    }
  } else if (data is String) {
    detail = 'String data of length ${data.length}';
    if (includeContent) {
      detail += ". Content: '$data'";
    }
  }
  return detail;
}

extension on ByteBuffer {
  String format() {
    final view = asUint8List();
    var str = '';
    for (var num in view) {
      str += '0x${num.toRadixString(16).padLeft(2, '0')} ';
    }
    return str.substring(0, str.length - 1);
  }
}

Future<void> sendMessageAsync(
    Logger logger,
    String transportName,
    HTTPClient httpClient,
    String url,
    dynamic Function() accessTokenFactory,
    dynamic content,
    bool logMessageContent,
    bool withCredentials,
    Map<String, String> defaultHeaders) async {
  final headers = <String, String>{};
  if (accessTokenFactory != null) {
    final token = await accessTokenFactory();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
  }

  final userAgent = getUserAgentHeader();
  headers[userAgent.key] = userAgent.value;

  headers.addAll(defaultHeaders);

  logger.log(LogLevel.trace,
      '($transportName transport) sending data. ${getDataDetail(content, logMessageContent)}.');

  final responseType = content is ByteBuffer ? 'arraybuffer' : 'text';
  final options = HTTPRequest(
      content: content,
      headers: headers,
      responseType: responseType,
      withCredentials: withCredentials);
  final response = await httpClient.postAsync(url, options);

  logger.log(LogLevel.trace,
      '($transportName transport) request complete. Response status: ${response.statusCode}.');
}

Logger createLogger(dynamic logger) {
  if (logger == null) {
    return ConsoleLogger(LogLevel.information);
  }
  if (logger is LogLevel) {
    return ConsoleLogger(logger);
  }
  if (logger is Logger) {
    return logger;
  }
  throw Exception('Invalid logger type: ${logger.runtimeType}');
}

class SubjectSubscription<T> implements Subscription<T> {
  final Subject<T> _subject;
  final StreamSubscriber<T> _observer;

  SubjectSubscription(this._subject, this._observer);

  @override
  void dispose() {
    final index = _subject.observers.indexOf(_observer);
    if (index > -1) {
      _subject.observers.removeAt(index);
    }

    if (_subject.observers.isEmpty && _subject.cancelCallback != null) {
      try {
        _subject.cancelCallback();
      } catch (_) {}
    }
  }
}

abstract class Console {
  void error(dynamic message);
  void warn(dynamic message);
  void info(dynamic message);
  void log(dynamic message);

  factory Console() => _Console();
}

class _Console implements Console {
  @override
  void error(dynamic message) => utils.error(message);
  @override
  void warn(dynamic message) => utils.warn(message);
  @override
  void info(dynamic message) => utils.info(message);
  @override
  void log(dynamic message) => utils.log(message);
}

class ConsoleLogger implements Logger {
  Console outputConsole;
  final LogLevel _minimumLogLevel;

  ConsoleLogger(this._minimumLogLevel) : outputConsole = Console();

  @override
  void log(LogLevel logLevel, String message) {
    if (logLevel.index >= _minimumLogLevel.index) {
      final object =
          '[${DateTime.now().toIso8601String()}] $logLevel: $message';
      switch (logLevel) {
        case LogLevel.critical:
        case LogLevel.error:
          outputConsole.error(object);
          break;
        case LogLevel.warning:
          outputConsole.warn(object);
          break;
        case LogLevel.information:
          outputConsole.info(object);
          break;
        default:
          // console.debug only goes to attached debuggers in Node, so we use console.log for Trace and Debug
          outputConsole.log(object);
          break;
      }
    }
  }
}

MapEntry<String, String> getUserAgentHeader() {
  final key = utils.userAgent;
  final value = constructUserAgent(
      VERSION, utils.osName, utils.runtime, utils.runtimeVersion);
  final header = MapEntry(key, value);
  return header;
}

String constructUserAgent(
    String version, String os, String runtime, String runtimeVersion) {
  // Microsoft SignalR/[Version] ([Detailed Version]; [Operating System]; [Runtime]; [Runtime Version])
  final majorAndMinor = version.split('.');
  if (os == null || os.isEmpty) {
    os = 'Unknown OS';
  }
  if (runtime == null || runtime.isEmpty) {
    runtime = 'Unknown Runtime';
  }
  if (runtimeVersion == null || runtimeVersion.isEmpty) {
    runtimeVersion = 'Unknown Runtime Version';
  }
  var userAgent =
      'Microsoft SignalR/${majorAndMinor[0]}.${majorAndMinor[1]} ($version; $os; $runtime; $runtimeVersion)';
  return userAgent;
}
