import 'dart:typed_data';

import 'package:cure/serialization.dart';
import 'package:cure/signalr.dart';

class TestConnection implements Connection {
  @override
  String baseURL;
  @override
  final Map<String, dynamic> features;
  @override
  String connectionId;
  @override
  void Function(Exception error) onclose;
  @override
  void Function(dynamic data) onreceive;

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
      final parsedInvocation =
          JSON.fromJSON(invocation) as Map<String, dynamic>;
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
    final data = <String, dynamic>{};
    if (error != null) {
      data['error'] = error;
    }
    receive(data);
  }

  void receive(dynamic data) {
    final payload = JSON.toJSON(data);
    _invokeOnReceive(TextMessageFormat.write(payload));
  }

  void receiveText(String data) {
    _invokeOnReceive(data);
  }

  void receiveBinary(ByteBuffer data) {
    _invokeOnReceive(data);
  }

  void _invokeOnReceive(dynamic data) {
    onreceive?.call(data);
  }
}
