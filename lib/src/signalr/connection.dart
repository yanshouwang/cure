import 'transport.dart';

abstract class Connection {
  Map<String, dynamic> get features;
  String get connectionId;

  String baseURL;

  void Function(dynamic data) onreceive;
  void Function(Exception error) onclose;

  Future<void> startAsync(TransferFormat transferFormat);
  Future<void> sendAsync(dynamic data);
  Future<void> stopAsync([Exception error]);
}
