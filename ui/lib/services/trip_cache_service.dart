import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'trips_service.dart';
import 'itinerary_items_service.dart';
import 'connectivity_service.dart';

/// Serviço para cache local de viagens (funciona offline)
class TripCacheService {
  static const String _tripsListKey = 'cached_trips_list';
  static const String _tripDetailsPrefix = 'cached_trip_';
  static const String _lastSyncKey = 'trips_last_sync';
  static const String _itineraryPrefix = 'cached_itinerary_';
  static const String _itineraryItemsPrefix = 'cached_items_';
  static const String _tripImagePrefix = 'cached_trip_image_';

  final TripsService _tripsService = TripsService();
  final ItineraryItemsService _itemsService = ItineraryItemsService();
  final ConnectivityService _connectivityService = ConnectivityService();

  /// Indica se a última operação usou cache offline
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  // Singleton
  static final TripCacheService _instance = TripCacheService._internal();
  factory TripCacheService() => _instance;
  TripCacheService._internal();

  /// Callback para notificar quando dados são atualizados em background
  Function(List<Trip>)? onTripsUpdated;

  /// Obtém viagens - CACHE FIRST (como WhatsApp)
  /// Retorna cache imediatamente e atualiza em background se online
  Future<List<Trip>> getTrips({bool forceRefresh = false}) async {
    // Se forceRefresh, ir direto à net
    if (forceRefresh) {
      try {
        final trips = await _fetchAndCacheTrips();
        _isOfflineMode = false;
        return trips;
      } catch (e) {
        _isOfflineMode = true;
        return _getCachedTrips();
      }
    }

    // CACHE FIRST: Se tiver cache, retorna imediatamente
    final cachedTrips = await _getCachedTrips();
    if (cachedTrips.isNotEmpty) {
      if (kDebugMode) {
        print(
          '💾 TripCacheService: Usando ${cachedTrips.length} viagens do cache',
        );
      }

      // Atualizar em background (não bloqueia)
      _refreshTripsInBackground();

      _isOfflineMode = false; // Temos dados, não é "offline mode" visual
      return cachedTrips;
    }

    // Sem cache - tentar online
    try {
      final trips = await _fetchAndCacheTrips();
      _isOfflineMode = false;
      return trips;
    } catch (e) {
      if (kDebugMode) {
        print('📴 TripCacheService: Sem cache e sem net');
      }
      _isOfflineMode = true;
      return [];
    }
  }

  /// Atualiza viagens em background sem bloquear UI
  Future<void> _refreshTripsInBackground() async {
    // Verificar conectividade primeiro
    final hasInternet = await _connectivityService.checkConnectivity();
    if (!hasInternet) return;

    try {
      final trips = await _fetchAndCacheTrips();
      _isOfflineMode = false;
      if (kDebugMode) {
        print('🔄 TripCacheService: Cache atualizado em background');
      }
      // Notificar se alguém estiver a ouvir
      onTripsUpdated?.call(trips);
    } catch (e) {
      // Falhou silenciosamente - cache continua válido
      if (kDebugMode) {
        print(
          '📴 TripCacheService: Atualização background falhou (usando cache)',
        );
      }
    }
  }

  /// Obtém detalhes de uma viagem - CACHE FIRST
  Future<Trip?> getTripById(String tripId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      try {
        final trip = await _tripsService.getTripById(tripId);
        await _cacheTripDetails(trip);
        _isOfflineMode = false;
        return trip;
      } catch (e) {
        _isOfflineMode = true;
        return _getCachedTripById(tripId);
      }
    }

    // CACHE FIRST
    final cachedTrip = await _getCachedTripById(tripId);
    if (cachedTrip != null) {
      if (kDebugMode) {
        print('💾 TripCacheService: Usando viagem $tripId do cache');
      }
      // Atualizar em background
      _refreshTripInBackground(tripId);
      return cachedTrip;
    }

