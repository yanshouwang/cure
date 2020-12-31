1. HTTP

``` Dart
import 'package:cure/http.dart';

void main() async {
  var client = Client();
  try {
    final response = await client.getAsync('url');
    print('${response.statusCode}: ${response.content}');
  } catch (e) {
    print(e);
  } finally {
    client.close();
  }
}
```

2. Serialization

``` Dart
import 'package:cure/serialization.dart';

void main() {
  final source = '{"key1": "value1", "key2": 123}';
  final obj = JSON.fromJSON(source);
  print(obj);
  final str = JSON.toJSON(obj);
  print(str);
}
```

3. Cryptography

``` Dart
import 'dart:convert';

import 'package:cure/cryptography.dart';

void main() {
  final crc = CRC.crc16MODBUS();
  final data = utf8.encode('123456789');
  final value = crc.calculate(data);
  print(value);
  final result = crc.verify(data, value);
  print(result);
}
``` 

4. Signalr

``` Dart
import 'package:cure/signalr.dart';

void main() async {
  final connection = HubConnectionBuilder().withURL('url').build();
  connection.on('send', (args) => print(args));
  await connection.startAsync();
  await connection.sendAsync('send', ['Hello', 123]);
  final obj = await connection.invokeAsync('send', ['Hello', 'World']);
  print(obj);
}
```