import 'package:cure/convert.dart';

import 'logger.dart';
import 'transport.dart';

/// A protocol abstraction for communicating with Signalr Hubs.
abstract class HubProtocol {
  /// The name of the protocol. This is used by Signalr to resolve the protocol between the client and server.
  String get name;

  /// The version of the protocol.
  int get version;

  /// The [TransferFormat] of the protocol.
  TransferFormat get transferFormat;

  /// Creates an array of [HubMessage] objects from the specified serialized representation.
  ///
  /// If [HubProtocol.transferFormat] is 'Text', the `input` parameter must be a string, otherwise it must be an Uint8List.
  ///
  /// [input] A string, Uint8List containing the serialized representation.
  ///
  /// [logger] A logger that will be used to log messages that occur during parsing.
  List<HubMessage> parseMessages(Object input, Logger logger);

  /// Writes the specified {@link @microsoft/signalr.HubMessage} to a string or ArrayBuffer and returns it.
  ///
  /// If [HubProtocol.transferFormat] is 'Text', the result of this method will be a string, otherwise it will be an Uint8List.
  ///
  /// [message] The message to write.
  ///
  /// Returns a string or Uint8List containing the serialized representation of the message.
  Object writeMessage(HubMessage message);
}

/// Defines properties common to all Hub messages.
abstract class HubMessage {
  /// A [MessageType] value indicating the type of this message.
  MessageType get type;
}

/// Defines properties common to all Hub messages relating to a specific invocation.
abstract class HubInvocationMessage implements HubMessage {
  /// A dictionary containing headers attached to the message.
  Map<String, String>? get headers;

  /// The ID of the invocation relating to this message.
  ///
  /// This is expected to be present for [StreamInvocationMessage] and [CompletionMessage]. It may
  /// be null for an [InvocationMessage] if the sender does not expect a response.
  String? get invocationId;
}

/// A hub message representing a non-streaming invocation.
class InvocationMessage implements HubInvocationMessage {
  @override
  final MessageType type;
  @override
  final Map<String, String>? headers;
  @override
  final String? invocationId;

  /// The target method name.
  final String target;

  /// The target method arguments.
  final List<dynamic> arguments;

  /// The target methods stream IDs.
  final List<String>? streamIds;

  InvocationMessage(this.target, this.arguments,
      {this.headers, this.invocationId, this.streamIds})
      : type = MessageType.invocation;

  factory InvocationMessage.fromJSON(Map<String, dynamic> obj) {
    obj.verify('type', MessageType.invocation.toJSON());
    final headers =
        (obj['headers'] as Map<String, dynamic>?)?.cast<String, String>();
    final invocationId = obj['invocationId'] as String?;
    final target = obj['target'] as String;
    final arguments = obj['arguments'] as List<dynamic>;
    final streamIds = (obj['streamIds'] as List<dynamic>?)?.cast<String>();
    return InvocationMessage(target, arguments,
        headers: headers, invocationId: invocationId, streamIds: streamIds);
  }

  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{
      'type': type,
      'target': target,
      'arguments': arguments,
    };
    obj.writeNotNull('headers', headers);
    obj.writeNotNull('invocationId', invocationId);
    obj.writeNotNull('streamIds', streamIds);
    return obj;
  }
}

/// A hub message representing a streaming invocation.
class StreamInvocationMessage implements HubInvocationMessage {
  @override
  final MessageType type;
  @override
  final Map<String, String>? headers;
  @override
  final String invocationId;

  /// The target method name.
  final String target;

  /// The target method arguments.
  final List<dynamic> arguments;

  /// The target methods stream IDs.
  final List<String>? streamIds;

  StreamInvocationMessage(this.invocationId, this.target, this.arguments,
      {this.headers, this.streamIds})
      : type = MessageType.streamInvocation;

  factory StreamInvocationMessage.fromJSON(Map<String, dynamic> obj) {
    obj.verify('type', MessageType.streamInvocation.toJSON());
    final headers =
        (obj['headers'] as Map<String, dynamic>?)?.cast<String, String>();
    final invocationId = obj['invocationId'] as String;
    final target = obj['target'] as String;
    final arguments = obj['arguments'] as List<dynamic>;
    final streamIds = (obj['streamIds'] as List<dynamic>?)?.cast<String>();
    return StreamInvocationMessage(invocationId, target, arguments,
        headers: headers, streamIds: streamIds);
  }

  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{
      'type': type,
      'invocationId': invocationId,
      'target': target,
      'arguments': arguments,
    };
    obj.writeNotNull('headers', headers);
    obj.writeNotNull('streamIds', streamIds);
    return obj;
  }
}

/// A hub message representing a single item produced as part of a result stream.
class StreamItemMessage implements HubInvocationMessage {
  @override
  final MessageType type;
  @override
  final Map<String, String>? headers;
  @override
  final String invocationId;

  /// The item produced by the server.
  final dynamic item;

  StreamItemMessage(this.invocationId, {this.headers, this.item})
      : type = MessageType.streamItem;

  factory StreamItemMessage.fromJSON(Map<String, dynamic> obj) {
    obj.verify('type', MessageType.streamItem.toJSON());
    final headers =
        (obj['headers'] as Map<String, dynamic>?)?.cast<String, String>();
    final invocationId = obj['invocationId'] as String;
    final item = obj['item'];
    return StreamItemMessage(invocationId, headers: headers, item: item);
  }

  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{
      'type': type,
      'invocationId': invocationId,
    };
    obj.writeNotNull('headers', headers);
    obj.writeNotNull('item', item);
    return obj;
  }
}

