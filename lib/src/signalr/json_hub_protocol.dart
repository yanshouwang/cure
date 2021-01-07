import 'package:cure/convert.dart';

import 'hub_protocol.dart';
import 'logger.dart';
import 'text_message_format.dart';
import 'transport.dart';

/// Implements the JSON Hub Protocol.
class JsonHubProtocol implements HubProtocol {
  @override
  String get name => 'json';
  @override
  int get version => 1;
  @override
  TransferFormat get transferFormat => TransferFormat.text;

  /// Creates an array of [HubMessage] objects from the specified serialized representation.
  ///
  /// [input] A string containing the serialized representation.
  /// [logger] A logger that will be used to log messages that occur during parsing.
  @override
  List<HubMessage> parseMessages(Object input, Logger logger) {
    if (input is String) {
      final hubMessages = <HubMessage>[];
      if (input != null) {
        logger ??= NullLogger();
        // Parse the messages
        final messages = TextMessageFormat.parse(input);
        for (final message in messages) {
          final obj = json.decode(message) as Map<String, Object>;
          final type = obj['type'];
          if (type is int) {
            final value = MessageType.fromJSON(type);
            HubMessage parsedMessage;
            switch (value) {
              case MessageType.invocation:
                try {
                  parsedMessage = InvocationMessage.fromJSON(obj);
                  _isInvocationMessage(parsedMessage);
                } catch (_) {
                  throw Exception('Invalid payload for Invocation message.');
                }
                break;
              case MessageType.streamItem:
                try {
                  parsedMessage = StreamItemMessage.fromJSON(obj);
                  _isStreamItemMessage(parsedMessage);
                } catch (_) {
                  throw Exception('Invalid payload for StreamItem message.');
                }
                break;
              case MessageType.completion:
                try {
                  parsedMessage = CompletionMessage.fromJSON(obj);
                  _isCompletionMessage(parsedMessage);
                } catch (_) {
                  throw Exception('Invalid payload for Completion message.');
                }
                break;
              case MessageType.ping:
                parsedMessage = PingMessage.fromJSON(obj);
                // Single value, no need to validate
                break;
              case MessageType.close:
                parsedMessage = CloseMessage.fromJSON(obj);
                // All optional values, no need to validate
                break;
              default:
                // Future protocol changes can add message types, old clients can ignore them
                logger.log(LogLevel.information,
                    "Unknown message type '$value' ignored.");
                continue;
            }
            hubMessages.add(parsedMessage);
          } else {
            throw Exception('Invalid payload.');
          }
        }
      }
      return hubMessages;
    } else {
      throw Exception(
          'Invalid input for JSON hub protocol. Expected a string.');
    }
  }

  /// Writes the specified [HubMessage] to a string and returns it.
  ///
  /// message The message to write.
  /// Returns a string containing the serialized representation of the message.
  @override
  Object writeMessage(HubMessage message) {
    final output = json.encode(message);
    return TextMessageFormat.write(output);
  }

  void _isInvocationMessage(InvocationMessage message) {
    _assertNotEmptyString(
        message.target, 'Invalid payload for Invocation message.');

    if (message.invocationId != null) {
      _assertNotEmptyString(
          message.invocationId, 'Invalid payload for Invocation message.');
    }
  }

  void _isStreamItemMessage(StreamItemMessage message) {
    _assertNotEmptyString(
        message.invocationId, 'Invalid payload for StreamItem message.');

    if (message.item == null) {
      throw Exception('Invalid payload for StreamItem message.');
    }
  }

  void _isCompletionMessage(CompletionMessage message) {
    if (message.result != null && message.error != null) {
      throw Exception('Invalid payload for Completion message.');
    }

    if (message.result == null && message.error != null) {
      _assertNotEmptyString(
          message.error, 'Invalid payload for Completion message.');
    }

    _assertNotEmptyString(
        message.invocationId, 'Invalid payload for Completion message.');
  }

  void _assertNotEmptyString(Object value, String errorMessage) {
    if (value is String && value.isNotEmpty) {
      // value is not empty string, just continue.
    } else {
      throw Exception(errorMessage);
    }
  }
}
