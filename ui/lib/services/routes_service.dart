import 'api_service.dart';

class Waypoint {
  final String? placeId;
  final String? name;
  final double latitude;
  final double longitude;

  Waypoint({
    this.placeId,
    this.name,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    if (placeId != null) 'placeId': placeId,
    if (name != null) 'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class TravelInfo {
  final int durationMinutes;
  final String durationText;
  final int distanceMeters;
  final String distanceText;
  final String travelMode;

  TravelInfo({
    required this.durationMinutes,
    required this.durationText,
    required this.distanceMeters,
    required this.distanceText,
    required this.travelMode,
  });

  factory TravelInfo.fromJson(Map<String, dynamic> json) {
    return TravelInfo(
      durationMinutes: ((json['duration'] ?? 0) / 60).round(),
      durationText: json['durationText'] ?? '',
      distanceMeters: json['distance'] ?? 0,
      distanceText: json['distanceText'] ?? '',
      travelMode: json['travelMode'] ?? 'driving',
    );
  }
}

class RouteInfo {
  final String id;
  final Waypoint origin;
  final Waypoint destination;
  final int distance;
  final int duration;
  final String distanceText;
  final String durationText;
  final String polyline;
  final String travelMode;

  RouteInfo({
    required this.id,
    required this.origin,
    required this.destination,
    required this.distance,
    required this.duration,
    required this.distanceText,
    required this.durationText,
    required this.polyline,
    required this.travelMode,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      id: json['id'] ?? '',
      origin: Waypoint(
        latitude: json['origin']['latitude'] ?? 0.0,
        longitude: json['origin']['longitude'] ?? 0.0,
      ),
      destination: Waypoint(
        latitude: json['destination']['latitude'] ?? 0.0,
        longitude: json['destination']['longitude'] ?? 0.0,
      ),
      distance: json['distance'] ?? 0,
      duration: json['duration'] ?? 0,
      distanceText: json['distanceText'] ?? '',
      durationText: json['durationText'] ?? '',
      polyline: json['polyline'] ?? '',
      travelMode: json['travelMode'] ?? 'driving',
    );
  }
}

class DistanceMatrixResult {
  final int distance;
  final String distanceText;
  final int duration;
  final String durationText;
  final String status;

  DistanceMatrixResult({
    required this.distance,
    required this.distanceText,
    required this.duration,
    required this.durationText,
    required this.status,
  });

  factory DistanceMatrixResult.fromJson(Map<String, dynamic> json) {
    return DistanceMatrixResult(
      distance: json['distance'] ?? 0,
      distanceText: json['distanceText'] ?? '',
      duration: json['duration'] ?? 0,
      durationText: json['durationText'] ?? '',
      status: json['status'] ?? 'OK',
    );
  }

  int get durationMinutes => (duration / 60).round();
}

class RoutesService {
  final ApiService _apiService = ApiService();

  /// Calcula a rota entre dois pontos
  Future<RouteInfo?> calculateRoute({
    required Waypoint origin,
    required Waypoint destination,
    String travelMode = 'driving',
  }) async {
    try {
      final response = await _apiService.post('/routes/calculate', body: {
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'travelMode': travelMode,
      });
      return RouteInfo.fromJson(response);
    } catch (e) {
      print('Error calculating route: $e');
      return null;
    }
  }

  /// Obtém a matriz de distâncias entre múltiplas origens e destinos
  Future<List<DistanceMatrixResult>> getDistanceMatrix({
    required List<Waypoint> origins,
    required List<Waypoint> destinations,
    String travelMode = 'driving',
  }) async {
    try {
      final response = await _apiService.post('/routes/distance-matrix', body: {
        'origins': origins.map((w) => w.toJson()).toList(),
        'destinations': destinations.map((w) => w.toJson()).toList(),
        'travelMode': travelMode,
      });

      if (response is List) {
        return response.map((json) => DistanceMatrixResult.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting distance matrix: $e');
      return [];
    }
  }

  /// Obtém o tempo de viagem de uma origem para um destino
  Future<TravelInfo?> getTravelTime({
    required Waypoint origin,
    required Waypoint destination,
    String travelMode = 'driving',
  }) async {
    try {
      final route = await calculateRoute(
        origin: origin,
        destination: destination,
        travelMode: travelMode,
      );

      if (route != null) {
        return TravelInfo(
          durationMinutes: (route.duration / 60).round(),
          durationText: route.durationText,
          distanceMeters: route.distance,
          distanceText: route.distanceText,
          travelMode: route.travelMode,
        );
      }
      return null;
    } catch (e) {
      print('Error getting travel time: $e');
      return null;
    }
  }

  /// Encontra o melhor modo de transporte (o mais rápido)
  Future<TravelInfo?> getBestTravelMode({
    required Waypoint origin,
    required Waypoint destination,
  }) async {
    final modes = ['walking', 'driving', 'transit'];
    TravelInfo? bestOption;

    for (final mode in modes) {
      try {
        final info = await getTravelTime(
          origin: origin,
          destination: destination,
          travelMode: mode,
        );

        if (info != null) {
          if (bestOption == null || info.durationMinutes < bestOption.durationMinutes) {
            bestOption = TravelInfo(
              durationMinutes: info.durationMinutes,
              durationText: info.durationText,
              distanceMeters: info.distanceMeters,
              distanceText: info.distanceText,
              travelMode: mode,
            );
          }
        }
      } catch (e) {
        // Continuar com o próximo modo
      }
    }

    return bestOption;
  }
}
