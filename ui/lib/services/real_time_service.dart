import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';
import 'auth_service.dart';

class RealTimeService {
  static final RealTimeService _instance = RealTimeService._internal();
  factory RealTimeService() => _instance;
  RealTimeService._internal();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _subscribeAckTimer;
  bool _subscribedAck = false;
  int _connectionGeneration = 0;
  List<Uri> _currentUris = const [];
  String? _currentToken;
  String? _currentItineraryId;
  int? _currentDayNumber;
  void Function()? _currentOnUpdate;
  Timer? _reconnectTimer;
  bool _wantsSubscription = false;
  int _failedCycles = 0;
  bool _lastFailureWasUpgrade = false;

  bool get isSubscribed => _subscribedAck;

  String? _sanitizeToken(String? token) {
    final value = token?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    return value.replaceAll('#', '');
  }

  List<Uri> _buildWebSocketUris(String? token) {
    final apiUri = Uri.parse(ApiService.baseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    final basePath = apiUri.path.endsWith('/')
        ? apiUri.path.substring(0, apiUri.path.length - 1)
        : apiUri.path;
    final queryParameters = (token != null && token.isNotEmpty)
        ? {'token': token}
        : null;

    final candidatePaths = <String>[
      '${basePath.isEmpty ? '' : basePath}/ws',
      '/ws',
    ];

    final uris = <Uri>[];
    final seen = <String>{};

    for (final path in candidatePaths) {
      final normalizedPath = path.startsWith('/') ? path : '/$path';
      final uri = apiUri.replace(
        scheme: scheme,
        path: normalizedPath,
        queryParameters: queryParameters,
      );

      if (seen.add(uri.toString())) {
        uris.add(uri);
      }
    }

    return uris;
  }

  void _sendSubscriptionMessages() {
    if (_channel == null ||
        _currentItineraryId == null ||
        _currentDayNumber == null) {
      return;
    }

    final token = _currentToken;
    if (token != null && token.isNotEmpty) {
      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
    }

    _channel!.sink.add(
      jsonEncode({
        'type': 'subscribe',
        'itineraryId': _currentItineraryId,
        'dayNumber': _currentDayNumber,
        if (token != null && token.isNotEmpty) 'token': token,
      }),
    );
  }

  void _connectWithFallback(int uriIndex) {
    if (uriIndex >= _currentUris.length) {
      _subscribedAck = false;
      if (!_wantsSubscription) {
        return;
      }

      _failedCycles++;
      final delay = _lastFailureWasUpgrade
          ? const Duration(seconds: 45)
          : Duration(seconds: _failedCycles >= 5 ? 30 : 5 * _failedCycles);

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () {
        if (!_wantsSubscription) return;
        _connectWithFallback(0);
      });
      return;
    }

    final wsUri = _currentUris[uriIndex];
    final generation = ++_connectionGeneration;
    _subscribedAck = false;

    _subscribeAckTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();

    try {
      if (kDebugMode) {
        print(
          '🔌 WS connect attempt [${uriIndex + 1}/${_currentUris.length}]: $wsUri',
        );
      }

      _channel = WebSocketChannel.connect(wsUri);
      _subscription = _channel!.stream.listen(
        (event) {
          if (generation != _connectionGeneration) return;

          try {
            final payload = jsonDecode(event.toString());
            if (payload is! Map<String, dynamic>) return;

            final type = payload['type'];
            if (kDebugMode) {
              print('📨 WS event: $type payload=$payload');
            }

            if (type == 'subscribed') {
              _subscribedAck = true;
              _failedCycles = 0;
              _lastFailureWasUpgrade = false;
              _reconnectTimer?.cancel();
              _subscribeAckTimer?.cancel();
              return;
            }

            if (type == 'error') {
              _subscribedAck = false;
            }

            if (type == 'itinerary_update' &&
                payload['itineraryId'] == _currentItineraryId &&
                payload['dayNumber'] == _currentDayNumber) {
              if (kDebugMode) {
                print(
                  '🔄 WS update accepted for $_currentItineraryId day $_currentDayNumber',
                );
              }
              _currentOnUpdate?.call();
            }
          } catch (_) {
            // Ignore malformed frames.
          }
        },
        onError: (error) {
          if (generation != _connectionGeneration) return;
          _subscribedAck = false;
          final errorText = error.toString().toLowerCase();
          _lastFailureWasUpgrade =
              errorText.contains('not upgraded to websocket') ||
              errorText.contains('unexpected response code: 404') ||
              errorText.contains(' 404');
          if (kDebugMode) {
            print('❌ WS error on $wsUri: $error');
          }
          _subscribeAckTimer?.cancel();
          _connectWithFallback(uriIndex + 1);
        },
        onDone: () {
          if (generation != _connectionGeneration) return;
          _subscribedAck = false;
          if (kDebugMode) {
            print('🔌 WS closed on $wsUri');
          }
          _subscribeAckTimer?.cancel();
          _connectWithFallback(uriIndex + 1);
        },
      );

      unawaited(
        _channel!.ready
            .then((_) {
              if (generation != _connectionGeneration) return;
              _sendSubscriptionMessages();
            })
            .catchError((error) {
              if (generation != _connectionGeneration) return;
              _subscribedAck = false;
              final errorText = error.toString().toLowerCase();
              _lastFailureWasUpgrade =
                  errorText.contains('not upgraded to websocket') ||
                  errorText.contains('unexpected response code: 404') ||
                  errorText.contains(' 404');
              if (kDebugMode) {
                print('❌ WS ready failed on $wsUri: $error');
              }
              _subscribeAckTimer?.cancel();
              _connectWithFallback(uriIndex + 1);
            }),
      );

      _subscribeAckTimer = Timer(const Duration(seconds: 4), () {
        if (generation != _connectionGeneration) return;
        if (_subscribedAck) return;

        if (kDebugMode) {
          print('⏱️ WS no subscribed ack from $wsUri, trying fallback URL');
        }

        _connectWithFallback(uriIndex + 1);
      });
    } catch (error) {
      if (generation != _connectionGeneration) return;
      if (kDebugMode) {
        print('❌ WS sync connect failed for $wsUri: $error');
      }
      _connectWithFallback(uriIndex + 1);
    }
  }

  StreamSubscription<dynamic> subscribeToItinerary(
    String itineraryId,
    int dayNumber,
    void Function() onUpdate,
  ) {
    _wantsSubscription = true;
    _currentToken = _sanitizeToken(AuthService().token);
    _currentItineraryId = itineraryId;
    _currentDayNumber = dayNumber;
    _currentOnUpdate = onUpdate;
    _currentUris = _buildWebSocketUris(_currentToken);

    if (kDebugMode) {
      print('🔄 WS subscribe requested itinerary=$itineraryId day=$dayNumber');
    }

    _connectWithFallback(0);

    _subscription ??= const Stream<dynamic>.empty().listen((_) {});
    return _subscription!;
  }

  void dispose() {
    _wantsSubscription = false;
    _failedCycles = 0;
    _lastFailureWasUpgrade = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscribeAckTimer?.cancel();
    _subscribeAckTimer = null;
    _subscribedAck = false;
    _currentOnUpdate = null;
    _currentItineraryId = null;
    _currentDayNumber = null;
    _currentUris = const [];
    _currentToken = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}
