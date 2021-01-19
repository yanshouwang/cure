import 'dart:typed_data';

import 'package:cure/core.dart';

import 'http_client.dart';
import 'logger.dart';
import 'utils_stub.dart'
    if (dart.library.html) 'utils_chromium.dart'
    if (dart.library.io) 'utils_dartium.dart' as utils;

/// The version of the Signalr client.
const VERSION = '5.0.1';

class Arg {
  static void isNotEmpty(String? val, String name) {
    final re = RegExp(r'^\s*$');
    if (val == null || re.hasMatch(val)) {
      throw Exception("The '${name}' argument should not be empty.");
    }
  }

  static void isIn(Object val, List<Object> values, String name) {
    if (!values.contains(val)) {
      throw Exception('Unknown ${name} value: ${val}.');
    }
  }
}

class Platform {
  static bool get isChromium => utils.isChromium;
  static bool get isDartium => utils.isDartium;
}

String getDataDetail(Object? data, bool includeContent) {
  var detail = '';
  if (data is Uint8List) {
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

extension on Uint8List {
  String format() {
    var str = '';
    for (var num in this) {
      str += '0x${num.toRadixString(16).padLeft(2, '0')} ';
    }
    return str.substring(0, str.length - 1);
  }
}

Future<void> sendMessageAsync(
    Logger logger,
    String transportName,
    HttpClient httpClient,
    String url,
    String Function()? accessTokenBuilder,
    Object content,
    bool logMessageContent,
    bool? withCredentials,
    Map<String, String>? headers) async {
  final combine = <String, String>{};
  final token = await accessTokenBuilder?.call();
  if (token != null) {
    combine['Authorization'] = 'Bearer $token';
  }

  final userAgent = getUserAgentHeader();
  combine[userAgent.key] = userAgent.value;

  if (headers != null) {
    combine.addAll(headers);
  }

  logger.log(LogLevel.trace,
      '($transportName transport) sending data. ${getDataDetail(content, logMessageContent)}.');

  final responseType = content is Uint8List ? 'arraybuffer' : 'text';
  final options = HttpRequest(
      content: content,
      headers: combine,
      responseType: responseType,
      withCredentials: withCredentials);
  final response = await httpClient.postAsync(url, options);

  logger.log(LogLevel.trace,
      '($transportName transport) request complete. Response status: ${response.statusCode}.');
}

Logger createLogger(Object? logger) {
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

class ConsoleLogger implements Logger {
  Console outputConsole;
  final LogLevel? _minimumLogLevel;

  ConsoleLogger(this._minimumLogLevel) : outputConsole = console;

  @override
  void log(LogLevel logLevel, String message) {
    if (logLevel.index >= _minimumLogLevel!.index) {
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
  if (os.isEmpty) {
    os = 'Unknown OS';
  }
  if (runtime.isEmpty) {
    runtime = 'Unknown Runtime';
  }
  if (runtimeVersion.isEmpty) {
    runtimeVersion = 'Unknown Runtime Version';
  }
  var userAgent =
      'Microsoft SignalR/${majorAndMinor[0]}.${majorAndMinor[1]} ($version; $os; $runtime; $runtimeVersion)';
  return userAgent;
}
