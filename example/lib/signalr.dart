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
