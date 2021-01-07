import 'dart:io';

String get osName => Platform.operatingSystem;
String get runtime => 'Dart';
String get runtimeVersion => Platform.version;

String get userAgent => 'User-Agent';

bool get isWeb => false;
bool get isVM => true;

void error(Object message) => print(message);
void warn(Object message) => print(message);
void info(Object message) => print(message);
void log(Object message) => print(message);
