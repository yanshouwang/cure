final lws = RegExp(r'(?:\r\n)?[ \t]+');
final whitespace = RegExp('(?:${lws.pattern})*');
final token = RegExp(r'[^()<>@,;:"\\/[\]?={} \t\x00-\x1F\x7F]+');
