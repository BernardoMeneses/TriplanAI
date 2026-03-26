import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../common/app_colors.dart';
import '../../common/constants/app_constants.dart';
import '../../services/trip_share_service.dart';
import '../../services/trips_service.dart';
import '../../services/encryption_service.dart';
import '../../common/app_events.dart';
import '../../services/trip_cache_service.dart';
import '../../shared/widgets/snackbar_helper.dart';

class ImportTripPage extends StatefulWidget {
  const ImportTripPage({super.key});

  @override
  State<ImportTripPage> createState() => _ImportTripPageState();
}

class _ImportTripPageState extends State<ImportTripPage> {
  final TripShareService _tripShareService = TripShareService();
  final TripsService _tripsService = TripsService();
  bool _isImporting = false;
  String? _selectedFilePath;
  Map<String, dynamic>? _tripPreview;
  final TextEditingController _codeController = TextEditingController();
  bool _isFetching = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      final raw = _codeController.text.trim();
      final code = raw.toUpperCase();
      // When empty: clear everything
      if (code.isEmpty) {
        if (mounted) setState(() { _tripPreview = null; _notFound = false; });
        return;
      }

      // If not valid 6-char alphanumeric, show not found while typing
      final valid = RegExp(r'^[A-Z0-9]{6}$').hasMatch(code);
      if (!valid) {
        if (mounted) setState(() { _tripPreview = null; _notFound = true; });
        return;
      }

