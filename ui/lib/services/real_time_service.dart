import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Serviço simples para integração WebSocket (exemplo)
class RealTimeService {
  static final RealTimeService _instance = RealTimeService._internal();
  factory RealTimeService() => _instance;
  RealTimeService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  /// Conecta ao WebSocket e escuta eventos de atualização de um itinerário
  StreamSubscription subscribeToItinerary(String tripId, int dayNumber, void Function() onUpdate) {
    // Substitua pela URL real do seu backend WebSocket
    final url = 'wss://seu-backend.com/ws/itinerary/$tripId/$dayNumber';
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _subscription = _channel!.stream.listen((event) {
      // Aqui pode-se filtrar eventos, validar payload, etc
      onUpdate();
    });
    return _subscription!;
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
  }
}
