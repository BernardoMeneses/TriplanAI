import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Serviço para verificar conectividade com a internet
class ConnectivityService {
  // Singleton
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  final _connectivityController = StreamController<bool>.broadcast();
  Timer? _periodicCheck;
  bool _isChecking = false;

  Stream<bool> get connectivityStream => _connectivityController.stream;
  bool get isOnline => _isOnline;

  /// Inicia verificação periódica de conectividade (a cada 5 segundos)
  void startPeriodicCheck({Duration interval = const Duration(seconds: 1)}) {
    _periodicCheck?.cancel();
    _periodicCheck = Timer.periodic(interval, (_) => checkConnectivity());
    // Verificar imediatamente
    checkConnectivity();
  }

  /// Para a verificação periódica
  void stopPeriodicCheck() {
    _periodicCheck?.cancel();
    _periodicCheck = null;
  }

  /// Verifica se há conectividade fazendo um lookup DNS
  Future<bool> checkConnectivity() async {
    // Evitar verificações simultâneas
    if (_isChecking) return _isOnline;
    _isChecking = true;
    
    final wasOnline = _isOnline;
    
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      _isOnline = false;
    } on TimeoutException catch (_) {
      _isOnline = false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ConnectivityService: Erro ao verificar conectividade: $e');
      }
      _isOnline = false;
    }
    
    _isChecking = false;

    // Só notifica se o estado mudou
    if (wasOnline != _isOnline) {
      _connectivityController.add(_isOnline);
      if (kDebugMode) {
        print(_isOnline ? '🌐 Voltou Online!' : '📴 Ficou Offline');
      }
    }
    
    return _isOnline;
  }

  void dispose() {
    _periodicCheck?.cancel();
    _connectivityController.close();
  }
}
