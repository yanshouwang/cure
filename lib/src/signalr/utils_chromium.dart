import 'dart:html';

String get osName => '';
String get runtime => 'Browser';
String get runtimeVersion => null;

String get userAgent => 'X-SignalR-User-Agent';

bool get isWeb => true;
bool get isVM => false;

void error(Object message) => window.console.error(message);
void warn(Object message) => window.console.warn(message);
void info(Object message) => window.console.info(message);
void log(Object message) => window.console.log(message);
