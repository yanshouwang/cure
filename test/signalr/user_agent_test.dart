import 'package:cure/signalr.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

void main() {
  final elements = [
    Tuple2(
      UserAgent('1.0.4-build.10', 'Linux', 'NodeJS', '10'),
      'Microsoft SignalR/1.0 (1.0.4-build.10; Linux; NodeJS; 10)',
    ),
    Tuple2(
      UserAgent('1.4.7-build.10', '', 'Browser', ''),
      'Microsoft SignalR/1.4 (1.4.7-build.10; Unknown OS; Browser; Unknown Runtime Version)',
    ),
    Tuple2(
      UserAgent('3.1.1-build.10', 'macOS', 'Browser', ''),
      'Microsoft SignalR/3.1 (3.1.1-build.10; macOS; Browser; Unknown Runtime Version)',
    ),
    Tuple2(
      UserAgent('3.1.3-build.10', '', 'Browser', '4'),
      'Microsoft SignalR/3.1 (3.1.3-build.10; Unknown OS; Browser; 4)',
    )
  ];
  for (var element in elements) {
    test('# is in correct format', () {
      final from = element.item1;
      final userAgent = constructUserAgent(
          from.version, from.os, from.runtime, from.runtimeVersion);
      expect(userAgent, element.item2);
    });
  }
}

class UserAgent {
  final String version;
  final String os;
  final String runtime;
  final String runtimeVersion;

  UserAgent(this.version, this.os, this.runtime, this.runtimeVersion);
}
