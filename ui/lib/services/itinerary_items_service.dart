import 'dart:convert';
import 'api_service.dart';

class Itinerary {
  final String id;
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final String? title;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  Itinerary({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.date,
    this.title,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Itinerary.fromJson(Map<String, dynamic> json) {
    return Itinerary(
      id: json['id'],
      tripId: json['trip_id'],
      dayNumber: json['day_number'],
      date: DateTime.parse(json['date']),
      title: json['title'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'day_number': dayNumber,
      'date': date.toIso8601String(),
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ItineraryItem {
  final String id;
  final String itineraryId;
  final String? placeId;
  final int orderIndex;
  final String title;
  final String? description;
  final String? startTime;
  final String? endTime;
  final int? durationMinutes;
  final String itemType;
  final String status;
  final double? cost;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PlaceInfo? place;
  // Distance tracking fields
  final int? distanceFromPreviousMeters;
  final String? distanceFromPreviousText;
  final int? travelTimeFromPreviousSeconds;
  final String? travelTimeFromPreviousText;
  final String? transportMode; // walking, driving, transit
  final bool isStartingPoint;

  ItineraryItem({
    required this.id,
    required this.itineraryId,
    this.placeId,
    required this.orderIndex,
    required this.title,
    this.description,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    required this.itemType,
    required this.status,
    this.cost,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.place,
    this.distanceFromPreviousMeters,
    this.distanceFromPreviousText,
    this.travelTimeFromPreviousSeconds,
    this.travelTimeFromPreviousText,
    this.transportMode,
    this.isStartingPoint = false,
  });

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      id: json['id'] ?? '',
      itineraryId: json['itinerary_id'] ?? '',
      placeId: json['place_id'],
      orderIndex: json['order_index'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      durationMinutes: json['duration_minutes'],
      itemType: json['item_type'] ?? 'activity',
      status: json['status'] ?? 'planned',
      cost: json['cost']?.toDouble(),
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      place: json['place'] != null ? PlaceInfo.fromJson(json['place']) : null,
      distanceFromPreviousMeters: json['distance_from_previous_meters'],
      distanceFromPreviousText: json['distance_from_previous_text'],
      travelTimeFromPreviousSeconds: json['travel_time_from_previous_seconds'],
      travelTimeFromPreviousText: json['travel_time_from_previous_text'],
      transportMode: json['transport_mode'],
      isStartingPoint: json['is_starting_point'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itinerary_id': itineraryId,
      'place_id': placeId,
      'order_index': orderIndex,
      'title': title,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'duration_minutes': durationMinutes,
      'item_type': itemType,
      'status': status,
      'cost': cost,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'place': place?.toJson(),
      'distance_from_previous_meters': distanceFromPreviousMeters,
      'distance_from_previous_text': distanceFromPreviousText,
      'travel_time_from_previous_seconds': travelTimeFromPreviousSeconds,
      'travel_time_from_previous_text': travelTimeFromPreviousText,
      'transport_mode': transportMode,
      'is_starting_point': isStartingPoint,
    };
  }
  ItineraryItem copyWith({
    String? id,
    String? itineraryId,
    String? placeId,
    int? orderIndex,
    String? title,
    String? description,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    String? itemType,
    String? status,
    double? cost,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    PlaceInfo? place,
    int? distanceFromPreviousMeters,
    String? distanceFromPreviousText,
    int? travelTimeFromPreviousSeconds,
    String? travelTimeFromPreviousText,
    String? transportMode,
    bool? isStartingPoint,
  }) {
    return ItineraryItem(
      id: id ?? this.id,
      itineraryId: itineraryId ?? this.itineraryId,
      placeId: placeId ?? this.placeId,
      orderIndex: orderIndex ?? this.orderIndex,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      itemType: itemType ?? this.itemType,
      status: status ?? this.status,
      cost: cost ?? this.cost,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      place: place ?? this.place,
      distanceFromPreviousMeters:
      distanceFromPreviousMeters ?? this.distanceFromPreviousMeters,
      distanceFromPreviousText:
      distanceFromPreviousText ?? this.distanceFromPreviousText,
      travelTimeFromPreviousSeconds:
      travelTimeFromPreviousSeconds ?? this.travelTimeFromPreviousSeconds,
      travelTimeFromPreviousText:
      travelTimeFromPreviousText ?? this.travelTimeFromPreviousText,
      transportMode: transportMode ?? this.transportMode,
      isStartingPoint: isStartingPoint ?? this.isStartingPoint,
    );
  }
}

class PlaceInfo {
  final String id;
  final String name;
  final String? googlePlaceId;
  final String? address;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final double? rating;
  final List<String>? images;
  final String? photoUrl;
  final String? placeType;
  final OpeningHours? openingHours;
  final int? priceLevel;
  final ContactInfo? contactInfo;

  PlaceInfo({
    required this.id,
    required this.name,
    this.googlePlaceId,
    this.address,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.rating,
    this.images,
    this.photoUrl,
    this.placeType,
    this.openingHours,
    this.priceLevel,
    this.contactInfo,
  });

  factory PlaceInfo.fromJson(Map<String, dynamic> json) {
    List<String>? imagesList;
    if (json['images'] != null) {
      if (json['images'] is List) {
        imagesList = List<String>.from(json['images']);
      } else if (json['images'] is String) {
        // Se vier como string JSON, fazer parse
        try {
          final decoded = jsonDecode(json['images']);
          if (decoded is List) {
            imagesList = List<String>.from(decoded);
          }
        } catch (e) {
          print('Error parsing images JSON: $e');
        }
      }
    }

    OpeningHours? openingHours;
    if (json['opening_hours'] != null) {
      try {
        if (json['opening_hours'] is Map) {
          openingHours = OpeningHours.fromJson(json['opening_hours']);
        } else if (json['opening_hours'] is String) {
          final decoded = jsonDecode(json['opening_hours']);
          if (decoded is Map) {
            openingHours = OpeningHours.fromJson(decoded as Map<String, dynamic>);
          }
        }
      } catch (e) {
        print('Error parsing opening_hours JSON: $e');
      }
    }

    ContactInfo? contactInfo;
    if (json['contact_info'] != null) {
      try {
        if (json['contact_info'] is Map) {
          contactInfo = ContactInfo.fromJson(json['contact_info']);
        } else if (json['contact_info'] is String) {
          final decoded = jsonDecode(json['contact_info']);
          if (decoded is Map) {
            contactInfo = ContactInfo.fromJson(decoded as Map<String, dynamic>);
          }
        }
      } catch (e) {
        print('Error parsing contact_info JSON: $e');
      }
    }

    return PlaceInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      googlePlaceId: json['google_place_id'],
      address: json['address'],
      city: json['city'],
      country: json['country'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      rating: json['rating']?.toDouble(),
      images: imagesList,
      photoUrl: json['photoUrl'],
      placeType: json['place_type'],
      openingHours: openingHours,
      priceLevel: json['price_level'],
      contactInfo: contactInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'google_place_id': googlePlaceId,
      'address': address,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'images': images,
      'photoUrl': photoUrl,
      'place_type': placeType,
      'opening_hours': openingHours?.toJson(),
      'price_level': priceLevel,
      'contact_info': contactInfo?.toJson(),
    };
  }
}

class OpeningHours {
  final List<String> weekdayText;
  final bool? isOpenNow;

  OpeningHours({
    required this.weekdayText,
    this.isOpenNow,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) {
    return OpeningHours(
      weekdayText: json['weekdayText'] != null
          ? List<String>.from(json['weekdayText'])
          : [],
      isOpenNow: json['isOpenNow'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weekdayText': weekdayText,
      'isOpenNow': isOpenNow,
    };
  }

  /// Retorna o horário de hoje formatado (ex: "9:00 - 18:00")
  String? getTodayHours() {
    if (weekdayText.isEmpty) return null;

    final now = DateTime.now();
    final dayIndex = now.weekday - 1; // 0 = Monday, 6 = Sunday

    if (dayIndex < weekdayText.length) {
      final todayText = weekdayText[dayIndex];
      // Formato típico: "Monday: 9:00 AM – 6:00 PM"
      final colonIndex = todayText.indexOf(':');
      if (colonIndex != -1 && colonIndex < todayText.length - 1) {
        return todayText.substring(colonIndex + 1).trim();
      }
      return todayText;
    }
    return null;
  }
}

class ContactInfo {
  final String? phone;
  final String? website;

  ContactInfo({
    this.phone,
    this.website,
  });

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      phone: json['phone'],
      website: json['website'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'website': website,
    };
  }

  bool get hasContact => phone != null || website != null;
}

class ItineraryItemsService {
  final ApiService _apiService = ApiService();

  Future<ItineraryItem> createItem({
    required String itineraryId,
    String? placeId,
    String? googlePlaceId,
    required int orderIndex,
    required String title,
    String? description,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    required String itemType,
    String status = 'planned',
    double? cost,
    String? notes,
  }) async {
    final response = await _apiService.post('/itinerary-items', body: {
      'itineraryId': itineraryId,
      'placeId': placeId,
      'googlePlaceId': googlePlaceId,
      'orderIndex': orderIndex,
      'title': title,
      'description': description,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'itemType': itemType,
      'status': status,
      'cost': cost,
      'notes': notes,
    });

    return ItineraryItem.fromJson(response);
  }

  Future<List<ItineraryItem>> getItemsByItinerary(String itineraryId) async {
    print('🔄 Fetching items for itinerary: $itineraryId');
    final response = await _apiService.get('/itinerary-items/itinerary/$itineraryId');

    if (response is List) {
      final items = response.map((json) => ItineraryItem.fromJson(json)).toList();
      print('📡 API returned ${items.length} items:');
      for (int i = 0; i < items.length; i++) {
        print('  API item $i: ${items[i].title} - startTime: ${items[i].startTime}');
      }
      return items;
    }
    return [];
  }

  Future<Itinerary> getOrCreateItineraryByDay(String tripId, int dayNumber) async {
    final response = await _apiService.get('/itineraries/trip/$tripId/day/$dayNumber');
    return Itinerary.fromJson(response);
  }

  Future<ItineraryItem> getItemById(String id) async {
    final response = await _apiService.get('/itinerary-items/$id');
    return ItineraryItem.fromJson(response);
  }

  Future<ItineraryItem> updateItem(
      String id, {
        int? orderIndex,
        String? title,
        String? description,
        String? startTime,
        String? endTime,
        int? durationMinutes,
        String? status,
        double? cost,
        String? notes,
        String? transportMode,
      }) async {
    final response = await _apiService.put('/itinerary-items/$id', body: {
      if (orderIndex != null) 'orderIndex': orderIndex,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (status != null) 'status': status,
      if (cost != null) 'cost': cost,
      if (notes != null) 'notes': notes,
      if (transportMode != null) 'transportMode': transportMode,
    });

    return ItineraryItem.fromJson(response);
  }

  Future<void> deleteItem(String id) async {
    await _apiService.delete('/itinerary-items/$id');
  }

  Future<void> reorderItems(String itineraryId, List<String> itemIds) async {
    await _apiService.put('/itinerary-items/reorder/$itineraryId', body: {
      'itemIds': itemIds,
    });
  }

  Future<void> recalculateDistances(String itineraryId) async {
    await _apiService.post('/itineraries/$itineraryId/recalculate-distances');
  }

  Future<ItineraryItem> moveItemToDay(String itemId, String newItineraryId) async {
    final response = await _apiService.put('/itinerary-items/$itemId', body: {
      'itineraryId': newItineraryId,
    });
    return ItineraryItem.fromJson(response);
  }
}
