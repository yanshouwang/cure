import 'dart:typed_data';

import 'package:cure/convert.dart';

import 'text_message_format.dart';

abstract class HandshakeProtocol {
  String writeHandshakeRequest(HandshakeRequestMessage handshakeRequest);
  MapEntry<Object, HandshakeResponseMessage> parseHandshakeResponse(
      Object data);

  factory HandshakeProtocol() => _HandshakeProtocol();
}

class _HandshakeProtocol implements HandshakeProtocol {
  @override
  MapEntry<Object, HandshakeResponseMessage> parseHandshakeResponse(data) {
    HandshakeResponseMessage responseMessage;
    String messageData;
    Object remainingData;

    if (data is Uint8List) {
      // Format is binary but still need to read JSON text from handshake response
      final separatorIndex =
          data.indexOf(TextMessageFormat.recordSeparatorCode);
      if (separatorIndex == -1) {
        throw Exception('Message is incomplete.');
      }

      // content before separator is handshake response
      // optional content after is additional messages
      final responseLength = separatorIndex + 1;
      final charCodes = data.sublist(0, responseLength);
      messageData = String.fromCharCodes(charCodes);
      remainingData = data.lengthInBytes > responseLength
          ? data.sublist(responseLength)
          : null;
    } else {
      final textData = data as String;
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
    final source = json.decode(messages[0]);
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
    final output = json.encode(handshakeRequest);
    return TextMessageFormat.write(output);
  }
}

abstract class HandshakeRequestMessage {
  String get protocol;
  int get version;

  Map<String, Object> toJSON();

  factory HandshakeRequestMessage(String protocol, int version) {
    return _HandshakeRequestMessage(protocol, version);
  }

  factory HandshakeRequestMessage.fromJSON(Map<String, Object> obj) {
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
  Map<String, Object> toJSON() {
    final obj = <String, Object>{
      'protocol': protocol,
      'version': version,
    };
    return obj;
  }
}

abstract class HandshakeResponseMessage {
  String get error;
  int get minorVersion;

  Map<String, Object> toJSON();

  factory HandshakeResponseMessage({String error, int minorVersion}) {
    return _HandshakeResponseMessage(error, minorVersion);
  }

  factory HandshakeResponseMessage.fromJSON(Map<String, Object> obj) {
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
  Map<String, Object> toJSON() {
    final obj = <String, Object>{};
    obj.writeNotNull('error', error);
    obj.writeNotNull('minorVersion', minorVersion);
    return obj;
  }
}
