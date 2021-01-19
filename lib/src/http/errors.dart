class ClientException implements Exception {
  final String message;
  final Uri? uri;

  ClientException(this.message, [this.uri]);

  @override
  String toString() {
    final report = 'ClientException';
    if (uri == null) {
      return '$report: $message';
    } else {
      return '$report: $message\nuri: $uri';
    }
  }
}
