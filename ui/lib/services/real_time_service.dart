import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';
import 'auth_service.dart';

class RealTimeService {
  static final RealTimeService _instance = RealTimeService._internal();
  factory RealTimeService() => _instance;
  RealTimeService._internal();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Uri _buildWebSocketUri(String? token) {
    final apiUri = Uri.parse(ApiService.baseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';

    return Uri(
      scheme: scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
      path: '/ws',
      queryParameters: (token != null && token.isNotEmpty)
          ? {'token': token}
          : null,
    );
  }

  StreamSubscription<dynamic> subscribeToItinerary(
    String itineraryId,
    int dayNumber,
    void Function() onUpdate,
  ) {
    _subscription?.cancel();
    _channel?.sink.close();

    final token = AuthService().token;
    final wsUri = _buildWebSocketUri(token);

    _channel = WebSocketChannel.connect(wsUri);
    _subscription = _channel!.stream.listen((event) {
      try {
        final payload = jsonDecode(event as String);
        if (payload is! Map<String, dynamic>) return;

        final type = payload['type'];
        if (type == 'itinerary_update' &&
            payload['itineraryId'] == itineraryId &&
            payload['dayNumber'] == dayNumber) {
          onUpdate();
        }
      } catch (_) {
        // Ignore malformed frames.
      }
    });

    if (token != null && token.isNotEmpty) {
      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
    }

    _channel!.sink.add(
      jsonEncode({
        'type': 'subscribe',
        'itineraryId': itineraryId,
        'dayNumber': dayNumber,
        if (token != null && token.isNotEmpty) 'token': token,
      }),
    );

    return _subscription!;
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
  }
}
