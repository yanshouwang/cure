import 'dart:convert';

final json = JsonCodec(toEncodable: (object) => object.toJSON());
