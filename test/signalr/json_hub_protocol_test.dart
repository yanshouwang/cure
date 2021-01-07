import 'package:cure/signalr.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import 'common.dart';

void main() {
  test('# can write/read non-blocking Invocation message', () async {
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

      final protocol = JsonHubProtocol();
      final data = protocol.writeMessage(invocation);
      final messages = protocol.parseMessages(data, logger);
      expect(messages.length, 1);
      expect(
        messages[0],
        isA<InvocationMessage>(),
      );
      final message = messages[0] as InvocationMessage;
      matchInvocationMessage(message, invocation);
    });
  });
  test('# can read Invocation message with Date argument', () async {
    await VerifyLogger.runAsync((logger) async {
      final invocation = InvocationMessage(
        'myMethod',
        [DateTime.utc(2018, 1, 1, 12, 34, 56).millisecondsSinceEpoch],
        headers: {},
      );

      final protocol = JsonHubProtocol();
      final data = protocol.writeMessage(invocation);
      final messages = protocol.parseMessages(data, logger);
      expect(messages.length, 1);
      expect(
        messages[0],
        isA<InvocationMessage>(),
      );
      final message = messages[0] as InvocationMessage;
      matchInvocationMessage(message, invocation);
    });
  });
  test('# can write/read Invocation message with headers', () async {
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

      final protocol = JsonHubProtocol();
      final data = protocol.writeMessage(invocation);
      final messages = protocol.parseMessages(data, logger);
      expect(messages.length, 1);
      expect(
        messages[0],
        isA<InvocationMessage>(),
      );
      final message = messages[0] as InvocationMessage;
      matchInvocationMessage(message, invocation);
    });
  });
  test('# can write/read Invocation message', () async {
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

      final protocol = JsonHubProtocol();
      final data = protocol.writeMessage(invocation);
      final messages = protocol.parseMessages(data, logger);
      expect(messages.length, 1);
      expect(
        messages[0],
        isA<InvocationMessage>(),
      );
      final message = messages[0] as InvocationMessage;
      matchInvocationMessage(message, invocation);
    });
  });

  [
    Tuple2(
      '{"type":3, "invocationId": "abc", "error": "Err", "result": null, "headers": {}}${TextMessageFormat.recordSeparator}',
      CompletionMessage(
        'abc',
        headers: {},
        error: 'Err',
        result: null,
      ),
    ),
    Tuple2(
      '{"type":3, "invocationId": "abc", "result": "OK", "headers": {}}${TextMessageFormat.recordSeparator}',
      CompletionMessage(
        'abc',
        headers: {},
        result: 'OK',
      ),
    ),
    Tuple2(
      '{"type":3, "invocationId": "abc", "result": null, "headers": {}}${TextMessageFormat.recordSeparator}',
      CompletionMessage(
        'abc',
        headers: {},
        result: null,
      ),
    ),
    Tuple2(
      '{"type":3, "invocationId": "abc", "result": 1514805840000, "headers": {}}${TextMessageFormat.recordSeparator}',
      CompletionMessage(
        'abc',
        headers: {},
        result: DateTime.utc(2018, 1, 1, 11, 24, 0).millisecondsSinceEpoch,
      ),
    ),
    Tuple2(
      '{"type":3, "invocationId": "abc", "result": null, "headers": {}, "extraParameter":"value"}${TextMessageFormat.recordSeparator}',
      CompletionMessage(
        'abc',
        headers: {},
        result: null,
      ),
    ),
  ].forEach((element) {
    test('# can read Completion message', () async {
      await VerifyLogger.runAsync((logger) async {
        final messages = JsonHubProtocol().parseMessages(element.item1, logger);
        expect(messages.length, 1);
        expect(
          messages[0],
          isA<CompletionMessage>(),
        );
        final message = messages[0] as CompletionMessage;
        matchCompletionMessage(message, element.item2);
      });
    });
  });

  [
    Tuple2(
      '{"type":2, "invocationId": "abc", "headers": {}, "item": 8}${TextMessageFormat.recordSeparator}',
      StreamItemMessage(
        'abc',
        headers: {},
        item: 8,
      ),
    ),
    Tuple2(
      '{"type":2, "invocationId": "abc", "headers": {}, "item": 1514805840000}${TextMessageFormat.recordSeparator}',
      StreamItemMessage(
        'abc',
        headers: {},
        item: DateTime.utc(2018, 1, 1, 11, 24, 0).millisecondsSinceEpoch,
      ),
    ),
  ].forEach((element) {
    test('# can read StreamItem message', () async {
      await VerifyLogger.runAsync((logger) async {
        final messages = JsonHubProtocol().parseMessages(element.item1, logger);
        expect(messages.length, 1);
        expect(
          messages[0],
          isA<StreamItemMessage>(),
        );
        final message = messages[0] as StreamItemMessage;
        matchStreamItemMessage(message, element.item2);
      });
    });
  });

  [
    Tuple2(
      '{"type":2, "invocationId": "abc", "headers": {"t": "u"}, "item": 8}${TextMessageFormat.recordSeparator}',
      StreamItemMessage(
        'abc',
        headers: <String, String>{
          't': 'u',
        },
        item: 8,
      ),
    ),
  ].forEach((element) {
    test('# can read message with headers', () async {
      await VerifyLogger.runAsync((logger) async {
        final messages = JsonHubProtocol().parseMessages(element.item1, logger);
        expect(messages.length, 1);
        expect(
          messages[0],
          isA<StreamItemMessage>(),
        );
        final message = messages[0] as StreamItemMessage;
        matchStreamItemMessage(message, element.item2);
      });
    });
  });

  [
    [
      'message with empty payload',
      '{}${TextMessageFormat.recordSeparator}',
      'Invalid payload.'
    ],
    [
      'Invocation message with invalid invocation id',
      '{"type":1,"invocationId":1,"target":"method"}${TextMessageFormat.recordSeparator}',
      'Invalid payload for Invocation message.'
    ],
    [
      'Invocation message with empty string invocation id',
      '{"type":1,"invocationId":"","target":"method"}${TextMessageFormat.recordSeparator}',
      'Invalid payload for Invocation message.'
    ],
    [
      'Invocation message with invalid target',
      '{"type":1,"invocationId":"1","target":1}${TextMessageFormat.recordSeparator}',
      'Invalid payload for Invocation message.'
    ],
    [
      'StreamItem message with missing invocation id',
      '{"type":2}${TextMessageFormat.recordSeparator}',
      'Invalid payload for StreamItem message.'
    ],
    [
      'StreamItem message with invalid invocation id',
      '{"type":2,"invocationId":1}${TextMessageFormat.recordSeparator}',
      'Invalid payload for StreamItem message.'
    ],
    [
      'Completion message with missing invocation id',
      '{"type":3}${TextMessageFormat.recordSeparator}',
      'Invalid payload for Completion message.'
    ],
    [
      'Completion message with invalid invocation id',
      '{"type":3,"invocationId":1}${TextMessageFormat.recordSeparator}',
      'Invalid payload for Completion message.'
    ],
    [
      'Completion message with result and error',
      '{"type":3,"invocationId":"1","result":2,"error":"error"}${TextMessageFormat.recordSeparator}',
      'Invalid payload for Completion message.'
    ],
    [
      'Completion message with non-string error',
      '{"type":3,"invocationId":"1","error":21}${TextMessageFormat.recordSeparator}',
      'Invalid payload for Completion message.'
    ],
  ].forEach((element) {
    test('# throws for ${element[0]}', () async {
      await VerifyLogger.runAsync((logger) async {
        final m = predicate((e) => '$e' == 'Exception: ${element[2]}');
        final matcher = throwsA(m);
        final protocol = JsonHubProtocol();
        expect(() => protocol.parseMessages(element[1], logger), matcher);
      });
    });
  });

  test('# can read multiple messages', () async {
    await VerifyLogger.runAsync((logger) async {
      final data =
          '{"type":2, "invocationId": "abc", "headers": {}, "item": 8}${TextMessageFormat.recordSeparator}{"type":3, "invocationId": "abc", "headers": {}, "result": "OK"}${TextMessageFormat.recordSeparator}';
      final messages = JsonHubProtocol().parseMessages(data, logger);
      expect(messages.length, 2);
      expect(
        messages[0],
        isA<StreamItemMessage>(),
      );
      expect(
        messages[1],
        isA<CompletionMessage>(),
      );
      final message0 = messages[0] as StreamItemMessage;
      final message1 = messages[1] as CompletionMessage;
      final matcher0 = StreamItemMessage('abc', headers: {}, item: 8);
      final matcher1 = CompletionMessage('abc', headers: {}, result: 'OK');
      matchStreamItemMessage(message0, matcher0);
      matchCompletionMessage(message1, matcher1);
    });
  });
  test('# can read ping message', () async {
    await VerifyLogger.runAsync((logger) async {
      final data = '{"type":6}${TextMessageFormat.recordSeparator}';
      final messages = JsonHubProtocol().parseMessages(data, logger);
      expect(messages.length, 1);
      expect(
        messages[0],
        isA<PingMessage>(),
      );
    });
  });
}

void matchInvocationMessage(
    InvocationMessage actual, InvocationMessage matcher) {
  expect(actual.target, matcher.target);
  expect(actual.arguments, matcher.arguments);
  expect(actual.headers, matcher.headers);
  expect(actual.invocationId, matcher.invocationId);
  expect(actual.streamIds, matcher.streamIds);
}

void matchCompletionMessage(
    CompletionMessage actual, CompletionMessage matcher) {
  expect(actual.invocationId, matcher.invocationId);
  expect(actual.headers, matcher.headers);
  expect(actual.error, matcher.error);
  expect(actual.result, matcher.result);
}

void matchStreamItemMessage(
    StreamItemMessage actual, StreamItemMessage matcher) {
  expect(actual.invocationId, matcher.invocationId);
  expect(actual.headers, matcher.headers);
  expect(actual.item, matcher.item);
}