      // If valid code, trigger fetch (debounce by ignoring if already fetching)
      if (!_isFetching) {
        // assign the controller text to uppercase without moving cursor
        final sel = _codeController.selection;
        _codeController.value = _codeController.value.copyWith(text: code, selection: sel);
        _fetchByCode();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['triplan'],
        withData: true,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;

        // Ler e desencriptar o arquivo
        final file = File(filePath);
        final encryptedData = await file.readAsString();

        // Tentar desencriptar para validar
        final tripShareService = TripShareService();
        try {
          // Apenas desencriptamos para preview, não importamos ainda
          final data = await _validateAndDecryptFile(encryptedData);

          setState(() {
            _selectedFilePath = filePath;
            _tripPreview = data;
          });
        } catch (e) {
          if (mounted) {
            SnackBarHelper.showError(context, '${AppConstants.fileInvalidOrCorrupted.tr()}: $e');
          }
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, '${AppConstants.errorReadingFile.tr()}: $e');
      }
    }
  }

  Future<void> _fetchByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      if (mounted) SnackBarHelper.showError(context, AppConstants.enterCodePrompt.tr());
      return;
    }

    try {
      setState(() {
        _isFetching = true;
        _notFound = false;
        _tripPreview = null; // clear old preview while fetching
      });

      final data = await _tripsService.fetchTripByCode(code);

      // If backend signals that the trip is owned by this user, prevent import
      if (data['owned'] == true) {
        if (mounted) SnackBarHelper.showWarning(context, AppConstants.tripAlreadyOwned.tr());
        setState(() {
          _tripPreview = null;
          _selectedFilePath = null;
        });
        return;
      }

      // If user is already a member, show a message but still show the preview
      if (data['already_member'] == true) {
        if (mounted) SnackBarHelper.showInfo(context, 'Já és membro desta viagem');
      }

      // Expect backend to return a map with 'trip' and optionally 'itineraries'
      setState(() {
        _tripPreview = data as Map<String, dynamic>?;
        _selectedFilePath = null; // indicate this came from code
        _notFound = _tripPreview == null;
      });
    } catch (e) {
      final msg = e.toString();
      // mark not found on 404-like errors
          if (msg.contains('Viagem não encontrada') || msg.toLowerCase().contains('not found')) {
        if (mounted) setState(() => _notFound = true);
      }
      if (mounted) {
        // If API returned not found, show a friendly message
          if (msg.contains('Viagem não encontrada') || msg.toLowerCase().contains('not found')) {
          SnackBarHelper.showError(context, AppConstants.errorNotFound.tr());
        } else {
          SnackBarHelper.showError(context, '${AppConstants.errorImportingTrip.tr()}: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<Map<String, dynamic>> _validateAndDecryptFile(String encryptedData) async {
    // Importar serviço de encriptação
    final encryptionService = EncryptionService();
    final data = encryptionService.decrypt(encryptedData);

    if (!data.containsKey('trip') || !data.containsKey('version')) {
      throw Exception(AppConstants.fileFormatInvalid);
    }

    return data;
  }

  Future<void> _importTrip() async {
    if (_tripPreview == null && _selectedFilePath == null) return;

    try {
      setState(() => _isImporting = true);

      Trip newTrip;

      if (_selectedFilePath != null) {
        // legacy: import from file
        newTrip = await _tripShareService.importTripFromFile(_selectedFilePath!);
      } else {
        // Join via share code (live-sync membership, no copy created)
        final code = _codeController.text.trim().toUpperCase();
        newTrip = await _tripsService.joinTrip(code);
      }

      if (mounted) {
        SnackBarHelper.showSuccess(context, AppConstants.tripImportedSuccess.tr());

        // Add to cache immediately so list views update without waiting for background refresh
        try {
          final cache = TripCacheService();
          await cache.addTripToCache(newTrip);
        } catch (_) {}

        // Emit event to inform other pages that a trip was imported
        try {
          AppEvents.emitTripImported(newTrip.toJson());
          AppEvents.emitTripsChanged();
        } catch (_) {}

        Navigator.pop(context, newTrip);
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {        
        if (msg.contains('Já és o dono desta viagem')) {
          SnackBarHelper.showWarning(context, AppConstants.tripAlreadyOwned.tr());
        } else if (msg.contains('Já és membro') || msg.contains('Viagem já importada') || msg.toLowerCase().contains('already imported')) {
          SnackBarHelper.showWarning(context, AppConstants.tripAlreadyImported.tr());
        } else {
          SnackBarHelper.showError(context, '${AppConstants.errorImportingTrip.tr()}: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Widget _buildPreviewCard() {
    if (_tripPreview == null) return const SizedBox.shrink();

    // Suporta duas formas de resposta:
    // 1) { 'trip': {...}, 'itineraries': [...] }
    // 2) {...} (objeto trip diretamente)
    late final Map<String, dynamic> trip;
    late final List<dynamic> itineraries;

    if (_tripPreview!.containsKey('trip') && _tripPreview!['trip'] is Map<String, dynamic>) {
      trip = _tripPreview!['trip'] as Map<String, dynamic>;
    } else if (_tripPreview is Map<String, dynamic>) {
      trip = Map<String, dynamic>.from(_tripPreview!);
    } else {
      // formato inesperado
      return const SizedBox.shrink();
    }

    final rawIt = _tripPreview!['itineraries'];
    if (rawIt is List) {
      itineraries = List<dynamic>.from(rawIt);
    } else {
      itineraries = <dynamic>[];
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flight_takeoff, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                      trip['title'] ?? AppConstants.untitled.tr(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.location_on,
              '${trip['destination_city']}, ${trip['destination_country']}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              '${_formatDate(trip['start_date'])} - ${_formatDate(trip['end_date'])}',
            ),
            if (trip['description'] != null && trip['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.description, trip['description']),
            ],
            if (trip['budget'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.account_balance_wallet,
                '${trip['currency'] ?? 'EUR'} ${trip['budget']}',
              ),
            ],
            const SizedBox(height: 8),
              _buildInfoRow(
                Icons.people,
                AppConstants.travelersCount.tr(args: [(trip['number_of_travelers'] ?? 1).toString()]),
              ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.list_alt, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                  Text(
                    AppConstants.itinerariesDays.tr(args: [itineraries.length.toString()]),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNotFound() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              AppConstants.errorNotFound.tr(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.tryDifferentSearch.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.importTripTitle.tr()),
        backgroundColor: AppColors.grey900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ícone e título
            const Icon(
              Icons.cloud_download,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
             Text(
              AppConstants.importSharedTrip.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.importTripDescription.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            // Import by 6-char code (preferred)
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: AppConstants.codeLabel.tr(),
                hintText: AppConstants.codeHint.tr(),
                prefixIcon: const Icon(Icons.vpn_key),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),


            const SizedBox(height: 16),
            // Secondary: keep file import available for backups/syncs


            if (_selectedFilePath != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppConstants.archiveSelected.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Preview da viagem ou estado "not found"
            if (_notFound) ...[
              const SizedBox(height: 12),
              _buildNotFound(),
            ] else if (_tripPreview != null) ...[
              Text(
                AppConstants.preview.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildPreviewCard(),
              const SizedBox(height: 24),
            ],

            // Botão de importar
            if (_tripPreview != null)
              ElevatedButton(
                onPressed: _isImporting ? null : _importTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isImporting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  AppConstants.importTripTitle.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Informações adicionais
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppConstants.howItWorks.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.importInstructions.tr(),
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
