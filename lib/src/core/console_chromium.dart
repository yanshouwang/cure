import 'dart:html';
import 'console.dart';

Console createConsole() => _Console();

class _Console implements Console {
  @override
  void log(Object message) {
    window.console.log(message);
  }

  @override
  void info(Object message) {
    window.console.info(message);
  }

  @override
  void warn(Object message) {
    window.console.warn(message);
  }

  @override
  void error(Object message) {
    window.console.error(message);
  }
}
