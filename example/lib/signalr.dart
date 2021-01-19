import 'package:cure/signalr.dart';

void main() async {
  final builder = HubConnectionBuilder()
    ..url = 'url'
    ..logLevel = LogLevel.information
    ..reconnect = true;
  final connection = builder.build();
  connection.on('send', (args) => print(args));
  await connection.startAsync();
  await connection.sendAsync('send', ['Hello', 123]);
  final obj = await connection.invokeAsync('send', ['Hello', 'World']);
  print(obj);
}
