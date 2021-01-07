import 'http_client.dart';
import 'logger.dart';

HttpClient createClient(Logger logger) => throw UnsupportedError(
    "Can't create a client without dart:html or dart:io.");