    // Sem cache - tentar online
    try {
      final trip = await _tripsService.getTripById(tripId);
      await _cacheTripDetails(trip);
      _isOfflineMode = false;
      return trip;
    } catch (e) {
      if (kDebugMode) {
        print('📴 TripCacheService: Viagem $tripId não encontrada');
      }
      _isOfflineMode = true;
      return null;
    }
  }

  /// Atualiza viagem em background
  Future<void> _refreshTripInBackground(String tripId) async {
    final hasInternet = await _connectivityService.checkConnectivity();
    if (!hasInternet) return;

    try {
      final trip = await _tripsService.getTripById(tripId);
      await _cacheTripDetails(trip);
    } catch (e) {
      // Falha silenciosa
    }
  }

  /// Busca viagens da API e guarda em cache
  Future<List<Trip>> _fetchAndCacheTrips() async {
    final trips = await _tripsService.getTrips();
    await _cacheTrips(trips);
    return trips;
  }

  /// Guarda lista de viagens em cache
  Future<void> _cacheTrips(List<Trip> trips) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripsJson = trips.map((t) => t.toJson()).toList();
      await prefs.setString(_tripsListKey, jsonEncode(tripsJson));
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);

      // Guardar também detalhes de cada viagem
      for (final trip in trips) {
        await _cacheTripDetails(trip);
      }

      if (kDebugMode) {
        print(
          '💾 TripCacheService: ${trips.length} viagens guardadas em cache',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao guardar cache: $e');
      }
    }
  }

  /// Adiciona uma viagem ao cache local (se já existir, substitui)
  Future<void> addTripToCache(Trip trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_tripsListKey);
      List<dynamic> tripsList = [];
      if (cachedJson != null) {
        tripsList = jsonDecode(cachedJson) as List<dynamic>;
        // remover qualquer ocorrência existente
        tripsList.removeWhere((j) => j['id'].toString() == trip.id);
      }
      tripsList.add(trip.toJson());
      await prefs.setString(_tripsListKey, jsonEncode(tripsList));
      await _cacheTripDetails(trip);
      if (kDebugMode)
        print('💾 TripCacheService: Viagem ${trip.id} adicionada ao cache');
      // notificar listeners
      onTripsUpdated?.call(tripsList.map((j) => Trip.fromJson(j)).toList());
    } catch (e) {
      if (kDebugMode)
        print('❌ TripCacheService: Erro ao adicionar viagem ao cache: $e');
    }
  }

  /// Remove uma viagem do cache local
  Future<void> removeTripFromCache(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_tripsListKey);
      if (cachedJson == null) return;
      final List<dynamic> tripsList = jsonDecode(cachedJson) as List<dynamic>;
      final initialLen = tripsList.length;
      tripsList.removeWhere((j) => j['id'].toString() == tripId);
      if (tripsList.length != initialLen) {
        await prefs.setString(_tripsListKey, jsonEncode(tripsList));
      }
      // remover detalhes em cache
      await prefs.remove('$_tripDetailsPrefix$tripId');
      if (kDebugMode)
        print('💾 TripCacheService: Viagem $tripId removida do cache');
      onTripsUpdated?.call(tripsList.map((j) => Trip.fromJson(j)).toList());
    } catch (e) {
      if (kDebugMode)
        print('❌ TripCacheService: Erro ao remover viagem do cache: $e');
    }
  }

  /// Guarda detalhes de uma viagem em cache
  Future<void> _cacheTripDetails(Trip trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_tripDetailsPrefix${trip.id}',
        jsonEncode(trip.toJson()),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao guardar detalhes da viagem: $e');
      }
    }
  }

  /// Obtém viagens do cache local
  Future<List<Trip>> _getCachedTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_tripsListKey);

      if (cachedJson == null) {
        return [];
      }

      final List<dynamic> tripsList = jsonDecode(cachedJson);
      return tripsList.map((json) => Trip.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao ler cache: $e');
      }
      return [];
    }
  }

  /// Obtém detalhes de uma viagem do cache
  Future<Trip?> _getCachedTripById(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('$_tripDetailsPrefix$tripId');

      if (cachedJson == null) {
        return null;
      }

      return Trip.fromJson(jsonDecode(cachedJson));
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao ler viagem do cache: $e');
      }
      return null;
    }
  }

  /// Retorna a data da última sincronização
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Verifica se há cache disponível
  Future<bool> hasCachedTrips() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tripsListKey);
  }

  // ============ CACHE DE IMAGENS DE DESTINO ============

  /// Guarda a URL da imagem do destino em cache
  Future<void> cacheTripImage(String tripId, String imageUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_tripImagePrefix$tripId', imageUrl);
      if (kDebugMode) {
        print(
          '💾 TripCacheService: Imagem da viagem $tripId guardada em cache',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao guardar imagem: $e');
      }
    }
  }

  /// Obtém a URL da imagem do destino do cache
  Future<String?> getCachedTripImage(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_tripImagePrefix$tripId');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao ler imagem do cache: $e');
      }
      return null;
    }
  }

  /// Remove a imagem de destino em cache para uma viagem específica.
  Future<void> removeTripImageFromCache(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_tripImagePrefix$tripId');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao remover imagem do cache: $e');
      }
    }
  }

  /// Limpa cache visual e de planeamento quando o destino da viagem muda.
  Future<void> clearTripDataAfterDestinationChange(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itineraryPrefix = '$_itineraryPrefix${tripId}_';
      final keys = prefs.getKeys();

      final keysToRemove = <String>{
        _tripsListKey,
        _lastSyncKey,
        '$_tripDetailsPrefix$tripId',
        '$_tripImagePrefix$tripId',
      };

      for (final key in keys) {
        if (!key.startsWith(itineraryPrefix)) continue;

        final itineraryJson = prefs.getString(key);
        if (itineraryJson != null) {
          try {
            final itineraryMap =
                jsonDecode(itineraryJson) as Map<String, dynamic>;
            final itineraryId = itineraryMap['id']?.toString();
            if (itineraryId != null && itineraryId.isNotEmpty) {
              keysToRemove.add('$_itineraryItemsPrefix$itineraryId');
            }
          } catch (_) {}
        }

        keysToRemove.add(key);
      }

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      if (kDebugMode) {
        print(
          '🧹 TripCacheService: cache reset após mudança de destino $tripId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: erro ao limpar cache da viagem $tripId: $e');
      }
    }
  }

  // ============ CACHE DE ITINERÁRIOS E ITEMS ============

  /// Sincroniza todos os itinerários e items de uma viagem para cache
  /// Deve ser chamado quando abre uma viagem (para garantir que todos os dias ficam em cache)
  Future<void> syncTripItineraries(String tripId, int durationInDays) async {
    // Verificar conectividade primeiro (rápido)
    final hasInternet = await _connectivityService.checkConnectivity();
    if (!hasInternet) {
      if (kDebugMode) {
        print('📴 TripCacheService: Sem internet - sincronização ignorada');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print(
          '🔄 TripCacheService: Sincronizando $durationInDays dias da viagem $tripId',
        );
      }

      for (int day = 1; day <= durationInDays; day++) {
        try {
          // Buscar e guardar itinerary em cache
          final itinerary = await _itemsService.getOrCreateItineraryByDay(
            tripId,
            day,
          );
          await _cacheItinerary(tripId, day, itinerary);

          // Buscar e guardar items em cache
          final items = await _itemsService.getItemsByItinerary(itinerary.id);
          await cacheItineraryItems(itinerary.id, items);

          if (kDebugMode) {
            print('  ✅ Dia $day: ${items.length} items em cache');
          }
        } catch (e) {
          if (kDebugMode) {
            print('  ⚠️ Dia $day: Erro ao sincronizar - $e');
          }
        }
      }

      if (kDebugMode) {
        print('✅ TripCacheService: Sincronização completa');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro na sincronização: $e');
      }
    }
  }

  /// Obtém itinerary por trip e dia - CACHE FIRST
  Future<Itinerary?> getOrCreateItineraryByDay(
    String tripId,
    int dayNumber,
  ) async {
    // CACHE FIRST
    final cachedItinerary = await _getCachedItinerary(tripId, dayNumber);
    if (cachedItinerary != null) {
      if (kDebugMode) {
        print('💾 TripCacheService: Usando itinerary dia $dayNumber do cache');
      }
      // Atualizar em background
      _refreshItineraryInBackground(tripId, dayNumber);
      return cachedItinerary;
    }

    // Sem cache - tentar online
    try {
      final itinerary = await _itemsService.getOrCreateItineraryByDay(
        tripId,
        dayNumber,
      );
      await _cacheItinerary(tripId, dayNumber, itinerary);
      _isOfflineMode = false;
      return itinerary;
    } catch (e) {
      if (kDebugMode) {
        print('📴 TripCacheService: Itinerary dia $dayNumber não encontrado');
      }
      _isOfflineMode = true;
      return null;
    }
  }

  /// Atualiza itinerary em background
  Future<void> _refreshItineraryInBackground(
    String tripId,
    int dayNumber,
  ) async {
    final hasInternet = await _connectivityService.checkConnectivity();
    if (!hasInternet) return;

    try {
      final itinerary = await _itemsService.getOrCreateItineraryByDay(
        tripId,
        dayNumber,
      );
      await _cacheItinerary(tripId, dayNumber, itinerary);
    } catch (e) {
      // Falha silenciosa
    }
  }

  /// Obtém items do itinerário - CACHE FIRST
  /// Obtém items do itinerário - CACHE FIRST
  Future<List<ItineraryItem>> getItemsByItinerary(
    String itineraryId, {
    bool forceRefresh = false,
  }) async {
    // Se forceRefresh, ir direto à net e atualizar cache
    if (forceRefresh) {
      try {
        final items = await _itemsService.getItemsByItinerary(itineraryId);
        await cacheItineraryItems(itineraryId, items);
        _isOfflineMode = false;
        return items;
      } catch (e) {
        if (kDebugMode) {
          print('📴 TripCacheService: forceRefresh falhou, usando cache');
        }
        _isOfflineMode = true;
        return _getCachedItineraryItems(itineraryId);
      }
    }

    // CACHE FIRST: Se tiver cache, retorna imediatamente
    final cachedItems = await _getCachedItineraryItems(itineraryId);
    if (cachedItems.isNotEmpty) {
      if (kDebugMode) {
        print(
          '💾 TripCacheService: Usando ${cachedItems.length} items do cache',
        );
      }
      // Atualizar em background (não bloqueia)
      _refreshItemsInBackground(itineraryId);
      return cachedItems;
    }

    // Sem cache - tentar online
    try {
      final items = await _itemsService.getItemsByItinerary(itineraryId);
      await cacheItineraryItems(itineraryId, items);
      _isOfflineMode = false;
      return items;
    } catch (e) {
      if (kDebugMode) {
        print('📴 TripCacheService: Items não encontrados');
      }
      _isOfflineMode = true;
      return [];
    }
  }

  /// Atualiza items em background
  Future<void> _refreshItemsInBackground(String itineraryId) async {
    final hasInternet = await _connectivityService.checkConnectivity();
    if (!hasInternet) return;

    try {
      final items = await _itemsService.getItemsByItinerary(itineraryId);
      await cacheItineraryItems(itineraryId, items);
    } catch (e) {
      // Falha silenciosa
    }
  }

  /// Guarda itinerary em cache
  Future<void> _cacheItinerary(
    String tripId,
    int dayNumber,
    Itinerary itinerary,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_itineraryPrefix${tripId}_$dayNumber';
      await prefs.setString(key, jsonEncode(itinerary.toJson()));
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao guardar itinerary: $e');
      }
    }
  }

  /// Obtém itinerary do cache
  Future<Itinerary?> _getCachedItinerary(String tripId, int dayNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_itineraryPrefix${tripId}_$dayNumber';
      final cachedJson = prefs.getString(key);

      if (cachedJson == null) return null;

      return Itinerary.fromJson(jsonDecode(cachedJson));
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao ler itinerary do cache: $e');
      }
      return null;
    }
  }

  /// Guarda items do itinerário em cache (public)
  Future<void> cacheItineraryItems(
    String itineraryId,
    List<ItineraryItem> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_itineraryItemsPrefix$itineraryId';
      final itemsJson = items.map((i) => i.toJson()).toList();
      await prefs.setString(key, jsonEncode(itemsJson));

      if (kDebugMode) {
        print('💾 TripCacheService: ${items.length} items guardados em cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao guardar items: $e');
      }
    }
  }

  /// Obtém items do cache
  Future<List<ItineraryItem>> _getCachedItineraryItems(
    String itineraryId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_itineraryItemsPrefix$itineraryId';
      final cachedJson = prefs.getString(key);

      if (cachedJson == null) return [];

      final List<dynamic> itemsList = jsonDecode(cachedJson);
      return itemsList.map((json) => ItineraryItem.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ TripCacheService: Erro ao ler items do cache: $e');
      }
      return [];
    }
  }

  /// Limpa todo o cache de viagens
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (k) =>
              k == _tripsListKey ||
              k == _lastSyncKey ||
              k.startsWith(_tripDetailsPrefix) ||
              k.startsWith(_itineraryPrefix) ||
              k.startsWith(_itineraryItemsPrefix) ||
              k.startsWith(_tripImagePrefix),
        )
        .toList();

    for (final key in keys) {
      await prefs.remove(key);
    }

    if (kDebugMode) {
      print('🗑️ TripCacheService: Cache limpo');
    }
  }

  // ============ BACKUP GOOGLE DRIVE ============

  /// Diretório local para ficheiros .triplan
  Future<Directory> get _localBackupDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/trip_backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Exporta uma única viagem para ficheiro .triplan local.
  Future<String?> exportTripLocally(String tripId) async {
    try {
      final tripData = await _tripsService.exportTrip(tripId);
      final trip = tripData['trip'] as Map<String, dynamic>?;
      final destination =
          trip?['destination_city']?.toString().trim().isNotEmpty == true
          ? trip!['destination_city'].toString()
          : 'trip';

      final backupDir = await _localBackupDir;
      final fileName = _sanitizeFileName('${destination}_$tripId.triplan');
      final filePath = '${backupDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(jsonEncode(tripData));

      if (kDebugMode) {
        print('💾 Exportado (single): $fileName');
      }

      return filePath;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao exportar viagem $tripId: $e');
      }
      return null;
    }
  }

  /// Exporta todas as viagens para ficheiros .triplan locais.
  ///
  /// Se `forceFromApi` for true, tenta sincronizar primeiro com a API para
  /// garantir que viagens antigas/existentes também ficam em backup.
  Future<List<String>> exportAllTripsLocally({
    bool forceFromApi = false,
  }) async {
    final exportedFiles = <String>[];

    try {
      List<Trip> trips = [];

      if (forceFromApi) {
        try {
          trips = await _tripsService.getTrips();
          if (trips.isNotEmpty) {
            await _cacheTrips(trips);
          }
        } catch (_) {
          // fallback para cache local abaixo
        }
      }

      if (trips.isEmpty) {
        trips = await _getCachedTrips();
      }

      if (trips.isEmpty) {
        try {
          trips = await _tripsService.getTrips();
          if (trips.isNotEmpty) {
            await _cacheTrips(trips);
          }
        } catch (_) {
          // sem dados online/cache, retorna lista vazia
        }
      }

      final backupDir = await _localBackupDir;

      for (final trip in trips) {
        try {
          // Exportar viagem completa da API (com itinerários)
          final tripData = await _tripsService.exportTrip(trip.id);
          final fileName = _sanitizeFileName(
            '${trip.destinationCity}_${trip.id}.triplan',
          );
          final filePath = '${backupDir.path}/$fileName';

          final file = File(filePath);
          await file.writeAsString(jsonEncode(tripData));
          exportedFiles.add(filePath);

          if (kDebugMode) {
            print('💾 Exportado: $fileName');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Erro ao exportar ${trip.title}: $e');
          }
        }
      }

      if (kDebugMode) {
        print('✅ ${exportedFiles.length} viagens exportadas localmente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao exportar viagens: $e');
      }
    }

    return exportedFiles;
  }

  /// Lista ficheiros .triplan locais
  Future<List<File>> getLocalBackupFiles() async {
    try {
      final backupDir = await _localBackupDir;
      final files = await backupDir.list().toList();
      return files
          .whereType<File>()
          .where((f) => f.path.endsWith('.triplan'))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Sanitiza nome de ficheiro
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s.-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }
}
