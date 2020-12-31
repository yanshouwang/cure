import 'dart:convert';

/// JavaScript Object Notation, JSON
abstract class JSON {
  /// Deserialize the [source] to a [JSON] object.
  static dynamic fromJSON(String source) {
    return json.decode(source);
  }

  /// Serialize the [obj] to a [JSON] string.
  static String toJSON(dynamic obj) {
    return json.encode(obj, toEncodable: (obj) => obj.toJSON());
  }
}
