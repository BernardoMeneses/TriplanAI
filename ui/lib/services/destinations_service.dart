import 'api_service.dart';

class Destination {
  final String placeId;
  final String name;
  final String subtitle;
  final String description;
  final List<String> types;
  final String? city;
  final String? country;

  Destination({
    required this.placeId,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.types,
    this.city,
    this.country,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      placeId: json['placeId'] ?? '',
      name: json['name'] ?? '',
      subtitle: json['subtitle'] ?? '',
      description: json['description'] ?? '',
      types: List<String>.from(json['types'] ?? []),
      city: json['city'],
      country: json['country'],
    );
  }
}

class DestinationDetails {
  final String placeId;
  final String name;
  final String subtitle;
  final String formattedAddress;
  final double lat;
  final double lng;
  final String? photoUrl;
  final List<String> types;

  DestinationDetails({
    required this.placeId,
    required this.name,
    required this.subtitle,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.photoUrl,
    required this.types,
  });

  factory DestinationDetails.fromJson(Map<String, dynamic> json) {
    final location = json['location'] ?? {};
    return DestinationDetails(
      placeId: json['placeId'] ?? '',
      name: json['name'] ?? '',
      subtitle: json['subtitle'] ?? '',
      formattedAddress: json['formattedAddress'] ?? '',
      lat: (location['lat'] ?? 0).toDouble(),
      lng: (location['lng'] ?? 0).toDouble(),
      photoUrl: json['photoUrl'],
      types: List<String>.from(json['types'] ?? []),
    );
  }
}

class DestinationsService {
  final ApiService _api = ApiService();

  /// Pesquisa destinos (cidades, países, regiões) pelo nome
  Future<List<Destination>> searchDestinations(
    String query, {
    String? sessionToken,
    double? lat,
    double? lng,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final params = {'query': query};
      if (sessionToken != null) params['sessionToken'] = sessionToken;
      if (lat != null && lng != null) {
        params['lat'] = lat.toString();
        params['lng'] = lng.toString();
      }

      final response = await _api.get(
        '/maps/destinations/search',
        queryParams: params,
      );

      if (response is List) {
        return response.map((json) => Destination.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao pesquisar destinos: $e');
      return [];
    }
  }

  /// Obtém detalhes de um destino incluindo foto
  Future<DestinationDetails?> getDestinationDetails(String placeId) async {
    try {
      final response = await _api.get('/maps/destinations/$placeId');

      if (response != null) {
        return DestinationDetails.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Erro ao obter detalhes do destino: $e');
      return null;
    }
  }
}
