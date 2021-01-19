import 'package:cure/signalr.dart';

class TestTransport extends Transport {
  @override
  void Function(Object? error)? onclose;
  @override
  void Function(Object data)? onreceive;

  @override
  Future<void> connectAsync(String? url, TransferFormat transferFormat) {
    return Future.value();
  }

  @override
  Future<void> sendAsync(data) {
    return Future.value();
  }

  @override
  Future<void> stopAsync() {
    return Future.value();
  }
}
