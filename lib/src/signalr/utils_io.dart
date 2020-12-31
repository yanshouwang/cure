import 'dart:io';

String get osName => Platform.operatingSystem;
String get runtime => 'Dart';
String get runtimeVersion => Platform.version;

String get userAgent => 'User-Agent';

bool get isWeb => false;
bool get isVM => true;

void error(dynamic message) => print(message);
void warn(dynamic message) => print(message);
void info(dynamic message) => print(message);
void log(dynamic message) => print(message);
