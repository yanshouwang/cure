/// MapExtension
extension MapExtension on Map<String, Object> {
  /// Write [key] with [value] to [Map] when the [value] is not null.
  void writeNotNull(String key, Object value) {
    if (key != null && value != null) {
      this[key] = value;
    }
  }

  /// Verify the [key]'s value is same as [value].
  void verify(String key, Object value) {
    if (!containsKey(key) || this[key] != value) {
      throw ArgumentError.value(this[key], key);
    }
  }
}
