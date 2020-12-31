import 'package:cure/signalr.dart';
import 'package:test/test.dart';

void main() {
  final items = [
    MapEntry(UserAgent('1.0.4-build.10', 'Linux', 'NodeJS', '10'),
        'Microsoft SignalR/1.0 (1.0.4-build.10; Linux; NodeJS; 10)'),
    MapEntry(UserAgent('1.4.7-build.10', '', 'Browser', ''),
        'Microsoft SignalR/1.4 (1.4.7-build.10; Unknown OS; Browser; Unknown Runtime Version)'),
    MapEntry(UserAgent('3.1.1-build.10', 'macOS', 'Browser', ''),
        'Microsoft SignalR/3.1 (3.1.1-build.10; macOS; Browser; Unknown Runtime Version)'),
    MapEntry(UserAgent('3.1.3-build.10', '', 'Browser', '4'),
        'Microsoft SignalR/3.1 (3.1.3-build.10; Unknown OS; Browser; 4)')
  ];
  for (var item in items) {
    test('# Is in correct format', () {
      final from = item.key;
      final userAgent = constructUserAgent(
          from.version, from.os, from.runtime, from.runtimeVersion);
      expect(userAgent, item.value);
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
