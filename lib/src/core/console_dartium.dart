import 'dart:io';

import 'package:ansicolor/ansicolor.dart';

import 'console.dart';

Console createConsole() => _Console();

class _Console implements Console {
  @override
  void log(Object message) {
    stdout.writeln(message);
  }

  @override
  void info(Object message) {
    stdout.writeln(message);
  }

  @override
  void warn(Object message) {
    final pen = AnsiPen()..yellow();
    final object = pen(message);
    stdout.writeln(object);
  }

  @override
  void error(Object message) {
    final pen = AnsiPen()..red();
    final object = pen(message);
    stdout.writeln(object);
  }
}
