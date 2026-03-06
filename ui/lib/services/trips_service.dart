import 'api_service.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';

class TripsService {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  // Criar nova viagem
  Future<Trip> createTrip({
    required String title,
    required String destinationCity,
    required String destinationCountry,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    double? budget,
    String currency = 'EUR',
    String? tripType,
    int numberOfTravelers = 1,
  }) async {
    final body = {
      'title': title,
      'destination_city': destinationCity,
      'destination_country': destinationCountry,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      if (description != null) 'description': description,
      if (budget != null) 'budget': budget,
      'currency': currency,
      'status': 'planning',
      if (tripType != null) 'trip_type': tripType,
      'number_of_travelers': numberOfTravelers,
    };

    final response = await _apiService.post('/trips', body: body);
    final trip = Trip.fromJson(response);
    
    // Agendar notificações para a viagem
    try {
      await _notificationService.scheduleTripNotifications(
        tripId: trip.id,
        destination: destinationCity,
        startDate: startDate,
      );
      if (kDebugMode) {
        print('✅ Notificações agendadas para viagem: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Erro ao agendar notificações: $e');
      }
    }
    
    return trip;
  }

  // Listar viagens do usuário
  Future<List<Trip>> getTrips() async {
    final response = await _apiService.get('/trips');
    return (response as List).map((json) => Trip.fromJson(json)).toList();
  }

  // Obter detalhes de uma viagem
  Future<Trip> getTripById(String tripId) async {
    final response = await _apiService.get('/trips/$tripId');
    return Trip.fromJson(response);
  }

  // Atualizar viagem
  Future<Trip> updateTrip({
    required String tripId,
    String? title,
    String? destinationCity,
    String? destinationCountry,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    double? budget,
    String? currency,
    String? status,
    String? tripType,
    int? numberOfTravelers,
  }) async {
    final body = <String, dynamic>{};

    if (title != null) body['title'] = title;
    if (destinationCity != null) body['destination_city'] = destinationCity;
    if (destinationCountry != null) body['destination_country'] = destinationCountry;
    if (startDate != null) body['start_date'] = startDate.toIso8601String();
    if (endDate != null) body['end_date'] = endDate.toIso8601String();
    if (description != null) body['description'] = description;
    if (budget != null) body['budget'] = budget;
    if (currency != null) body['currency'] = currency;
    if (status != null) body['status'] = status;
    if (tripType != null) body['trip_type'] = tripType;
    if (numberOfTravelers != null) body['number_of_travelers'] = numberOfTravelers;

    final response = await _apiService.put('/trips/$tripId', body: body);
    final trip = Trip.fromJson(response);
    
    // Se a data de início mudou, reagendar notificações
    if (startDate != null && destinationCity != null) {
      try {
        await _notificationService.cancelTripNotifications(trip.id);
        await _notificationService.scheduleTripNotifications(
          tripId: trip.id,
          destination: destinationCity,
          startDate: startDate,
        );
        if (kDebugMode) {
          print('✅ Notificações reagendadas para viagem: ${trip.id}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Erro ao reagendar notificações: $e');
        }
      }
    }
    
    return trip;
  }

  // Deletar viagem
  Future<void> deleteTrip(String tripId) async {
    // Cancelar notificações antes de deletar
    try {
      await _notificationService.cancelTripNotifications(tripId);
      if (kDebugMode) {
        print('✅ Notificações canceladas para viagem: $tripId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Erro ao cancelar notificações: $e');
      }
    }
    
    await _apiService.delete('/trips/$tripId');
  }

  // Exportar viagem
  Future<Map<String, dynamic>> exportTrip(String tripId) async {
    final response = await _apiService.get('/trips/$tripId/export');
    return response as Map<String, dynamic>;
  }

  // Buscar viagem pelo código de partilha (6 caracteres)
  Future<Map<String, dynamic>> fetchTripByCode(String code) async {
    final response = await _apiService.get('/trips/by-code/$code');

    // Normalizar respostas diferentes do backend:
    // - Caso o backend devolva { "trip": { ... }, "itineraries": [...] } -> retorna tal qual
    // - Caso o backend devolva diretamente o objeto `trip` -> encapsula em { trip: ..., itineraries: [] }
    if (response == null) {
      throw Exception('Viagem não encontrada');
    }

    if (response is Map<String, dynamic>) {
      if (response.containsKey('trip')) {
        return response;
      }

      // Se a resposta tem campos de uma viagem (ex: id, title), considera que é o objeto trip
      if (response.containsKey('id') || response.containsKey('title')) {
        return {
          'trip': response,
          'itineraries': response['itineraries'] ?? [],
        };
      }
    }

    throw Exception('Resposta inválida do servidor');
  }

  // Gerar ou obter um código de partilha para a viagem
  Future<String> generateTripCode(String tripId) async {
    final response = await _apiService.post('/trips/$tripId/code');
    if (response is Map && response.containsKey('trip_code')) {
      return response['trip_code'].toString();
    }
    throw Exception('Invalid response from server');
  }

  // Importar viagem
  Future<Trip> importTrip(Map<String, dynamic> tripData) async {
    final response = await _apiService.post('/trips/import', body: tripData);
    return Trip.fromJson(response);
  }
}

class Trip {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String destinationCity;
  final String destinationCountry;
  final DateTime startDate;
  final DateTime endDate;
  final double? budget;
  final String currency;
  final String status;
  final String? tripType;
  final int numberOfTravelers;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trip({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.destinationCity,
    required this.destinationCountry,
    required this.startDate,
    required this.endDate,
    this.budget,
    required this.currency,
    required this.status,
    this.tripType,
    required this.numberOfTravelers,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      destinationCity: json['destination_city'] ?? '',
      destinationCountry: json['destination_country'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      budget: json['budget']?.toDouble(),
      currency: json['currency'] ?? 'EUR',
      status: json['status'] ?? 'planning',
      tripType: json['trip_type'],
      numberOfTravelers: json['number_of_travelers'] ?? 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'destination_city': destinationCity,
      'destination_country': destinationCountry,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'budget': budget,
      'currency': currency,
      'status': status,
      'trip_type': tripType,
      'number_of_travelers': numberOfTravelers,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  int get durationInDays => endDate.difference(startDate).inDays + 1;
}
