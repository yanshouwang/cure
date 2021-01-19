import 'hash_codes.dart';

const THOUSAND = 1000;
const MILLION = 1000000;
const BILLION = 1000000000;

/// A Timestamp represents a point in time independent of any time zone or calendar,
/// represented as seconds and fractions of seconds at nanosecond resolution in UTC
/// Epoch time. It is encoded using the Proleptic Gregorian Calendar which extends
/// the Gregorian calendar backwards to year one. It is encoded assuming all minutes
/// are 60 seconds long, i.e. leap seconds are "smeared" so that no leap second table
/// is needed for interpretation. Range is from 0001-01-01T00:00:00Z to
/// 9999-12-31T23:59:59.999999999Z. By restricting to that range, we ensure that we
/// can convert to and from RFC 3339 date strings.
///
/// For more information, see [the reference timestamp definition](https://github.com/google/protobuf/blob/master/src/google/protobuf/timestamp.proto)
class Timestamp implements Comparable<Timestamp> {
  final int seconds;
  final int nanoseconds;

  /// Converts [Timestamp] to [DateTime]
  DateTime get date {
    final microsecondsSinceEpoch = seconds * MILLION + nanoseconds ~/ THOUSAND;
    return DateTime.fromMicrosecondsSinceEpoch(microsecondsSinceEpoch);
  }

  int get millisecondsSinceEpoch => date.millisecondsSinceEpoch;
  int get microsecondsSinceEpoch => date.microsecondsSinceEpoch;

  /// Creates a [Timestamp]
  Timestamp(this.seconds, this.nanoseconds) {
    _check(nanoseconds.abs() < BILLION, nanoseconds, 'nanoseconds');
  }

  void _check(bool expr, int value, String name) {
    if (!expr) {
      throw ArgumentError.value(value, name);
    }
  }

  /// Create a [Timestamp] fromMillisecondsSinceEpoch
  factory Timestamp.fromMillisecondsSinceEpoch(int millisecondsSinceEpoch) {
    final seconds = (millisecondsSinceEpoch ~/ THOUSAND);
    final nanoseconds = (millisecondsSinceEpoch - seconds * THOUSAND) * MILLION;
    return Timestamp(seconds, nanoseconds);
  }

  /// Create a [Timestamp] fromMicrosecondsSinceEpoch
  factory Timestamp.fromMicrosecondsSinceEpoch(int microsecondsSinceEpoch) {
    final seconds = (microsecondsSinceEpoch ~/ MILLION);
    final nanoseconds = (microsecondsSinceEpoch - seconds * MILLION) * THOUSAND;
    return Timestamp(seconds, nanoseconds);
  }

  /// Create a [Timestamp] from [DateTime.now]
  factory Timestamp.now() => DateTime.now().timestamp;

  /// Create a [Timestamp] from [DateTime.utc]
  factory Timestamp.utc(
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ]) =>
      DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
        millisecond,
        microsecond,
      ).timestamp;

  /// Create a [Timestamp] from [DateTime.parse]
  static Timestamp parse(String formattedString) =>
      DateTime.parse(formattedString).timestamp;

  /// Create a [Timestamp] from [DateTime.tryParse]
  static Timestamp? tryParse(String formattedString) =>
      DateTime.tryParse(formattedString)?.timestamp;

  @override
  int compareTo(Timestamp other) {
    if (seconds == other.seconds) {
      return nanoseconds.compareTo(other.nanoseconds);
    }
    return seconds.compareTo(other.seconds);
  }

  @override
  bool operator ==(Object o) =>
      o is Timestamp && o.seconds == seconds && o.nanoseconds == nanoseconds;

  @override
  int get hashCode => hashValues(seconds, nanoseconds);

  @override
  String toString() => 'Timestamp($seconds, $nanoseconds)';
}

extension on DateTime {
  Timestamp get timestamp =>
      Timestamp.fromMicrosecondsSinceEpoch(microsecondsSinceEpoch);
}