/// A hub message representing the result of an invocation.
class CompletionMessage implements HubInvocationMessage {
  @override
  final MessageType type;
  @override
  final Map<String, String>? headers;
  @override
  final String invocationId;

  /// The error produced by the invocation, if any.
  ///
  /// Either [CompletionMessage.error] or [CompletionMessage.result] must be defined, but not both.
  final String? error;

  /// The result produced by the invocation, if any.
  ///
  /// Either [CompletionMessage.error] or [CompletionMessage.result] must be defined, but not both.
  final Object? result;

  CompletionMessage(this.invocationId, {this.headers, this.error, this.result})
      : type = MessageType.completion;

  factory CompletionMessage.fromJSON(Map<String, dynamic> obj) {
    obj.verify('type', MessageType.completion.toJSON());
    final headers =
        (obj['headers'] as Map<String, dynamic>?)?.cast<String, String>();
    final invocationId = obj['invocationId'] as String;
    final error = obj['error'] as String?;
    final result = obj['result'];
    return CompletionMessage(invocationId,
        headers: headers, error: error, result: result);
  }

  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{
      'type': type,
      'invocationId': invocationId,
    };
    obj.writeNotNull('headers', headers);
    obj.writeNotNull('error', error);
    obj.writeNotNull('result', result);
    return obj;
  }
}

/// A hub message sent to request that a streaming invocation be canceled.
class CancelInvocationMessage implements HubInvocationMessage {
  @override
  final MessageType type;
  @override
  final Map<String, String>? headers;
  @override
  final String invocationId;

  CancelInvocationMessage(this.invocationId, {this.headers})
      : type = MessageType.cancelInvocation;

  factory CancelInvocationMessage.fromJSON(Map<String, dynamic> obj) {
    obj.verify('type', MessageType.cancelInvocation.toJSON());
    final headers =
        (obj['headers'] as Map<String, dynamic>?)?.cast<String, String>();
    final invocationId = obj['invocationId'] as String;
    return CancelInvocationMessage(invocationId, headers: headers);
  }

  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{
      'type': type,
      'invocationId': invocationId,
    };
    obj.writeNotNull('headers', headers);
    return obj;
  }
}

/// A hub message indicating that the sender is still active.
class PingMessage implements HubMessage {
  @override
  final MessageType type;

  PingMessage() : type = MessageType.ping;

  factory PingMessage.fromJSON(Map<String, dynamic> obj) {
    obj.verify('type', MessageType.ping.toJSON());
    return PingMessage();
  }

  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{
      'type': type,
    };
    return obj;
  }
}

/// A hub message indicating that the sender is closing the connection.
///
/// If [CloseMessage.error] is defined, the sender is closing the connection due to an error.
class CloseMessage implements HubMessage {
  @override
  final MessageType type;

  /// The error that triggered the close, if any.
  ///
  /// If this property is undefined, the connection was closed normally and without error.
  final String? error;

  /// If true, clients with automatic reconnects enabled should attempt to reconnect after receiving the CloseMessage. Otherwise, they should not.
  final bool? allowReconnect;

  CloseMessage({this.error, this.allowReconnect}) : type = MessageType.close;

  factory CloseMessage.fromJSON(Map<String, dynamic> obj) {
    obj.verify('type', MessageType.close.toJSON());
    final error = obj['error'] as String?;
    final allowReconnect = obj['allowReconnect'] as bool?;
    return CloseMessage(error: error, allowReconnect: allowReconnect);
  }

  Map<String, dynamic> toJSON() {
    final obj = <String, dynamic>{
      'type': type,
    };
    obj.writeNotNull('error', error);
    obj.writeNotNull('allowReconnect', allowReconnect);
    return obj;
  }
}

/// Defines the type of a Hub Message.
class MessageType {
  final String name;
  final int value;

  /// Indicates the message is an Invocation message and implements the [InvocationMessage] interface.
  static const MessageType invocation = MessageType('Invocation', 1);

  /// Indicates the message is a StreamItem message and implements the [StreamItemMessage] interface.
  static const MessageType streamItem = MessageType('StreamItem', 2);

  /// Indicates the message is a Completion message and implements the [CompletionMessage] interface.
  static const MessageType completion = MessageType('Completion', 3);

  /// Indicates the message is a Stream Invocation message and implements the [StreamInvocationMessage] interface.
  static const MessageType streamInvocation =
      MessageType('StreamInvocation', 4);

  /// Indicates the message is a Cancel Invocation message and implements the [CancelInvocationMessage] interface.
  static const MessageType cancelInvocation =
      MessageType('CancelInvocation', 5);

  /// Indicates the message is a Ping message and implements the [PingMessage] interface.
  static const MessageType ping = MessageType('Ping', 6);

  /// Indicates the message is a Close message and implements the [CloseMessage] interface.
  static const MessageType close = MessageType('Close', 7);

  const MessageType(this.name, this.value);

  factory MessageType.fromJSON(int obj) {
    switch (obj) {
      case 1:
        return invocation;
      case 2:
        return streamItem;
      case 3:
        return completion;
      case 4:
        return streamInvocation;
      case 5:
        return cancelInvocation;
      case 6:
        return ping;
      case 7:
        return close;
      default:
        throw ArgumentError.value(obj);
    }
  }

  int toJSON() {
    return value;
  }

  @override
  String toString() {
    return name;
  }
}
