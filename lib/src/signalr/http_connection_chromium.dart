import 'dart:html';

import 'logger.dart';

String resolveURL(String url, Logger logger) {
  // Setting the url to the href propery of an anchor tag handles normalization
  // for us. There are 3 main cases.
  // 1. Relative path normalization e.g "b" -> "http://localhost:5000/a/b"
  // 2. Absolute path normalization e.g "/a/b" -> "http://localhost:5000/a/b"
  // 3. Networkpath reference normalization e.g "//localhost:5000/a/b" -> "http://localhost:5000/a/b"
  final aTag = window.document.createElement('a') as AnchorElement;
  aTag.href = url;

  logger.log(LogLevel.information, "Normalizing '$url' to '${aTag.href}'.");
  return aTag.href!;
}
