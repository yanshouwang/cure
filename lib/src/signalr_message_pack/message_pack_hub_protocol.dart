import 'dart:typed_data';

import 'package:cure/convert.dart';
import 'package:cure/signalr.dart';
import 'package:cure/signalr_message_pack.dart';

final SERIALIZED_PING_MESSAGE =
    Uint8List.fromList([0x91, MessageType.ping.value]);

const ERROR_RESULT = 1;
const VOID_RESULT = 2;
const NON_VOID_RESULT = 3;

/// Implements the MessagePack Hub Protocol
class MessagePackHubProtocol implements HubProtocol {
  @override
  String get name => 'messagepack';
  @override
  int get version => 1;
  @override
  TransferFormat get transferFormat => TransferFormat.binary;

  final MessagePackCodec _codec;

  /// [options] MessagePack options passed to MessagePack
  MessagePackHubProtocol({
    MessagePackDecodeOptions decodeOptions,
    MessagePackEncodeOptions encodeOptions,
  }) : _codec = MessagePackCodec(
          decodeOptions: decodeOptions,
          encodeOptions: encodeOptions,
        );

  /// Creates an array of HubMessage objects from the specified serialized representation.
  ///
  /// [input] An Uint8List containing the serialized representation.
  /// [logger] A logger that will be used to log messages that occur during parsing.
  @override
  List<HubMessage> parseMessages(Object input, Logger logger) {
    // The interface does allow "string" to be passed in, but this implementation does not. So let's throw a useful error.
    if (input is Uint8List) {
      logger ??= NullLogger();

      final messages = BinaryMessageFormat.parse(input);

      final hubMessages = <HubMessage>[];
      for (final message in messages) {
        final parsedMessage = _parseMessage(message, logger);
        // Can be null for an unknown message. Unknown message is logged in parseMessage
        if (parsedMessage != null) {
          hubMessages.add(parsedMessage);
        }
      }

      return hubMessages;
    } else {
      throw Exception(
          'Invalid input for MessagePack hub protocol. Expected an Uint8List.');
    }
  }

  /// Writes the specified HubMessage to a Uint8List and returns it.
  ///
  /// [message] The message to write.
  /// Returns a Uint8List containing the serialized representation of the message.
  @override
  Object writeMessage(HubMessage message) {
    switch (message.type) {
      case MessageType.invocation:
        return _writeInvocation(message as InvocationMessage);
      case MessageType.streamInvocation:
        return _writeStreamInvocation(message as StreamInvocationMessage);
      case MessageType.streamItem:
        return _writeStreamItem(message as StreamItemMessage);
      case MessageType.completion:
        return _writeCompletion(message as CompletionMessage);
      case MessageType.ping:
        return BinaryMessageFormat.write(SERIALIZED_PING_MESSAGE);
      case MessageType.cancelInvocation:
        return _writeCancelInvocation(message as CancelInvocationMessage);
      default:
        throw Exception('Invalid message type.');
    }
  }

  HubMessage _parseMessage(Uint8List input, Logger logger) {
    if (input.isEmpty) {
      throw Exception('Invalid payload.');
    }

    final properties = _codec.decode(input);
    if (properties is List && properties.isNotEmpty) {
      final messageType = MessageType.fromJSON(properties[0] as int);

      switch (messageType) {
        case MessageType.invocation:
          return _createInvocationMessage(_readHeaders(properties), properties);
        case MessageType.streamItem:
          return _createStreamItemMessage(_readHeaders(properties), properties);
        case MessageType.completion:
          return _createCompletionMessage(_readHeaders(properties), properties);
        case MessageType.ping:
          return _createPingMessage(properties);
        case MessageType.close:
          return _createCloseMessage(properties);
        default:
          // Future protocol changes can add message types, old clients can ignore them
          logger.log(LogLevel.information,
              "Unknown message type '$messageType' ignored.");
          return null;
      }
    } else {
      throw Exception('Invalid payload.');
    }
  }

  Map<String, String> _readHeaders(List<Object> properties) {
    try {
      final map = properties[1] as Map;
      final headers = map.cast<String, String>();
      return headers;
    } catch (_) {
      throw Exception('Invalid headers.');
    }
  }

  HubMessage _createInvocationMessage(
      Map<String, String> headers, List<Object> properties) {
    // check minimum length to allow protocol to add items to the end of objects in future releases
    if (properties.length < 5) {
      throw Exception('Invalid payload for Invocation message.');
    }

    final invocationId = properties[2] as String;
    if (invocationId != null) {
      return InvocationMessage(
        properties[3] as String,
        properties[4] as List,
        headers: headers,
        invocationId: invocationId,
        streamIds: [],
      );
    } else {
      return InvocationMessage(
        properties[3] as String,
        properties[4] as List,
        headers: headers,
        streamIds: [],
      );
    }
  }

