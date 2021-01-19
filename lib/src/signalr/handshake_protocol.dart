import 'dart:typed_data';

import 'package:cure/convert.dart';
import 'package:tuple/tuple.dart';

import 'text_message_format.dart';

abstract class HandshakeProtocol {
  Tuple2<dynamic, HandshakeResponseMessage> parseHandshakeResponse(
      dynamic data);
  String writeHandshakeRequest(HandshakeRequestMessage handshakeRequest);

  factory HandshakeProtocol() => _HandshakeProtocol();
}

class _HandshakeProtocol implements HandshakeProtocol {
  @override
  Tuple2<dynamic, HandshakeResponseMessage> parseHandshakeResponse(
      dynamic data) {
    HandshakeResponseMessage responseMessage;
    String messageData;
    dynamic remainingData;

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
    final source = json.decode(messages[0]) as Map<String, dynamic>;
    try {
      final response = HandshakeResponseMessage.fromJSON(source);
      responseMessage = response;
    } catch (_) {
      throw Exception('Expected a handshake response from the server.');
    }

    // multiple messages could have arrived with handshake
    // return additional data to be parsed as usual, or null if all parsed
    return Tuple2(remainingData, responseMessage);
  }

  // Handshake request is always JSON
  @override
  String writeHandshakeRequest(HandshakeRequestMessage handshakeRequest) {
    final output = json.encode(handshakeRequest);
    return TextMessageFormat.write(output);
  }
}

class HandshakeRequestMessage {
  final String protocol;
  final int version;

  HandshakeRequestMessage(this.protocol, this.version);

  factory HandshakeRequestMessage.fromJSON(Map<String, dynamic> obj) {
    final protocol = obj['protocol'] as String;
    final version = obj['version'] as int;
    return HandshakeRequestMessage(protocol, version);
  }

  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{
      'protocol': protocol,
      'version': version,
    };
    return obj;
  }
}

class HandshakeResponseMessage {
  final String? error;
  final int? minorVersion;

  HandshakeResponseMessage({this.error, this.minorVersion});

  factory HandshakeResponseMessage.fromJSON(Map<String, dynamic> obj) {
    final error = obj['error'] as String?;
    final minorVersion = obj['minorVersion'] as int?;
    return HandshakeResponseMessage(error: error, minorVersion: minorVersion);
  }

  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{};
    obj.writeNotNull('error', error);
    obj.writeNotNull('minorVersion', minorVersion);
    return obj;
  }
}
