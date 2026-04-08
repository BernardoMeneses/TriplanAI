import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'trips_service.dart';
import 'encryption_service.dart';
import 'subscription_service.dart';

/// Serviço para exportar e importar viagens
class TripShareService {
  final TripsService _tripsService = TripsService();
  final EncryptionService _encryptionService = EncryptionService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  Future<void> _ensureTripLimitNotReached() async {
    final status = await _subscriptionService.getStatus(forceRefresh: true);

    if (!status.canCreateTrip(status.tripsUsed)) {
      throw Exception('TRIP_LIMIT_REACHED');
    }
  }

  Map<String, dynamic> _normalizeBackupPayload(Map<String, dynamic> data) {
    final payload = Map<String, dynamic>.from(data);

    if (!payload.containsKey('trip')) {
      throw Exception('Formato de ficheiro inválido');
    }

    if (!payload.containsKey('version')) {
      // Compatibilidade com backups antigos sem campo version.
      payload['version'] = '1.0';
    }

    return payload;
  }

  Map<String, dynamic> _parseBackupFileContent(String rawContent) {
    // 1) Formato encriptado (share/export tradicional)
    try {
      final decrypted = _encryptionService.decrypt(rawContent);
      return _normalizeBackupPayload(decrypted);
    } catch (_) {
      // 2) Formato JSON puro (backups automáticos locais/cloud)
      try {
        final decoded = jsonDecode(rawContent);
        if (decoded is! Map) {
          throw Exception('Formato de ficheiro inválido');
        }

        final payload = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        return _normalizeBackupPayload(payload);
      } catch (e) {
        throw Exception('Formato de ficheiro inválido');
      }
    }
  }

  /// Exporta uma viagem e retorna o caminho do arquivo
  Future<String> exportTripToFile(String tripId, String tripTitle) async {
    try {
      final tripData = await _tripsService.exportTrip(tripId);
      final encryptedData = _encryptionService.encrypt(tripData);

      final directory = await getTemporaryDirectory();

      final destination = tripData['trip']['destination_city'] as String?;
      final country = tripData['trip']['destination_country'] as String?;

      String sanitize(String? value) {
        if (value == null || value.trim().isEmpty) return '';
        return value
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      final safeCity = sanitize(destination);
      final safeCountry = sanitize(country);

      String locationName;
      if (safeCity.isNotEmpty && safeCountry.isNotEmpty) {
        locationName = '$safeCity';
      } else if (safeCity.isNotEmpty) {
        locationName = safeCity;
      } else if (safeCountry.isNotEmpty) {
        locationName = safeCountry;
      } else {
        locationName = 'Trip';
      }

      final fileName = 'Trip to $locationName.triplan';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(encryptedData);

      return filePath;
    } catch (e) {
      debugPrint('Erro ao exportar viagem: $e');
      rethrow;
    }
  }

  /// Partilha uma viagem exportada
  Future<void> shareTrip(String tripId, String tripTitle) async {
    try {
      final filePath = await exportTripToFile(tripId, tripTitle);

      // Partilhar arquivo
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Viagem: $tripTitle',
        text: 'Confere esta viagem que criei no TriplanAI!',
      );
    } catch (e) {
      debugPrint('Erro ao partilhar viagem: $e');
      rethrow;
    }
  }

  /// Importa uma viagem de um arquivo .triplan encriptado
  Future<Trip> importTripFromFile(String filePath) async {
    try {
      await _ensureTripLimitNotReached();

      // Ler arquivo
      final file = File(filePath);
      final rawData = await file.readAsString();

      // Suporta ficheiros encriptados e JSON puro (retrocompatível).
      final tripData = _parseBackupFileContent(rawData);

      // Importar para o backend
      final newTrip = await _tripsService.importTrip(tripData);

      return newTrip;
    } catch (e) {
      debugPrint('Erro ao importar viagem: $e');
      rethrow;
    }
  }

  /// Importa uma viagem de dados encriptados diretos
  Future<Trip> importTripFromEncryptedString(String encryptedData) async {
    try {
      await _ensureTripLimitNotReached();

      final tripData = _parseBackupFileContent(encryptedData);

      // Importar para o backend
      final newTrip = await _tripsService.importTrip(tripData);

      return newTrip;
    } catch (e) {
      debugPrint('Erro ao importar viagem: $e');
      rethrow;
    }
  }
}
