import 'package:cure/serialization.dart';

void main() {
  final source = '{"key1": "value1", "key2": 123}';
  final obj = JSON.fromJSON(source);
  print(obj);
  final str = JSON.toJSON(obj);
  print(str);
}
