import 'transport.dart';

abstract class Connection {
  Map<String, dynamic> get features;
  String? get connectionId;

  String get baseURL;
  set baseURL(String url);

  void Function(Object data)? onreceive;
  void Function(Object? error)? onclose;

  Future<void> startAsync(TransferFormat transferFormat);
  Future<void> sendAsync(Object data);
  Future<void> stopAsync([Object? error]);
}
