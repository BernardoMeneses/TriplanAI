import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'itinerary_items_service.dart';
import 'connectivity_service.dart';

class FavoritesService {
  static const String _favoritesListKey = 'cached_favorites_list';

  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Singleton
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  /// Callback para notificar quando favoritos são atualizados em background
  Function(List<FavoritePlace>)? onFavoritesUpdated;

  /// Adicionar lugar aos favoritos
  Future<void> addFavorite(String placeId, {String? notes}) async {
    await _apiService.post(
      '/favorites/$placeId',
      body: notes != null ? {'notes': notes} : {},
    );
    // Atualizar cache após adicionar
    _refreshFavoritesInBackground();
  }

  /// Remover lugar dos favoritos
  Future<void> removeFavorite(String placeId) async {
    await _apiService.delete('/favorites/$placeId');
    // Atualizar cache após remover
    _refreshFavoritesInBackground();
  }

  /// Adicionar favorito de forma segura (sem duplicados)
  Future<bool> addFavoriteSafe(String placeId, {String? notes}) async {
    if (await isFavorite(placeId)) {
      return false;
    }
    await addFavorite(placeId, notes: notes);
    return true;
  }

  /// Obter todos os favoritos do utilizador - CACHE FIRST
  Future<List<FavoritePlace>> getFavorites({bool forceRefresh = false}) async {
    // Se forceRefresh, ir direto à net
    if (forceRefresh) {
      try {
        final favorites = await _fetchAndCacheFavorites();
        return favorites;
      } catch (e) {
        return _getCachedFavorites();
      }
    }

    // CACHE FIRST: Se tiver cache, retorna imediatamente
    final cachedFavorites = await _getCachedFavorites();
    if (cachedFavorites.isNotEmpty) {
      if (kDebugMode) {
        print(
          '💾 FavoritesService: Usando ${cachedFavorites.length} favoritos do cache',
        );
      }

      // Atualizar em background (não bloqueia)
      _refreshFavoritesInBackground();

      return cachedFavorites;
    }

    // Sem cache, tentar buscar da net
    try {
      final favorites = await _fetchAndCacheFavorites();
      return favorites;
    } catch (e) {
      if (kDebugMode) {
        print('❌ FavoritesService: Erro ao buscar favoritos: $e');
      }
      return [];
    }
  }

  /// Busca favoritos da API e guarda em cache
  Future<List<FavoritePlace>> _fetchAndCacheFavorites() async {
    final response = await _apiService.get('/favorites');
    final List<dynamic> data = response as List<dynamic>;
    final favorites = data.map((json) => FavoritePlace.fromJson(json)).toList();

    // Guardar em cache
    await _cacheFavorites(favorites);

    return favorites;
  }

  /// Guarda favoritos em cache
  Future<void> _cacheFavorites(List<FavoritePlace> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = favorites.map((f) => f.toJson()).toList();
      await prefs.setString(_favoritesListKey, jsonEncode(jsonList));
      if (kDebugMode) {
        print(
          '💾 FavoritesService: ${favorites.length} favoritos guardados em cache',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FavoritesService: Erro ao guardar cache: $e');
      }
    }
  }

  /// Obtém favoritos do cache local
  Future<List<FavoritePlace>> _getCachedFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_favoritesListKey);
      if (jsonString == null) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => FavoritePlace.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ FavoritesService: Erro ao ler cache: $e');
      }
      return [];
    }
  }

  /// Atualiza favoritos em background se online
  Future<void> _refreshFavoritesInBackground() async {
    // Verificar conectividade antes de tentar atualizar
    final hasConnection = await _connectivityService.checkConnectivity();
    if (!hasConnection) {
      if (kDebugMode) {
        print('📴 FavoritesService: Sem conexão, não atualiza em background');
      }
      return;
    }

    try {
      final favorites = await _fetchAndCacheFavorites();
      if (kDebugMode) {
        print('✅ FavoritesService: Favoritos atualizados em background');
      }
      // Notificar listeners
      onFavoritesUpdated?.call(favorites);
    } catch (e) {
      if (kDebugMode) {
        print('❌ FavoritesService: Erro ao atualizar em background: $e');
      }
    }
  }

  /// Verificar se um lugar é favorito
  Future<bool> isFavorite(String placeId) async {
    try {
      final response = await _apiService.get('/favorites/check/$placeId');
      return response['isFavorite'] as bool;
    } catch (e) {
      // Verificar no cache se offline
      final cached = await _getCachedFavorites();
      return cached.any((f) => f.placeId == placeId);
    }
  }

  /// Limpar cache de favoritos
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesListKey);
  }
}

class FavoritePlace {
  final String id;
  final String userId;
  final String placeId;
  final String? notes;
  final DateTime createdAt;
  final PlaceInfo place;

  FavoritePlace({
    required this.id,
    required this.userId,
    required this.placeId,
    this.notes,
    required this.createdAt,
    required this.place,
  });

  static DateTime _parseCreatedAt(dynamic value) {
    DateTime fromEpoch(int rawValue) {
      if (rawValue <= 0) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      // If looks like seconds precision, convert to milliseconds.
      final msValue = rawValue < 1000000000000 ? rawValue * 1000 : rawValue;
      return DateTime.fromMillisecondsSinceEpoch(msValue).toLocal();
    }

    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    if (value is int) {
      return fromEpoch(value);
    }

    if (value is double) {
      return fromEpoch(value.round());
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == '0') {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      final numeric = int.tryParse(trimmed);
      if (numeric != null) {
        return fromEpoch(numeric);
      }

      try {
        return DateTime.parse(trimmed).toLocal();
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      id: json['id'],
      userId: json['user_id'],
      placeId: json['place_id'],
      notes: json['notes'],
      createdAt: _parseCreatedAt(json['created_at'] ?? json['createdAt']),
      place: PlaceInfo.fromJson(json['place']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'place_id': placeId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'place': place.toJson(),
    };
  }
}
