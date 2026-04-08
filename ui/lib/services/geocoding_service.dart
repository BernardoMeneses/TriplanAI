import 'package:flutter/foundation.dart';
import 'api_service.dart';

class GeocodingService {
  final ApiService _api = ApiService();

  GeocodingService();

  /// Geocode an address via backend. Returns the full backend response when possible.
  /// Expected backend shape: { lat, lng, formattedAddress, placeId, components: { city, country, ... } }
  Future<Map<String, dynamic>?> geocodeAddress(String address) async {
    try {
      if (kDebugMode) {
        print('🛰️ Geocoding address: $address');
      }
      final response = await _api.get(
        '/maps/geocode',
        queryParams: {'address': address},
      );
      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Geocoding error: $e');
      }
      return null;
    }
  }
}
