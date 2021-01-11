import 'dart:io';

String get osName => Platform.operatingSystem;
String get runtime => 'Dart';
String get runtimeVersion => Platform.version;

String get userAgent => 'User-Agent';

bool get isChromium => false;
bool get isDartium => true;
