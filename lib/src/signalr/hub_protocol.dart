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
  Map<String, String> get headers;

  /// The ID of the invocation relating to this message.
  ///
  /// This is expected to be present for [StreamInvocationMessage] and [CompletionMessage]. It may
  /// be null for an [InvocationMessage] if the sender does not expect a response.
  String get invocationId;
}

/// A hub message representing a non-streaming invocation.
abstract class InvocationMessage extends HubInvocationMessage {
  /// The target method name.
  String get target;

  /// The target method arguments.
  List<Object> get arguments;

  /// The target methods stream IDs.
  List<String> get streamIds;

  factory InvocationMessage(String target, List<Object> arguments,
      {Map<String, String> headers,
      String invocationId,
      List<String> streamIds}) {
    return _InvocationMessage(
        headers, invocationId, target, arguments, streamIds);
  }

  factory InvocationMessage.fromJSON(Map<String, Object> obj) {
    obj.verify('type', MessageType.invocation.toJSON());
    final headers =
        (obj['headers'] as Map<String, Object>)?.cast<String, String>();
    final invocationId = obj['invocationId'] as String;
    final target = obj['target'] as String;
    final arguments = obj['arguments'] as List<Object>;
    final streamIds = (obj['streamIds'] as List<Object>)?.cast<String>();
    return _InvocationMessage(
        headers, invocationId, target, arguments, streamIds);
  }

  Map<String, Object> toJSON();
}

class _InvocationMessage implements InvocationMessage {
  @override
  final MessageType type;
  @override
  final Map<String, String> headers;
  @override
  final String invocationId;
  @override
  final String target;
  @override
  final List<Object> arguments;
  @override
  final List<String> streamIds;

  _InvocationMessage(this.headers, this.invocationId, this.target,
      this.arguments, this.streamIds)
      : type = MessageType.invocation;

