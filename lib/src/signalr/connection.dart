import 'transport.dart';

abstract class Connection {
  Map<String, Object> get features;
  String get connectionId;

  String baseURL;

  void Function(Object data) onreceive;
  void Function(Exception error) onclose;

  Future<void> startAsync(TransferFormat transferFormat);
  Future<void> sendAsync(Object data);
  Future<void> stopAsync([Exception error]);
}
