import 'console_stub.dart'
    if (dart.library.html) 'console_chromium.dart'
    if (dart.library.io) 'console_dartium.dart';

final console = Console._();

abstract class Console {
  void log(Object message);
  void info(Object message);
  void warn(Object message);
  void error(Object message);

  factory Console._() => createConsole();
}
