import 'dart:html';

String get osName => '';
String get runtime => 'Browser';
String get runtimeVersion => null;

String get userAgent => 'X-SignalR-User-Agent';

bool get isWeb => true;
bool get isVM => false;

void error(dynamic message) => window.console.error(message);
void warn(dynamic message) => window.console.warn(message);
void info(dynamic message) => window.console.info(message);
void log(dynamic message) => window.console.log(message);
