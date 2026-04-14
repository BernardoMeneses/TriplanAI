import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../common/constants/oauth_constants.dart';
import 'trip_cache_service.dart';
import 'trips_service.dart';

/// Serviço para backup de viagens no Google Drive
class GoogleDriveBackupService {
  static const String _backupFolderName = 'TriplanAI Backups';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', drive.DriveApi.driveFileScope],
    serverClientId: OAuthConstants.googleServerClientId,
  );

  final TripCacheService _cacheService = TripCacheService();
  final TripsService _tripsService = TripsService();

  // Singleton
  static final GoogleDriveBackupService _instance =
      GoogleDriveBackupService._internal();
  factory GoogleDriveBackupService() => _instance;
  GoogleDriveBackupService._internal();

  drive.DriveApi? _driveApi;

  /// Verifica se está autenticado com Google Drive
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Faz login no Google e obtém acesso ao Drive
  Future<bool> signIn({bool forceAccountSelection = false}) async {
    try {
      if (forceAccountSelection) {
        // Permite reescolher conta explicitamente.
        await _googleSignIn.signOut();
      }

      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        return false;
      }

      final hasDriveScope = await _googleSignIn.requestScopes([
        drive.DriveApi.driveFileScope,
      ]);

      if (!hasDriveScope) {
        if (kDebugMode) {
          print('❌ GoogleDriveBackupService: Permissão Drive não concedida');
        }
        return false;
      }

      for (var attempt = 0; attempt < 3; attempt++) {
        final httpClient = await _googleSignIn.authenticatedClient();
        if (httpClient != null) {
          _driveApi = drive.DriveApi(httpClient);
          if (kDebugMode) {
            print(
              '✅ GoogleDriveBackupService: Login bem sucedido (${account.email})',
            );
          }
          return true;
        }

        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      if (kDebugMode) {
        print('❌ GoogleDriveBackupService: authenticatedClient retornou null');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ GoogleDriveBackupService: Erro no login: $e');
      }
      return false;
    }
  }

  Future<bool> _ensureDriveApiFromExistingSession() async {
    if (_driveApi != null) return true;

    try {
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return false;
      _driveApi = drive.DriveApi(httpClient);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Faz logout do Google Drive
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
    if (kDebugMode) {
      print('🔐 GoogleDriveBackupService: Logout');
    }
  }

  /// Obtém ou cria a pasta de backup no Drive
  Future<String?> _getOrCreateBackupFolder() async {
    if (_driveApi == null) {
      if (!await signIn()) return null;
    }

    try {
      // Procurar pasta existente
      final existingFolders = await _driveApi!.files.list(
        q: "name='$_backupFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
      );

      if (existingFolders.files != null && existingFolders.files!.isNotEmpty) {
        return existingFolders.files!.first.id;
      }

      // Criar nova pasta
      final folder = drive.File()
        ..name = _backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await _driveApi!.files.create(folder);
      if (kDebugMode) {
        print('📁 Pasta de backup criada no Google Drive');
      }
      return createdFolder.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao obter/criar pasta: $e');
      }
      return null;
    }
  }

  /// Faz backup de um ficheiro .triplan para o Google Drive
  Future<bool> backupFile(File file) async {
    try {
      final hasApi = await _ensureDriveApiFromExistingSession();
      if (!hasApi) {
        if (!await signIn()) return false;
      }

      final folderId = await _getOrCreateBackupFolder();
      if (folderId == null) return false;

      final fileName = file.path.split(Platform.pathSeparator).last;

      // Verificar se já existe e apagar
      await _deleteExistingFile(fileName, folderId);

      // Upload do novo ficheiro
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final media = drive.Media(file.openRead(), await file.length());

      await _driveApi!.files.create(driveFile, uploadMedia: media);

      if (kDebugMode) {
        print('☁️ Backup: $fileName enviado para Google Drive');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro no backup: $e');
      }
      return false;
    }
  }

  Future<bool> backupTripById(String tripId) async {
    try {
      if (!await isSignedIn()) {
        return false;
      }

      final hasApi = await _ensureDriveApiFromExistingSession();
      if (!hasApi) {
        return false;
      }

      final exportData = await _tripsService.exportTrip(tripId);
      final trip = (exportData['trip'] as Map<String, dynamic>? ?? {});
      final destinationCity = trip['destination_city']?.toString() ?? 'trip';
      final fileName = '${_sanitizeFileName(destinationCity)}_$tripId.triplan';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonEncode(exportData));

      final uploaded = await backupFile(file);

      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      return uploaded;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro no backup automático da viagem $tripId: $e');
      }
      return false;
    }
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s.-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  /// Apaga ficheiro existente com o mesmo nome
  Future<void> _deleteExistingFile(String fileName, String folderId) async {
    try {
      final existing = await _driveApi!.files.list(
        q: "name='$fileName' and '$folderId' in parents and trashed=false",
        spaces: 'drive',
      );

      if (existing.files != null) {
        for (final file in existing.files!) {
          await _driveApi!.files.delete(file.id!);
        }
      }
    } catch (e) {
      // Ignorar erros ao apagar
    }
  }

  /// Faz backup de todas as viagens locais para o Google Drive
  Future<int> backupAllTrips() async {
    int successCount = 0;

    try {
      // Exportar viagens localmente primeiro
      final exportedFiles = await _cacheService.exportAllTripsLocally();

      for (final filePath in exportedFiles) {
        final file = File(filePath);
        if (await file.exists()) {
          if (await backupFile(file)) {
            successCount++;
          }
        }
      }

      if (kDebugMode) {
        print(
          '✅ Backup completo: $successCount/${exportedFiles.length} viagens',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro no backup geral: $e');
      }
    }

    return successCount;
  }

  /// Lista backups disponíveis no Google Drive
  Future<List<drive.File>> listBackups() async {
    try {
      final folderId = await _getOrCreateBackupFolder();
      if (folderId == null) return [];

      final files = await _driveApi!.files.list(
        q: "'$folderId' in parents and trashed=false",
        spaces: 'drive',
        $fields: 'files(id, name, createdTime, size)',
      );

      return files.files ?? [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao listar backups: $e');
      }
      return [];
    }
  }

  /// Restaura um ficheiro de backup do Google Drive
  Future<File?> restoreBackup(String fileId, String fileName) async {
    try {
      if (_driveApi == null) {
        if (!await signIn()) return null;
      }

      final response =
          await _driveApi!.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/restored_$fileName');

      final List<int> dataStore = [];
      await for (final data in response.stream) {
        dataStore.addAll(data);
      }

      await localFile.writeAsBytes(dataStore);

      if (kDebugMode) {
        print('✅ Backup restaurado: $fileName');
      }
      return localFile;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao restaurar: $e');
      }
      return null;
    }
  }

  /// Apaga um backup do Google Drive
  Future<bool> deleteBackup(String fileId) async {
    try {
      if (_driveApi == null) {
        if (!await signIn()) return false;
      }

      await _driveApi!.files.delete(fileId);
      if (kDebugMode) {
        print('🗑️ Backup apagado');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao apagar: $e');
      }
      return false;
    }
  }
}
