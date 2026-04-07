import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../common/app_colors.dart';
import '../../../common/app_events.dart';
import '../../../common/constants/app_constants.dart';
import '../../../shared/widgets/snackbar_helper.dart';
import '../../../services/trips_service.dart';
import '../../../services/subscription_service.dart';
import '../../../services/google_drive_backup_service.dart';
import '../../../services/trip_cache_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/new_trip_draft_service.dart';
import '../../../shared/widgets/destination_search_modal.dart';
import '../../../shared/widgets/feature_locked_dialog.dart';
import '../../trip_details/my_trip_page.dart';
import 'dart:async';

/// =======================================================
/// MODELOS / WIDGETS AUXILIARES (DEVEM VIR ANTES DA PAGE)
/// =======================================================

class _DestinationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final DateTime? startDate;
  final DateTime? endDate;

  const _DestinationCard({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.startDate,
    this.endDate,
  });

  String _formatDateRange() {
    if (startDate == null || endDate == null) return '';

    final months = [
      AppConstants.jan.tr(),
      AppConstants.feb.tr(),
      AppConstants.mar.tr(),
      AppConstants.apr.tr(),
      AppConstants.may.tr(),
      AppConstants.jun.tr(),
      AppConstants.jul.tr(),
      AppConstants.aug.tr(),
      AppConstants.sep.tr(),
      AppConstants.oct.tr(),
      AppConstants.nov.tr(),
      AppConstants.dec.tr(),
    ];

    final startDay = startDate!.day;
    final endDay = endDate!.day;
    final month = months[startDate!.month - 1];
    final year = startDate!.year;

    return '$startDay - $endDay $month $year';
  }

  int _calculateDays() {
    if (startDate == null || endDate == null) return 0;
    return endDate!.difference(startDate!).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDate = startDate != null && endDate != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          if (imageUrl != null)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 180,
                color: isDark ? AppColors.grey800 : AppColors.grey200,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 180,
                color: isDark ? AppColors.grey800 : AppColors.grey200,
                child: const Center(
                  child: Icon(Icons.landscape, size: 64, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              height: 180,
              color: isDark ? AppColors.grey800 : AppColors.grey200,
              child: const Center(
                child: Icon(Icons.landscape, size: 64, color: Colors.grey),
              ),
            ),
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
                if (hasDate) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatDateRange()} • ${_calculateDays()} ${AppConstants.days.tr()}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// NEW TRIP PAGE
/// =======================================================

class NewTripPage extends StatefulWidget {
  final Trip? existingTrip; // Para edição
  final DestinationResult?
  initialDestination; // Para nova viagem com destino pré-selecionado

  const NewTripPage({super.key, this.existingTrip, this.initialDestination});

  @override
  State<NewTripPage> createState() => _NewTripPageState();
}

class _NewTripPageState extends State<NewTripPage> {
  final TextEditingController _destinationController = TextEditingController();
  final TripsService _tripsService = TripsService();
  final GoogleDriveBackupService _googleDriveBackupService =
      GoogleDriveBackupService();
  final TripCacheService _tripCacheService = TripCacheService();
  final NewTripDraftService _newTripDraftService = NewTripDraftService();

  DateTime? _startDate;
  DateTime? _endDate;

  String? _destinationImageUrl;
  String? _destinationSubtitle;
  String? _destinationCity;
  String? _destinationCountry;

  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isApplyingDraft = false;
  bool _skipDraftPersistence = false;

  /// Quando não tem existingTrip nem initialDestination, está embutido no tab
  /// e não deve mostrar seta de voltar (senão faz pop da raiz → ecrã preto).
  bool get _isEmbeddedInTab =>
      widget.existingTrip == null && widget.initialDestination == null;

  @override
  void initState() {
    super.initState();

    // Se estiver editando uma viagem existente, preencher os campos
    if (widget.existingTrip != null) {
      _isEditMode = true;
      final trip = widget.existingTrip!;

      final city = trip.destinationCity.trim();
      final country = trip.destinationCountry.trim();
      final destinationLabel = city.isNotEmpty
          ? city
          : (country.isNotEmpty ? country : trip.title);

      _destinationController.value = TextEditingValue(
        text: destinationLabel,
        selection: TextSelection.collapsed(offset: destinationLabel.length),
      );
      _startDate = trip.startDate;
      _endDate = trip.endDate;
      _destinationSubtitle =
          '${trip.destinationCity}, ${trip.destinationCountry}';
    }
    // Se vier de uma pesquisa, preencher o destino
    else if (widget.initialDestination != null) {
      final dest = widget.initialDestination!;
      _destinationController.value = TextEditingValue(
        text: dest.title,
        selection: TextSelection.collapsed(offset: dest.title.length),
      );
      _destinationSubtitle = dest.subtitle;
      _destinationImageUrl = dest.imageUrl;
      unawaited(_saveDraftSnapshot());
    } else {
      unawaited(_restoreDraftIfAvailable());
    }

    _destinationController.addListener(_onDraftInputsChanged);
  }

  void _onDraftInputsChanged() {
    if (_isEditMode || _isApplyingDraft || _skipDraftPersistence) return;
    unawaited(_saveDraftSnapshot());
  }

  Future<void> _restoreDraftIfAvailable() async {
    if (_isEditMode || widget.initialDestination != null) return;

    final draft = await _newTripDraftService.getDraft();
    if (draft == null || !mounted) return;

    final label = draft.destinationLabel.trim().isNotEmpty
        ? draft.destinationLabel.trim()
        : (draft.destinationCity?.trim().isNotEmpty ?? false)
        ? draft.destinationCity!.trim()
        : (draft.destinationCountry ?? '').trim();

    _isApplyingDraft = true;
    setState(() {
      _destinationController.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
      _destinationSubtitle = draft.destinationSubtitle;
      _destinationImageUrl = draft.destinationImageUrl;
      _destinationCity = draft.destinationCity;
      _destinationCountry = draft.destinationCountry;
      _startDate = draft.startDate;
      _endDate = draft.endDate;
    });
    _isApplyingDraft = false;
  }

  Future<void> _saveDraftSnapshot() async {
    if (_isEditMode || _isApplyingDraft || _skipDraftPersistence) return;

    final draft = NewTripDraft(
      destinationLabel: _destinationController.text.trim(),
      destinationSubtitle: _destinationSubtitle,
      destinationImageUrl: _destinationImageUrl,
      destinationCity: _destinationCity,
      destinationCountry: _destinationCountry,
      startDate: _startDate,
      endDate: _endDate,
      savedAt: DateTime.now(),
    );

    if (!draft.hasContent) {
      final removed = await _newTripDraftService.clearDraft();
      if (removed) {
        AppEvents.emitDraftChanged();
      }
      return;
    }

    await _newTripDraftService.saveDraft(draft);
    AppEvents.emitDraftChanged();
  }

  Future<void> _clearDraftAfterCreation() async {
    _skipDraftPersistence = true;
    final removed = await _newTripDraftService.clearDraft();
    if (removed) {
      AppEvents.emitDraftChanged();
    }
  }

  bool get _isFormValid =>
      _destinationController.text.trim().isNotEmpty &&
      _startDate != null &&
      _endDate != null;

  String _getDateRangeText() {
    if (_startDate == null && _endDate == null) {
      return AppConstants.pickDates.tr();
    }
    return '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
        ' - '
        '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';
  }

  Future<void> _selectDateRange() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });

      unawaited(_saveDraftSnapshot());
    }
  }

  Future<void> _openDestinationSearch() async {
    final result = await showModalBottomSheet<DestinationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DestinationSearchModal(),
    );

    if (result != null) {
      setState(() {
        _destinationController.text = result.title;
        _destinationSubtitle = result.subtitle;
        _destinationImageUrl = result.imageUrl;
        _destinationCity = result.city;
        _destinationCountry = result.country;
      });
    }
  }

  @override
  void dispose() {
    _destinationController.removeListener(_onDraftInputsChanged);
    if (!_isEditMode && !_skipDraftPersistence) {
      unawaited(_saveDraftSnapshot());
    }
    _destinationController.dispose();
    super.dispose();
  }

  String _buildTripTitle() {
    final city = _destinationCity?.trim();
    final country = _destinationCountry?.trim();
    final fallback = _destinationController.text.trim();

    String normalizeForEdit(String value) {
      if (!_isEditMode) return value;

      final tripPrefix = '${AppConstants.tripTo.tr()} ';
      if (value.toLowerCase().startsWith(tripPrefix.toLowerCase())) {
        return value.substring(tripPrefix.length).trim();
      }
      return value;
    }

    final normalizedFallback = normalizeForEdit(fallback);

    if (_isEditMode) {
      if (city != null &&
          city.isNotEmpty &&
          country != null &&
          country.isNotEmpty) {
        return '$city, $country';
      }

      if (city != null && city.isNotEmpty) {
        return city;
      }

      if (country != null && country.isNotEmpty) {
        return country;
      }

      return normalizedFallback;
    }

    if (city != null &&
        city.isNotEmpty &&
        country != null &&
        country.isNotEmpty) {
      return '${AppConstants.tripTo.tr()} $city, $country';
    }

    if (city != null && city.isNotEmpty) {
      return '${AppConstants.tripTo.tr()} $city';
    }

    if (country != null && country.isNotEmpty) {
      return '${AppConstants.tripTo.tr()} $country';
    }

    return '${AppConstants.tripTo.tr()} $normalizedFallback';
  }

  Future<void> _handleStartPlanning() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      SubscriptionStatus? status;

      // Check subscription limits for new trips (skip for edit mode)
      if (!_isEditMode) {
        status = await SubscriptionService().getStatus(forceRefresh: true);
        if (!status.canCreateTrip(status.tripsUsed)) {
          if (mounted) {
            setState(() => _isLoading = false);
            await showFeatureLockedDialog(
              context,
              title: AppConstants.tripLimitTitle.tr(),
              description: AppConstants.tripLimitDesc.tr(),
              suggestedPlan: SubscriptionPlan.basic,
            );
          }
          return;
        }
      }

      // Usar cidade e país do resultado da pesquisa
      final city = _destinationCity ?? _destinationController.text;
      final country = _destinationCountry ?? '';

      // Criar título descritivo para a viagem
      final tripTitle = _buildTripTitle();

      Trip trip;

      if (_isEditMode && widget.existingTrip != null) {
        // Atualizar viagem existente
        trip = await _tripsService.updateTrip(
          tripId: widget.existingTrip!.id,
          title: tripTitle,
          destinationCity: city,
          destinationCountry: country,
          startDate: _startDate!,
          endDate: _endDate!,
        );
      } else {
        // Criar nova viagem
        trip = await _tripsService.createTrip(
          title: tripTitle,
          destinationCity: city,
          destinationCountry: country,
          startDate: _startDate!,
          endDate: _endDate!,
        );

        await _clearDraftAfterCreation();

        if (status?.limits.canAutoBackup == true) {
          unawaited(_autoBackupNewTrip(trip.id));
        }
      }

      if (mounted) {
        if (_isEditMode) {
          // Se estiver editando, voltar para MyTripPage com a viagem atualizada
          Navigator.pop(context, trip);
        } else {
          // Se for nova viagem, substituir a rota atual pela página de detalhes
          // Isso garante que o botão voltar vá para home
          debugPrint(
            'DEBUG [new_trip_page] trip.userId: \x1B[36m\x1B[1m\x1B[4m\x1B[7m[36m${trip.userId}\x1B[0m | isReadOnly: \x1B[31mfalse\x1B[0m',
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MyTripPage(trip: trip, isReadOnly: false),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorText = e.toString();
        final isTripLimitError =
            errorText.contains('TRIP_LIMIT_REACHED') ||
            errorText.toLowerCase().contains('limite');

        if (isTripLimitError) {
          await showFeatureLockedDialog(
            context,
            title: AppConstants.tripLimitTitle.tr(),
            description: AppConstants.tripLimitDesc.tr(),
            suggestedPlan: SubscriptionPlan.basic,
          );
        } else if (errorText.contains('TRIP_EDIT_LOCKED')) {
          SnackBarHelper.showWarning(context, AppConstants.tripEditLocked.tr());
        } else {
          SnackBarHelper.showError(
            context,
            _isEditMode
                ? '${AppConstants.errorUpdatingTrip.tr()}: $e'
                : '${AppConstants.errorCreatingTrip.tr()}: $e',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _autoBackupNewTrip(String tripId) async {
    try {
      final isAppleICloudFlow =
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          (AuthService().currentUser?.isAppleAccount ?? false);

      if (isAppleICloudFlow) {
        await _tripCacheService.exportTripLocally(tripId);
        // Sync all trips so older/existing trips are also exported for iCloud import.
        await _tripCacheService.exportAllTripsLocally(forceFromApi: true);
        return;
      }

      final isSignedIn = await _googleDriveBackupService.isSignedIn();
      if (!isSignedIn) return;

      await _googleDriveBackupService.backupTripById(tripId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        elevation: 0,
        leading: _isEmbeddedInTab
            ? null
            : IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                onPressed: () => Navigator.pop(context),
              ),
        automaticallyImplyLeading: !_isEmbeddedInTab,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditMode
                  ? AppConstants.editYourTrip.tr()
                  : AppConstants.yourNextTrip.tr(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),

            const SizedBox(height: 32),

            /// DESTINATION FIELD
            GestureDetector(
              onTap: _openDestinationSearch,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.grey800 : AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _destinationController.text.isEmpty
                            ? AppConstants.toCountryOrCity.tr()
                            : _destinationController.text,
                        style: TextStyle(
                          color: _destinationController.text.isEmpty
                              ? (isDark
                                    ? AppColors.textHintDark
                                    : AppColors.textHintLight)
                              : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                        ),
                      ),
                    ),
                    Icon(Icons.search, color: AppColors.primary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// DATE RANGE
            GestureDetector(
              onTap: _selectDateRange,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.grey800 : AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getDateRangeText(),
                        style: TextStyle(
                          color: (_startDate == null && _endDate == null)
                              ? (isDark
                                    ? AppColors.textHintDark
                                    : AppColors.textHintLight)
                              : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// DESTINATION CARD
            if (_destinationController.text.isNotEmpty)
              _DestinationCard(
                title: _destinationController.text,
                subtitle: _destinationSubtitle ?? '',
                imageUrl: _destinationImageUrl,
                startDate: _startDate,
                endDate: _endDate,
              ),

            const Spacer(),

            /// CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isFormValid && !_isLoading)
                    ? _handleStartPlanning
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFormValid
                      ? AppColors.primary
                      : (isDark ? AppColors.grey800 : AppColors.grey200),
                  disabledBackgroundColor: isDark
                      ? AppColors.grey800
                      : AppColors.grey200,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditMode
                            ? AppConstants.saveChanges.tr()
                            : AppConstants.startPlanning.tr(),
                        style: TextStyle(
                          color: _isFormValid
                              ? Colors.white
                              : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
