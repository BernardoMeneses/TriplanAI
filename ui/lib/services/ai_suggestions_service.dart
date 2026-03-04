import 'api_service.dart';

class PlaceSuggestion {
  final String name;
  final String description;
  final String category;
  final String? estimatedDuration;
  final String? priceLevel;

  PlaceSuggestion({
    required this.name,
    required this.description,
    required this.category,
    this.estimatedDuration,
    this.priceLevel,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      name: json['name'],
      description: json['description'],
      category: json['category'],
      estimatedDuration: json['estimatedDuration'],
      priceLevel: json['priceLevel'],
    );
  }
}

class AISuggestionsService {
  final ApiService _apiService = ApiService();

  Future<List<PlaceSuggestion>> getPlaceSuggestions({
    required String city,
    required String country,
    int? dayNumber,
  }) async {
    final queryParams = {
      'city': city,
      'country': country,
      if (dayNumber != null) 'dayNumber': dayNumber.toString(),
    };

    try {
      final response = await _apiService.get(
        '/ai/place-suggestions',
        queryParams: queryParams,
      );

      if (response is List) {
        return response.map((json) => PlaceSuggestion.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting AI suggestions: $e');
      return [];
    }
  }
}