  @override
  Map<String, Object> toJSON() {
    final obj = <String, Object>{
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
abstract class StreamInvocationMessage extends HubInvocationMessage {
  /// The target method name.
  String get target;

  /// The target method arguments.
  List<Object> get arguments;

  /// The target methods stream IDs.
  List<String> get streamIds;

  factory StreamInvocationMessage(
      String invocationId, String target, List<Object> arguments,
      {Map<String, String> headers, List<String> streamIds}) {
    return _StreamInvocationMessage(
        headers, invocationId, target, arguments, streamIds);
  }

  factory StreamInvocationMessage.fromJSON(Map<String, Object> obj) {
    obj.verify('type', MessageType.streamInvocation.toJSON());
    final headers =
        ((obj['headers'] as Map<String, Object>)?.cast<String, String>())
            ?.cast<String, String>();
    final invocationId = obj['invocationId'] as String;
    final target = obj['target'] as String;
    final arguments = obj['arguments'] as List<Object>;
    final streamIds = (obj['streamIds'] as List<Object>)?.cast<String>();
    return _StreamInvocationMessage(
        headers, invocationId, target, arguments, streamIds);
  }

  Map<String, Object> toJSON();
}

class _StreamInvocationMessage implements StreamInvocationMessage {
  @override
  final MessageType type;
  @override
  final Map<String, String> headers;
  @override
  final String invocationId;
  @override
  final String target;
  @override
  final List<Object> arguments;
  @override
  final List<String> streamIds;

  _StreamInvocationMessage(this.headers, this.invocationId, this.target,
      this.arguments, this.streamIds)
      : type = MessageType.streamInvocation;

  @override
  Map<String, Object> toJSON() {
    final obj = <String, Object>{
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
abstract class StreamItemMessage extends HubInvocationMessage {
  /// The item produced by the server.
  Object get item;

  factory StreamItemMessage(String invocationId,
      {Map<String, String> headers, Object item}) {
    return _StreamItemMessage(headers, invocationId, item);
  }

  factory StreamItemMessage.fromJSON(Map<String, Object> obj) {
    obj.verify('type', MessageType.streamItem.toJSON());
    final headers =
        (obj['headers'] as Map<String, Object>)?.cast<String, String>();
    final invocationId = obj['invocationId'] as String;
    final item = obj['item'];
    return _StreamItemMessage(headers, invocationId, item);
  }

  Map<String, Object> toJSON();
}

class _StreamItemMessage implements StreamItemMessage {
  @override
  final MessageType type;
  @override
  final Map<String, String> headers;
  @override
  final String invocationId;
  @override
  final Object item;

  _StreamItemMessage(this.headers, this.invocationId, this.item)
      : type = MessageType.streamItem;

  @override
  Map<String, Object> toJSON() {
    final obj = <String, Object>{
      'type': type,
      'invocationId': invocationId,
    };
    obj.writeNotNull('headers', headers);
    obj.writeNotNull('item', item);
    return obj;
  }
}

/// A hub message representing the result of an invocation.
abstract class CompletionMessage extends HubInvocationMessage {
  /// The error produced by the invocation, if any.
  ///
  /// Either [CompletionMessage.error] or [CompletionMessage.result] must be defined, but not both.
  String get error;

  /// The result produced by the invocation, if any.
  ///
  /// Either [CompletionMessage.error] or [CompletionMessage.result] must be defined, but not both.
  Object get result;

  factory CompletionMessage(String invocationId,
      {Map<String, String> headers, String error, Object result}) {
    return _CompletionMessage(headers, invocationId, error, result);
  }

  factory CompletionMessage.fromJSON(Map<String, Object> obj) {
    obj.verify('type', MessageType.completion.toJSON());
    final headers =
        (obj['headers'] as Map<String, Object>)?.cast<String, String>();
    final invocationId = obj['invocationId'] as String;
    final error = obj['error'] as String;
    final result = obj['result'];
    return _CompletionMessage(headers, invocationId, error, result);
  }

  Map<String, Object> toJSON();
}

class _CompletionMessage implements CompletionMessage {
  @override
  final MessageType type;
  @override
  final Map<String, String> headers;
  @override
  final String invocationId;
  @override
  final String error;
  @override
  final Object result;

  _CompletionMessage(this.headers, this.invocationId, this.error, this.result)
      : type = MessageType.completion;

  @override
  Map<String, Object> toJSON() {
    final obj = <String, Object>{
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
abstract class CancelInvocationMessage extends HubInvocationMessage {
  factory CancelInvocationMessage(String invocationId,
      {Map<String, String> headers}) {
    return _CancelInvocationMessage(headers, invocationId);
  }

  factory CancelInvocationMessage.fromJSON(Map<String, Object> obj) {
    obj.verify('type', MessageType.cancelInvocation.toJSON());
    final headers =
        (obj['headers'] as Map<String, Object>)?.cast<String, String>();
    final invocationId = obj['invocationId'];
    return _CancelInvocationMessage(headers, invocationId);
  }

  Map<String, Object> toJSON();
}

class _CancelInvocationMessage implements CancelInvocationMessage {
  @override
  final MessageType type;
  @override
  final Map<String, String> headers;
  @override
  final String invocationId;

  _CancelInvocationMessage(this.headers, this.invocationId)
      : type = MessageType.cancelInvocation;

  @override
  Map<String, Object> toJSON() {
    final obj = <String, Object>{
      'type': type,
      'invocationId': invocationId,
    };
    obj.writeNotNull('headers', headers);
    return obj;
  }
}

/// A hub message indicating that the sender is still active.
abstract class PingMessage extends HubMessage {
  factory PingMessage() {
    return _PingMessage();
  }

  factory PingMessage.fromJSON(Map<String, Object> obj) {
    obj.verify('type', MessageType.ping.toJSON());
    return _PingMessage();
  }

  Map<String, Object> toJSON();
}

class _PingMessage implements PingMessage {
  @override
  final MessageType type;

  _PingMessage() : type = MessageType.ping;

  @override
  Map<String, Object> toJSON() {
    final obj = <String, Object>{
      'type': type,
    };
    return obj;
  }
}

/// A hub message indicating that the sender is closing the connection.
///
/// If [CloseMessage.error] is defined, the sender is closing the connection due to an error.
abstract class CloseMessage extends HubMessage {
  /// The error that triggered the close, if any.
  ///
  /// If this property is undefined, the connection was closed normally and without error.
  String get error;

  /// If true, clients with automatic reconnects enabled should attempt to reconnect after receiving the CloseMessage. Otherwise, they should not.
  bool get allowReconnect;

  factory CloseMessage({String error, bool allowReconnect}) {
    return _CloseMessage(error, allowReconnect);
  }

  factory CloseMessage.fromJSON(Map<String, Object> obj) {
    obj.verify('type', MessageType.close.toJSON());
    final error = obj['error'] as String;
    final allowReconnect = obj['allowReconnect'] as bool;
    return _CloseMessage(error, allowReconnect);
  }

  Map<String, Object> toJSON();
}

class _CloseMessage implements CloseMessage {
  @override
  final MessageType type;
  @override
  final String error;
  @override
  final bool allowReconnect;

  _CloseMessage(this.error, this.allowReconnect) : type = MessageType.close;

  @override
  Map<String, Object> toJSON() {
    final obj = <String, Object>{
      'type': type,
    };
    obj.writeNotNull('error', error);
    obj.writeNotNull('allowReconnect', allowReconnect);
    return obj;
  }
}

/// Defines the type of a Hub Message.
abstract class MessageType {
  String get name;
  int get value;

  int toJSON();

  /// Indicates the message is an Invocation message and implements the [InvocationMessage] interface.
  static const MessageType invocation = _MessageType('Invocation', 1);

  /// Indicates the message is a StreamItem message and implements the [StreamItemMessage] interface.
  static const MessageType streamItem = _MessageType('StreamItem', 2);

  /// Indicates the message is a Completion message and implements the [CompletionMessage] interface.
  static const MessageType completion = _MessageType('Completion', 3);

  /// Indicates the message is a Stream Invocation message and implements the [StreamInvocationMessage] interface.
  static const MessageType streamInvocation =
      _MessageType('StreamInvocation', 4);

  /// Indicates the message is a Cancel Invocation message and implements the [CancelInvocationMessage] interface.
  static const MessageType cancelInvocation =
      _MessageType('CancelInvocation', 5);

  /// Indicates the message is a Ping message and implements the [PingMessage] interface.
  static const MessageType ping = _MessageType('Ping', 6);

  /// Indicates the message is a Close message and implements the [CloseMessage] interface.
  static const MessageType close = _MessageType('Close', 7);

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
}

class _MessageType implements MessageType {
  @override
  final String name;
  @override
  final int value;

  const _MessageType(this.name, this.value);

  @override
  int toJSON() {
    return value;
  }

  @override
  String toString() {
    return name;
  }
}
