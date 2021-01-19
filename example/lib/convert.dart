import 'package:cure/convert.dart';
import 'package:cure/core.dart';

void main() {
  // MessagePack
  var object = Timestamp.utc(1970);
  final data = messagePack.encode(object);
  print(data); // [214, 255, 0, 0, 0, 0]
  object = messagePack.decode(data) as Timestamp;
  print(object); // Timestamp(0, 0)
}
