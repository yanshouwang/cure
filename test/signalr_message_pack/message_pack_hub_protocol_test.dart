import 'dart:typed_data';

import 'package:cure/core.dart';
import 'package:cure/signalr.dart';
import 'package:cure/signalr_message_pack.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

void main() {
  test('# can write/read non-blocking Invocation message', () {
    final invocation = InvocationMessage(
      'myMethod',
      [
        42,
        true,
        'test',
        ['x1', 'y2'],
        null
      ],
      headers: {},
      streamIds: [],
    );

    final protocol = MessagePackHubProtocol();
    final input = protocol.writeMessage(invocation);
    final messages = protocol.parseMessages(input, NullLogger());
    expect(messages.length, 1);
    expect(
      messages[0],
      isA<InvocationMessage>(),
    );
    final message = messages[0] as InvocationMessage;
    matchInvocationMessage(message, invocation);
  });
  test('# can read Invocation message with Date argument', () {
    final invocation = InvocationMessage(
      'mymethod',
      [Timestamp.utc(2018, 1, 1, 12, 34, 56)],
      headers: {},
      streamIds: [],
    );

    final protocol = MessagePackHubProtocol();
    final input = protocol.writeMessage(invocation);
    final messages = protocol.parseMessages(input, NullLogger());
    expect(messages.length, 1);
    expect(
      messages[0],
      isA<InvocationMessage>(),
    );
    final message = messages[0] as InvocationMessage;
    matchInvocationMessage(message, invocation);
  });
  test('# can write/read Invocation message with headers', () {
    final invocation = InvocationMessage(
      'myMethod',
      [
        42,
        true,
        'test',
        ['x1', 'y2'],
        null,
      ],
      headers: {'foo': 'bar'},
      streamIds: [],
    );

    final protocol = MessagePackHubProtocol();
    final input = protocol.writeMessage(invocation);
    final messages = protocol.parseMessages(input, NullLogger());
    expect(messages.length, 1);
    expect(
      messages[0],
      isA<InvocationMessage>(),
    );
    final message = messages[0] as InvocationMessage;
    matchInvocationMessage(message, invocation);
  });
  test('# can write/read Invocation message', () {
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
      invocationId: '123',
      streamIds: [],
    );

    final protocol = MessagePackHubProtocol();
    final input = protocol.writeMessage(invocation);
    final messages = protocol.parseMessages(input, NullLogger());
    expect(messages.length, 1);
    expect(
      messages[0],
      isA<InvocationMessage>(),
    );
    final message = messages[0] as InvocationMessage;
    matchInvocationMessage(message, invocation);
  });

  [
    Tuple2(
      [
        0x0c,
        0x95,
        0x03,
        0x80,
        0xa3,
        0x61,
        0x62,
        0x63,
        0x01,
        0xa3,
        0x45,
        0x72,
        0x72,
      ],
      CompletionMessage('abc', error: 'Err', headers: {}),
    ),
    Tuple2(
      [
        0x0b,
        0x95,
        0x03,
        0x80,
        0xa3,
        0x61,
        0x62,
        0x63,
        0x03,
        0xa2,
        0x4f,
        0x4b,
      ],
      CompletionMessage('abc', headers: {}, result: 'OK'),
    ),
    Tuple2(
      [0x08, 0x94, 0x03, 0x80, 0xa3, 0x61, 0x62, 0x63, 0x02],
      CompletionMessage('abc', headers: {}),
    ),
    Tuple2(
      [
        0x0E,
        0x95,
        0x03,
        0x80,
        0xa3,
        0x61,
        0x62,
        0x63,
        0x03,
        0xD6,
        0xFF,
        0x5A,
        0x4A,
        0x1A,
        0x50,
      ],
      CompletionMessage(
        'abc',
        headers: {},
        result: Timestamp.utc(2018, 1, 1, 11, 24, 0),
      ),
    ),
    // extra property at the end should be ignored (testing older protocol client working with newer protocol server)
    Tuple2(
      [0x09, 0x95, 0x03, 0x80, 0xa3, 0x61, 0x62, 0x63, 0x02, 0x00],
      CompletionMessage('abc', headers: {}),
    ),
  ].forEach((element) => test('# can read Completion message', () {
        final data = Uint8List.fromList(element.item1);
        final protocol = MessagePackHubProtocol();
        final messages = protocol.parseMessages(data, NullLogger());
        expect(messages.length, 1);
        expect(
          messages[0],
          isA<CompletionMessage>(),
        );
        final message = messages[0] as CompletionMessage;
        matchCompletionMessage(message, element.item2);
      }));

  [
    Tuple2(
      [0x08, 0x94, 0x02, 0x80, 0xa3, 0x61, 0x62, 0x63, 0x08],
      StreamItemMessage(
        'abc',
        headers: {},
        item: 8,
      ),
    ),
    Tuple2(
      [
        0x0D,
        0x94,
        0x02,
        0x80,
        0xa3,
        0x61,
        0x62,
        0x63,
        0xD6,
        0xFF,
        0x5A,
        0x4A,
        0x1A,
        0x50,
      ],
      StreamItemMessage(
        'abc',
        headers: {},
        item: Timestamp.utc(2018, 1, 1, 11, 24, 0),
      ),
    ),
  ].forEach((element) => test('# can read StreamItem message', () {
        final data = Uint8List.fromList(element.item1);
        final protocol = MessagePackHubProtocol();
        final messages = protocol.parseMessages(data, NullLogger());
        expect(messages.length, 1);
        expect(
          messages[0],
          isA<StreamItemMessage>(),
        );
        final message = messages[0] as StreamItemMessage;
        matchStreamItemMessage(message, element.item2);
      }));

  [
    Tuple2(
      [
        0x0c,
        0x94,
        0x02,
        0x81,
        0xa1,
        0x74,
        0xa1,
        0x75,
        0xa3,
        0x61,
        0x62,
        0x63,
        0x08,
      ],
      StreamItemMessage(
        'abc',
        headers: {'t': 'u'},
        item: 8,
      ),
    ),
  ].forEach((element) => test('# can read message with headers', () {
        final data = Uint8List.fromList(element.item1);
        final protocol = MessagePackHubProtocol();
        final messages = protocol.parseMessages(data, NullLogger());
        expect(messages.length, 1);
        expect(
          messages[0],
          isA<StreamItemMessage>(),
        );
        final message = messages[0] as StreamItemMessage;
        matchStreamItemMessage(message, element.item2);
      }));

  [
    Tuple3(
      'message with no payload',
      [0x00],
      'Invalid payload.',
    ),
    Tuple3(
      'message with empty array',
      [0x01, 0x90],
      'Invalid payload.',
    ),
    Tuple3(
      'message without outer array',
      [0x01, 0xc2],
      'Invalid payload.',
    ),
    Tuple3(
      'message with invalid headers',
      [0x03, 0x92, 0x01, 0x05],
      'Invalid headers.',
    ),
    Tuple3(
      'Invocation message with invalid invocation id',
      [0x03, 0x92, 0x01, 0x80],
      'Invalid payload for Invocation message.',
    ),
    Tuple3(
      'StreamItem message with invalid invocation id',
      [0x03, 0x92, 0x02, 0x80],
      'Invalid payload for StreamItem message.',
    ),
    Tuple3(
      'Completion message with invalid invocation id',
      [0x04, 0x93, 0x03, 0x80, 0xa0],
      'Invalid payload for Completion message.',
    ),
    Tuple3(
      'Completion message with missing result',
      [0x05, 0x94, 0x03, 0x80, 0xa0, 0x01],
      'Invalid payload for Completion message.',
    ),
    Tuple3(
      'Completion message with missing error',
      [0x05, 0x94, 0x03, 0x80, 0xa0, 0x03],
      'Invalid payload for Completion message.',
    ),
  ].forEach((element) => test('# throws for ${element.item1}', () {
        final data = Uint8List.fromList(element.item2);
        final protocol = MessagePackHubProtocol();
        final m = predicate((e) => '$e' == 'Exception: ${element.item3}');
        final matcher = throwsA(m);
        expect(() => protocol.parseMessages(data, NullLogger()), matcher);
      }));

  test('# can read multiple messages', () {
    final data = Uint8List.fromList([
      0x08,
      0x94,
      0x02,
      0x80,
      0xa3,
      0x61,
      0x62,
      0x63,
      0x08,
      0x0b,
      0x95,
      0x03,
      0x80,
      0xa3,
      0x61,
      0x62,
      0x63,
      0x03,
      0xa2,
      0x4f,
      0x4b,
    ]);
    final protocol = MessagePackHubProtocol();
    final messages = protocol.parseMessages(data, NullLogger());
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
    final matcher0 = StreamItemMessage(
      'abc',
      headers: {},
      item: 8,
    );
    final matcher1 = CompletionMessage(
      'abc',
      headers: {},
      result: 'OK',
    );
    matchStreamItemMessage(message0, matcher0);
    matchCompletionMessage(message1, matcher1);
  });
  test('# can read ping message', () {
    final data = Uint8List.fromList([
      0x02,
      0x91, // message array length = 1 (fixarray)
      0x06, // type = 6 = Ping (fixnum)
    ]);
    final protocol = MessagePackHubProtocol();
    final messages = protocol.parseMessages(data, NullLogger());
    expect(messages.length, 1);
    expect(
      messages[0],
      isA<PingMessage>(),
    );
  });
  test('# can write ping message', () {
    final message = PingMessage();
    final protocol = MessagePackHubProtocol();
    final actual = protocol.writeMessage(message);
    final matcher = Uint8List.fromList([
      0x02, // length prefix
      0x91, // message array length = 1 (fixarray)
      0x06, // type = 6 = Ping (fixnum)
    ]);
    expect(actual, matcher);
  });
  test('# can write cancel message', () {
    final message = CancelInvocationMessage('abc');
    final protocol = MessagePackHubProtocol();
    final actual = protocol.writeMessage(message);
    final matcher = Uint8List.fromList([
      0x07, // length prefix
      0x93, // message array length = 1 (fixarray)
      0x05, // type = 5 = CancelInvocation (fixnum)
      0x80, // headers
      0xa3, // invocationID = string length 3
      0x61, // a
      0x62, // b
      0x63, // c
    ]);
    expect(actual, matcher);
  });
  test('# will preserve double precision', () {
    final invocation = InvocationMessage(
      'myMethod',
      [0.005],
      headers: {},
      invocationId: '123',
      streamIds: [],
    );

    final protocol = MessagePackHubProtocol();
    final input = protocol.writeMessage(invocation);
    final messages = protocol.parseMessages(input, NullLogger());
    expect(messages.length, 1);
    expect(
      messages[0],
      isA<InvocationMessage>(),
    );
    final message = messages[0] as InvocationMessage;
    matchInvocationMessage(message, invocation);
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
