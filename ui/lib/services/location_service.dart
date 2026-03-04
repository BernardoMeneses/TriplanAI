import 'package:geolocator/geolocator.dart';

class LocationService {
  static Position? _cachedPosition;
  static DateTime? _lastUpdate;
  static const Duration _cacheExpiry = Duration(seconds: 30);

  /// Obtém a posição atual do utilizador
  static Future<Position?> getCurrentPosition() async {
    // Verificar se temos uma posição em cache recente
    if (_cachedPosition != null && _lastUpdate != null) {
      if (DateTime.now().difference(_lastUpdate!) < _cacheExpiry) {
        return _cachedPosition;
      }
    }

    // Verificar se os serviços de localização estão habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    // Verificar permissões
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _cachedPosition = position;
      _lastUpdate = DateTime.now();

      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Obtém a última posição conhecida (mais rápido, sem precisão)
  static Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }

  /// Calcula a distância em metros entre dois pontos
  static double calculateDistance(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Limpa o cache
  static void clearCache() {
    _cachedPosition = null;
    _lastUpdate = null;
  }
}