  HubMessage _createStreamItemMessage(
      Map<String, String> headers, List<Object> properties) {
    // check minimum length to allow protocol to add items to the end of objects in future releases
    if (properties.length < 4) {
      throw Exception('Invalid payload for StreamItem message.');
    }

    return StreamItemMessage(
      properties[2] as String,
      headers: headers,
      item: properties[3],
    );
  }

  HubMessage _createCompletionMessage(
      Map<String, String> headers, List<Object> properties) {
    // check minimum length to allow protocol to add items to the end of objects in future releases
    if (properties.length < 4) {
      throw Exception('Invalid payload for Completion message.');
    }

    final resultKind = properties[3] as int;

    if (resultKind != VOID_RESULT && properties.length < 5) {
      throw Exception('Invalid payload for Completion message.');
    }

    String error;
    Object result;

    switch (resultKind) {
      case ERROR_RESULT:
        error = properties[4];
        break;
      case NON_VOID_RESULT:
        result = properties[4];
        break;
    }

    final completionMessage = CompletionMessage(
      properties[2] as String,
      headers: headers,
      error: error,
      result: result,
    );

    return completionMessage;
  }

  HubMessage _createPingMessage(List<Object> properties) {
    // check minimum length to allow protocol to add items to the end of objects in future releases
    if (properties.isEmpty) {
      throw Exception('Invalid payload for Ping message.');
    }

    // Ping messages have no headers.
    return PingMessage();
  }

  HubMessage _createCloseMessage(List<Object> properties) {
    // check minimum length to allow protocol to add items to the end of objects in future releases
    if (properties.length < 2) {
      throw Exception('Invalid payload for Close message.');
    }

    return CloseMessage(
      // Close messages have no headers.
      allowReconnect: properties.length >= 3 ? properties[2] : null,
      error: properties[1],
    );
  }

  Uint8List _writeInvocation(InvocationMessage message) {
    Uint8List payload;
    if (message.streamIds != null) {
      payload = _codec.encode([
        MessageType.invocation.value,
        message.headers ?? {},
        message.invocationId,
        message.target,
        message.arguments,
        message.streamIds,
      ]);
    } else {
      payload = _codec.encode([
        MessageType.invocation.value,
        message.headers ?? {},
        message.invocationId,
        message.target,
        message.arguments,
      ]);
    }

    return BinaryMessageFormat.write(payload);
  }

  Uint8List _writeStreamInvocation(StreamInvocationMessage message) {
    Uint8List payload;
    if (message.streamIds != null) {
      payload = _codec.encode([
        MessageType.streamInvocation.value,
        message.headers ?? {},
        message.invocationId,
        message.target,
        message.arguments,
        message.streamIds,
      ]);
    } else {
      payload = _codec.encode([
        MessageType.streamInvocation.value,
        message.headers ?? {},
        message.invocationId,
        message.target,
        message.arguments,
      ]);
    }

    return BinaryMessageFormat.write(payload);
  }

  Uint8List _writeStreamItem(StreamItemMessage message) {
    final payload = _codec.encode([
      MessageType.streamItem.value,
      message.headers ?? {},
      message.invocationId,
      message.item,
    ]);

    return BinaryMessageFormat.write(payload);
  }

  Uint8List _writeCompletion(CompletionMessage message) {
    final resultKind = message.error != null
        ? ERROR_RESULT
        : message.result != null
            ? NON_VOID_RESULT
            : VOID_RESULT;

    Uint8List payload;
    switch (resultKind) {
      case ERROR_RESULT:
        payload = _codec.encode([
          MessageType.completion.value,
          message.headers ?? {},
          message.invocationId,
          resultKind,
          message.error,
        ]);
        break;
      case VOID_RESULT:
        payload = _codec.encode([
          MessageType.completion.value,
          message.headers ?? {},
          message.invocationId,
          resultKind,
        ]);
        break;
      case NON_VOID_RESULT:
        payload = _codec.encode([
          MessageType.completion.value,
          message.headers ?? {},
          message.invocationId,
          resultKind,
          message.result,
        ]);
        break;
    }

    return BinaryMessageFormat.write(payload);
  }

  Uint8List _writeCancelInvocation(CancelInvocationMessage message) {
    final payload = _codec.encode([
      MessageType.cancelInvocation.value,
      message.headers ?? {},
      message.invocationId
    ]);

    return BinaryMessageFormat.write(payload);
  }
}
