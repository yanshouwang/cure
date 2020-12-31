import 'dart:typed_data';

import 'package:cure/serialization.dart';

import 'text_message_format.dart';

abstract class HandshakeProtocol {
  String writeHandshakeRequest(HandshakeRequestMessage handshakeRequest);
  MapEntry<dynamic, HandshakeResponseMessage> parseHandshakeResponse(
      dynamic data);

  factory HandshakeProtocol() => _HandshakeProtocol();
}

class _HandshakeProtocol implements HandshakeProtocol {
  @override
  MapEntry<dynamic, HandshakeResponseMessage> parseHandshakeResponse(data) {
    HandshakeResponseMessage responseMessage;
    String messageData;
    dynamic remainingData;

    if (data is ByteBuffer) {
      // Format is binary but still need to read JSON text from handshake response
      final binaryData = data.asUint8List();
      final separatorIndex =
          binaryData.indexOf(TextMessageFormat.recordSeparatorCode);
      if (separatorIndex == -1) {
        throw Exception('Message is incomplete.');
      }

      // content before separator is handshake response
      // optional content after is additional messages
      final responseLength = separatorIndex + 1;
      final charCodes = binaryData.sublist(0, responseLength);
      messageData = String.fromCharCodes(charCodes);
      remainingData = binaryData.lengthInBytes > responseLength
          ? binaryData.sublist(responseLength).buffer
          : null;
    } else {
      final textData = data;
      final separatorIndex =
          textData.indexOf(TextMessageFormat.recordSeparator);
      if (separatorIndex == -1) {
        throw Exception('Message is incomplete.');
      }

      // content before separator is handshake response
      // optional content after is additional messages
      final responseLength = separatorIndex + 1;
      messageData = textData.substring(0, responseLength);
      remainingData = textData.length > responseLength
          ? textData.substring(responseLength)
          : null;
    }

    // At this point we should have just the single handshake message
    final messages = TextMessageFormat.parse(messageData);
    final source = JSON.fromJSON(messages[0]);
    final response = HandshakeResponseMessage.fromJSON(source);
    if (response == null) {
      throw Exception('Expected a handshake response from the server.');
    }
    responseMessage = response;

    // multiple messages could have arrived with handshake
    // return additional data to be parsed as usual, or null if all parsed
    return MapEntry(remainingData, responseMessage);
  }

  // Handshake request is always JSON
  @override
  String writeHandshakeRequest(HandshakeRequestMessage handshakeRequest) {
    //final obj = handshakeRequest.toJSON();
    final output = JSON.toJSON(handshakeRequest);
    return TextMessageFormat.write(output);
  }
}

abstract class HandshakeRequestMessage {
  String get protocol;
  int get version;

  Map<String, dynamic> toJSON();

  factory HandshakeRequestMessage(String protocol, int version) {
    return _HandshakeRequestMessage(protocol, version);
  }

  factory HandshakeRequestMessage.fromJSON(Map<String, dynamic> obj) {
    final protocol = obj['protocol'] as String;
    final version = obj['version'] as int;
    return _HandshakeRequestMessage(protocol, version);
  }
}

class _HandshakeRequestMessage implements HandshakeRequestMessage {
  @override
  final String protocol;
  @override
  final int version;

  _HandshakeRequestMessage(this.protocol, this.version);

  @override
  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{
      'protocol': protocol,
      'version': version,
    };
    return obj;
  }
}

abstract class HandshakeResponseMessage {
  String get error;
  int get minorVersion;

  Map<String, dynamic> toJSON();

  factory HandshakeResponseMessage({String error, int minorVersion}) {
    return _HandshakeResponseMessage(error, minorVersion);
  }

  factory HandshakeResponseMessage.fromJSON(Map<String, dynamic> obj) {
    final error = obj['error'] as String;
    final minorVersion = obj['minorVersion'] as int;
    return _HandshakeResponseMessage(error, minorVersion);
  }
}

class _HandshakeResponseMessage implements HandshakeResponseMessage {
  @override
  final String error;
  @override
  final int minorVersion;

  _HandshakeResponseMessage(this.error, this.minorVersion);

  @override
  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{};
    obj.writeNotNull('error', error);
    obj.writeNotNull('minorVersion', minorVersion);
    return obj;
  }
}
