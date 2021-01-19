import 'event_source.dart';

EventSource connectEventSource(String url,
        {Map<String, String>? headers, bool? withCredentials}) =>
    throw UnsupportedError(
        "Can't create a EventSource without dart:html or dart:io.");
