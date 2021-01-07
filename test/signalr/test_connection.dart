import 'dart:typed_data';

import 'package:cure/convert.dart';
import 'package:cure/signalr.dart';

class TestConnection implements Connection {
  @override
  String baseURL;
  @override
  final Map<String, Object> features;
  @override
  String connectionId;
  @override
  void Function(Exception error) onclose;
  @override
  void Function(Object data) onreceive;

  List<dynamic> sentData;
  List<dynamic> parsedSentData;
  String lastInvocationId;

  final bool _autoHandshake;

  Future<void> Function() startFuture;
  Future<void> Function() sendFuture;

  TestConnection(
      [this._autoHandshake = true, bool hasInherentKeepAlive = false])
      : features = {},
        onreceive = null,
        onclose = null,
        sentData = [],
        parsedSentData = [],
        lastInvocationId = null,
        baseURL = 'http://example.com' {
    features['inherentKeepAlive'] = hasInherentKeepAlive;
  }

  @override
  Future<void> startAsync(TransferFormat transferFormat) {
    if (startFuture != null) {
      return startFuture();
    } else {
      return Future.value();
    }
  }

  @override
  Future<void> sendAsync(data) {
    if (sendFuture != null) {
      return sendFuture();
    } else {
      final invocation = TextMessageFormat.parse(data)[0];
      final parsedInvocation = json.decode(invocation) as Map<String, Object>;
      final invocationId = parsedInvocation['invocationId'];
      if (parsedInvocation.containsKey('protocol') &&
          parsedInvocation.containsKey('version') &&
          _autoHandshake) {
        receiveHandshakeResponse();
      }
      if (invocationId != null) {
        lastInvocationId = invocationId;
      }
      if (sentData != null) {
        sentData.add(invocation);
        parsedSentData.add(parsedInvocation);
      } else {
        sentData = [invocation];
        parsedSentData = [parsedInvocation];
      }
      return Future.value();
    }
  }

  @override
  Future<void> stopAsync([Exception error]) {
    onclose?.call(error);
    return Future.value();
  }

  void receiveHandshakeResponse([String error]) {
    final data = <String, Object>{};
    if (error != null) {
      data['error'] = error;
    }
    receive(data);
  }

  void receive(Object data) {
    final payload = json.encode(data);
    _invokeOnReceive(TextMessageFormat.write(payload));
  }

  void receiveText(String data) {
    _invokeOnReceive(data);
  }

  void receiveBinary(Uint8List data) {
    _invokeOnReceive(data);
  }

  void _invokeOnReceive(Object data) {
    onreceive?.call(data);
  }
}
