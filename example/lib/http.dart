import 'package:cure/http.dart';

void main() async {
  var client = Client();
  try {
    final response = await client.getAsync('url');
    print('${response.statusCode}: ${response.content}');
  } catch (e) {
    print(e);
  } finally {
    client.close();
  }
}
