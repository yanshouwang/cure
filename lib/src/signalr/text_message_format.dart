abstract class TextMessageFormat {
  static const recordSeparatorCode = 0x1e;
  static final recordSeparator = String.fromCharCode(recordSeparatorCode);

  static String write(String output) {
    return '$output$recordSeparator';
  }

  static List<String> parse(String input) {
    if (input.isEmpty || input[input.length - 1] != recordSeparator) {
      throw Exception('Message is incomplete.');
    }

    final messages = input.split(recordSeparator);
    messages.removeLast();
    return messages;
  }
}
