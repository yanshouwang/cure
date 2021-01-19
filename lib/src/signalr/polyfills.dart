import 'package:cure/sse.dart';
import 'package:cure/ws.dart';

typedef WebSocketConstructor = WebSocket Function(
    String url, List<String>? protocols, Map<String, String>? headers);

typedef EventSourceConstructor = EventSource Function(
    String url, Map<String, String>? headers, bool? withCredentials);
