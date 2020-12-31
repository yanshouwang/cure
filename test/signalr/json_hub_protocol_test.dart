import 'package:cure/signalr.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  test('# Can write/read non-blocking Invocation message', () async {
    await VerifyLogger.runAsync((logger) async {
      final invocation = InvocationMessage(
        'myMethod',
        [
          42,
          true,
          'test',
          ['x1', 'y2'],
          null,
        ],
        headers: {},
      );

      final protocol = JSONHubProtocol();
      final messages = protocol.parseMessages(
        protocol.writeMessage(invocation),
        logger,
      );
      expect(messages.length, 1);
      expect(
        messages[0],
        isA<InvocationMessage>(),
      );
      final message = messages[0] as InvocationMessage;
      expect(message.target, invocation.target);
      expect(message.arguments, invocation.arguments);
      expect(message.headers, invocation.headers);
      expect(
        [message.invocationId, message.streamIds],
        everyElement(isNull),
      );
    });
  });
  test('# Can read Invocation message with Date argument', () async {
    await VerifyLogger.runAsync((logger) async {
      final invocation = InvocationMessage(
        'myMethod',
        [
          DateTime.utc(2018, 1, 1, 12, 34, 56).millisecondsSinceEpoch,
        ],
        headers: {},
      );

      final protocol = JSONHubProtocol();
      final messages = protocol.parseMessages(
        protocol.writeMessage(invocation),
        logger,
      );
      expect(messages.length, 1);
      expect(
        messages[0],
        isA<InvocationMessage>(),
      );
      final message = messages[0] as InvocationMessage;
      expect(message.target, invocation.target);
      expect(message.arguments, invocation.arguments);
      expect(message.headers, invocation.headers);
      expect(
        [message.invocationId, message.streamIds],
        everyElement(isNull),
      );
    });
  });
  test('# Can write/read Invocation message with headers', () async {
    await VerifyLogger.runAsync((logger) async {
      final invocation = InvocationMessage(
        'myMethod',
        [
          42,
          true,
          'test',
          ['x1', 'y2'],
          null,
        ],
        headers: <String, String>{
          'foo': 'bar',
        },
      );

      final protocol = JSONHubProtocol();
      final messages = protocol.parseMessages(
        protocol.writeMessage(invocation),
        logger,
      );
      expect(messages.length, 1);
      expect(
        messages[0],
        isA<InvocationMessage>(),
      );
      final message = messages[0] as InvocationMessage;
      expect(message.target, invocation.target);
      expect(message.arguments, invocation.arguments);
      expect(message.headers, invocation.headers);
      expect(
        [message.invocationId, message.streamIds],
        everyElement(isNull),
      );
    });
  });
  test('# Can write/read Invocation message', () async {
    await VerifyLogger.runAsync((logger) async {
      final invocation = InvocationMessage(
        'myMethod',
        [
          42,
          true,
          'test',
          ['x1', 'y2'],
          null,
        ],
        headers: {},
      );

      final protocol = JSONHubProtocol();
      final messages = protocol.parseMessages(
        protocol.writeMessage(invocation),
        logger,
      );
      expect(messages.length, 1);
      expect(
        messages[0],
        isA<InvocationMessage>(),
      );
      final message = messages[0] as InvocationMessage;
      expect(message.target, invocation.target);
      expect(message.arguments, invocation.arguments);
      expect(message.headers, invocation.headers);
      expect(
        [message.invocationId, message.streamIds],
        everyElement(isNull),
      );
    });
  });

  [
    MapEntry(
      '{"type":3, "invocationId": "abc", "error": "Err", "result": null, "headers": {}}${TextMessageFormat.recordSeparator}',
      CompletionMessage(
        'abc',
        headers: {},
        error: 'Err',
        result: null,
      ),
    ),
    MapEntry(
      '{"type":3, "invocationId": "abc", "result": "OK", "headers": {}}${TextMessageFormat.recordSeparator}',
      CompletionMessage(
        'abc',
        headers: {},
        result: 'OK',
      ),
    ),
    MapEntry(
      '{"type":3, "invocationId": "abc", "result": null, "headers": {}}${TextMessageFormat.recordSeparator}',
      CompletionMessage(
        'abc',
        headers: {},
        result: null,
      ),
    ),
    MapEntry(
      '{"type":3, "invocationId": "abc", "result": 1514805840000, "headers": {}}${TextMessageFormat.recordSeparator}',
      CompletionMessage(
        'abc',
        headers: {},
        result: DateTime.utc(2018, 1, 1, 11, 24, 0).millisecondsSinceEpoch,
      ),
    ),
    MapEntry(
      '{"type":3, "invocationId": "abc", "result": null, "headers": {}, "extraParameter":"value"}${TextMessageFormat.recordSeparator}',
      CompletionMessage(
        'abc',
        headers: {},
        result: null,
      ),
    ),
  ].forEach((entry) {
    test('# Can read Completion message', () async {
      final payload = entry.key;
      final invocation = entry.value;
      await VerifyLogger.runAsync((logger) async {
        final messages = JSONHubProtocol().parseMessages(payload, logger);
        expect(messages.length, 1);
        expect(
          messages[0],
          isA<CompletionMessage>(),
        );
        final message = messages[0] as CompletionMessage;
        expect(message.invocationId, invocation.invocationId);
        expect(message.headers, invocation.headers);
        expect(message.error, invocation.error);
        expect(message.result, invocation.result);
      });
    });
  });

  [
    MapEntry(
      '{"type":2, "invocationId": "abc", "headers": {}, "item": 8}${TextMessageFormat.recordSeparator}',
      StreamItemMessage(
        'abc',
        headers: {},
        item: 8,
      ),
    ),
    MapEntry(
      '{"type":2, "invocationId": "abc", "headers": {}, "item": 1514805840000}${TextMessageFormat.recordSeparator}',
      StreamItemMessage(
        'abc',
        headers: {},
        item: DateTime.utc(2018, 1, 1, 11, 24, 0).millisecondsSinceEpoch,
      ),
    ),
  ].forEach((entry) {
    test('# Can read StreamItem message', () async {
      final payload = entry.key;
      final invocation = entry.value;
      await VerifyLogger.runAsync((logger) async {
        final messages = JSONHubProtocol().parseMessages(payload, logger);
        expect(messages.length, 1);
        expect(
          messages[0],
          isA<StreamItemMessage>(),
        );
        final message = messages[0] as StreamItemMessage;
        expect(message.invocationId, invocation.invocationId);
        expect(message.headers, invocation.headers);
        expect(message.item, invocation.item);
      });
    });
  });

  [
    MapEntry(
      '{"type":2, "invocationId": "abc", "headers": {"t": "u"}, "item": 8}${TextMessageFormat.recordSeparator}',
      StreamItemMessage(
        'abc',
        headers: <String, String>{
          't': 'u',
        },
        item: 8,
      ),
    ),
  ].forEach((entry) {
    test('# Can read message with headers', () async {
      final payload = entry.key;
      final invocation = entry.value;
      await VerifyLogger.runAsync((logger) async {
        final messages = JSONHubProtocol().parseMessages(payload, logger);
        expect(messages.length, 1);
        expect(
          messages[0],
          isA<StreamItemMessage>(),
        );
        final message = messages[0] as StreamItemMessage;
        expect(message.invocationId, invocation.invocationId);
        expect(message.headers, invocation.headers);
        expect(message.item, invocation.item);
      });
    });
  });

  [
    [
      'message with empty payload',
      '{}${TextMessageFormat.recordSeparator}',
      'Exception: Invalid payload.'
    ],
    [
      'Invocation message with invalid invocation id',
      '{"type":1,"invocationId":1,"target":"method"}${TextMessageFormat.recordSeparator}',
      'Exception: Invalid payload for Invocation message.'
    ],
    [
      'Invocation message with empty string invocation id',
      '{"type":1,"invocationId":"","target":"method"}${TextMessageFormat.recordSeparator}',
      'Exception: Invalid payload for Invocation message.'
    ],
    [
      'Invocation message with invalid target',
      '{"type":1,"invocationId":"1","target":1}${TextMessageFormat.recordSeparator}',
      'Exception: Invalid payload for Invocation message.'
    ],
    [
      'StreamItem message with missing invocation id',
      '{"type":2}${TextMessageFormat.recordSeparator}',
      'Exception: Invalid payload for StreamItem message.'
    ],
    [
      'StreamItem message with invalid invocation id',
      '{"type":2,"invocationId":1}${TextMessageFormat.recordSeparator}',
      'Exception: Invalid payload for StreamItem message.'
    ],
    [
      'Completion message with missing invocation id',
      '{"type":3}${TextMessageFormat.recordSeparator}',
      'Exception: Invalid payload for Completion message.'
    ],
    [
      'Completion message with invalid invocation id',
      '{"type":3,"invocationId":1}${TextMessageFormat.recordSeparator}',
      'Exception: Invalid payload for Completion message.'
    ],
    [
      'Completion message with result and error',
      '{"type":3,"invocationId":"1","result":2,"error":"error"}${TextMessageFormat.recordSeparator}',
      'Exception: Invalid payload for Completion message.'
    ],
    [
      'Completion message with non-string error',
      '{"type":3,"invocationId":"1","error":21}${TextMessageFormat.recordSeparator}',
      'Exception: Invalid payload for Completion message.'
    ],
  ].forEach((element) {
    final name = element[0];
    final payload = element[1];
    final expectedError = element[2];
    test('# Throws for $name', () async {
      await VerifyLogger.runAsync((logger) async {
        final m = predicate((e) => '$e' == expectedError);
        final matcher = throwsA(m);
        expect(() => JSONHubProtocol().parseMessages(payload, logger), matcher);
      });
    });
  });

  test('# Can read multiple messages', () async {
    await VerifyLogger.runAsync((logger) async {
      final payload =
          '{"type":2, "invocationId": "abc", "headers": {}, "item": 8}${TextMessageFormat.recordSeparator}{"type":3, "invocationId": "abc", "headers": {}, "result": "OK"}${TextMessageFormat.recordSeparator}';
      final messages = JSONHubProtocol().parseMessages(payload, logger);
      expect(messages.length, 2);
      expect(
        messages[0],
        isA<StreamItemMessage>(),
      );
      expect(
        messages[1],
        isA<CompletionMessage>(),
      );
      final message1 = messages[0] as StreamItemMessage;
      final message2 = messages[1] as CompletionMessage;
      expect(message1.invocationId, 'abc');
      expect(message1.headers, isEmpty);
      expect(message1.item, 8);
      expect(message2.invocationId, 'abc');
      expect(message2.headers, isEmpty);
      expect(message2.error, isNull);
      expect(message2.result, 'OK');
    });
  });
  test('# Can read ping message', () async {
    await VerifyLogger.runAsync((logger) async {
      final payload = '{"type":6}${TextMessageFormat.recordSeparator}';
      final messages = JSONHubProtocol().parseMessages(payload, logger);
      expect(messages.length, 1);
      expect(
        messages[0],
        isA<PingMessage>(),
      );
    });
  });
}
