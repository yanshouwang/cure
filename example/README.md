1. convert

``` Dart
import 'package:cure/convert.dart';
import 'package:cure/core.dart';

void main() {
  // MessagePack
  var object = Timestamp.utc(1970);
  final data = messagePack.encode(object);
  print(data); // [214, 255, 0, 0, 0, 0]
  object = messagePack.decode(data);
  print(object); // Timestamp(0, 0)
}

```

2. crypto

``` Dart
import 'dart:convert';

import 'package:cure/crypto.dart';

void main() {
  final crc = CRC.crc16MODBUS();
  final data = utf8.encode('123456789');
  final value = crc.calculate(data);
  print(value);
  final result = crc.verify(data, value);
  print(result);
}

``` 

3. http

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

4. signalr

``` Dart
import 'package:cure/signalr.dart';

void main() async {
  final connection = HubConnectionBuilder()
      .withURL('url')
      //.withHubProtocol(MessagePackHubProtocol())
      .build();
  connection.on('send', (args) => print(args));
  await connection.startAsync();
  await connection.sendAsync('send', ['Hello', 123]);
  final obj = await connection.invokeAsync('send', ['Hello', 'World']);
  print(obj);
}

```