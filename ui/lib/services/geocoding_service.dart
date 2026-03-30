import 'package:flutter/foundation.dart';
import 'api_service.dart';

class GeocodingService {
  final ApiService _api = ApiService();

  GeocodingService();

  /// Geocode an address via backend. Expected response: { "lat": number, "lng": number }
  Future<Map<String, double>?> geocodeAddress(String address) async {
    try {
      if (kDebugMode) {
        print('🛰️ Geocoding address: $address');
      }
      final response = await _api.get(
        '/maps/geocode',
        queryParams: {'address': address},
      );
      if (response == null) return null;
      final latRaw = response['lat'];
      final lngRaw = response['lng'];
      if (latRaw == null || lngRaw == null) return null;
      final lat = (latRaw as num).toDouble();
      final lng = (lngRaw as num).toDouble();
      return {'lat': lat, 'lng': lng};
    } catch (e) {
      if (kDebugMode) {
        print('Geocoding error: $e');
      }
      return null;
    }
  }
}
