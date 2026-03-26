import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:cached_network_image/cached_network_image.dart';
import '../../common/app_colors.dart';
import '../../common/app_events.dart';
import '../../common/constants/app_constants.dart';
import '../../services/trips_service.dart';
import '../../services/destinations_service.dart';
import 'package:flutter/services.dart';
import '../../services/trip_cache_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/notes_service.dart';
import 'day_details_page.dart';
import '../../shared/widgets/snackbar_helper.dart';

class MyTripPage extends StatefulWidget {
  final Trip trip;
  final VoidCallback? onTripUpdated;
  final bool isReadOnly;

  const MyTripPage({
    super.key,
    required this.trip,
    this.onTripUpdated,
    this.isReadOnly = false,
  });

  @override
  State<MyTripPage> createState() => _MyTripPageState();
}

class _MyTripPageState extends State<MyTripPage> {
  late Trip _trip;
  bool _isLoading = false;
  String? _destinationImageUrl;
  final DestinationsService _destinationsService = DestinationsService();
  final TripsService _tripsService = TripsService();
  final TripCacheService _cacheService = TripCacheService();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Connectivity state
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySubscription;
  // Map dayNumber -> items count
  Map<int, int> _dayItemCounts = {};
  
  /// ReadOnly efetivo - true se offline OU se widget.isReadOnly
  bool get _effectiveReadOnly => widget.isReadOnly || !_isOnline;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadDestinationImage();
    
    // Iniciar verificação de conectividade
    _isOnline = _connectivityService.isOnline;
    _connectivitySubscription = _connectivityService.connectivityStream.listen((isOnline) {
      if (mounted && _isOnline != isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
    
    // Sincronizar todos os dias em background (não bloqueia UI)
    if (!widget.isReadOnly) {
      _syncAllDays();
      // carregar contadores de items por dia (cache primeiro)
      _loadDayCounts();
    }
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Sincroniza todos os itinerários da viagem em background (fire and forget)
  void _syncAllDays() {
    // Não usar await - corre em background sem bloquear
    _cacheService.syncTripItineraries(_trip.id, _trip.durationInDays);
  }

  @override
  void didUpdateWidget(MyTripPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recarregar imagem se a viagem mudou
    if (oldWidget.trip.id != widget.trip.id ||
        oldWidget.trip.destinationCity != widget.trip.destinationCity ||
        oldWidget.trip.destinationCountry != widget.trip.destinationCountry) {
      _trip = widget.trip;
      _loadDestinationImage();
      // recarregar contadores quando a viagem muda
      _loadDayCounts();
    }
  }

  Future<void> _loadDayCounts() async {
    final Map<int, int> counts = {};
    for (int day = 1; day <= _trip.durationInDays; day++) {
      try {
        final itinerary = await _cacheService.getOrCreateItineraryByDay(_trip.id, day);
        if (itinerary == null) {
          counts[day] = 0;
          continue;
        }
        final items = await _cacheService.getItemsByItinerary(itinerary.id);
        counts[day] = items.length;
      } catch (e) {
        if (mounted && kDebugMode) print('Erro ao carregar contadores dia $day: $e');
        counts[day] = 0;
      }
    }
    if (!mounted) return;
    setState(() {
      _dayItemCounts = counts;
    });
  }

  Future<void> _loadDestinationImage() async {
    // Primeiro tentar carregar do cache
    final cachedImage = await _cacheService.getCachedTripImage(_trip.id);
    if (cachedImage != null && mounted) {
      setState(() {
        _destinationImageUrl = cachedImage;
      });
      return;
    }

    try {
      // Buscar o destino usando tanto cidade quanto país para melhor resultado
      final queries = [
        '${_trip.destinationCity}, ${_trip.destinationCountry}',
        _trip.destinationCity,
        _trip.destinationCountry,
      ];

      String? selectedPhotoUrl;

      // Tentar buscar fotos de múltiplas queries
      for (final query in queries) {
        if (selectedPhotoUrl != null) break;

        final searchResults = await _destinationsService.searchDestinations(query);

        if (searchResults.isNotEmpty && mounted) {
          // Pegar os primeiros resultados e tentar obter fotos
          for (final destination in searchResults.take(3)) {
            final details = await _destinationsService.getDestinationDetails(destination.placeId);

            if (details?.photoUrl != null) {
              selectedPhotoUrl = details!.photoUrl;
              break;
            }
          }
        }
      }

      if (mounted && selectedPhotoUrl != null) {
        // Guardar em cache para uso offline
        await _cacheService.cacheTripImage(_trip.id, selectedPhotoUrl);
        setState(() {
          _destinationImageUrl = selectedPhotoUrl;
        });
      }
    } catch (e) {
      // Se falhar, não tem problema, usará o gradient padrão
      debugPrint('Erro ao carregar imagem do destino: $e');
    }
  }

  String _formatDateRange() {
    final months = [
      AppConstants.jan.tr(), AppConstants.feb.tr(), AppConstants.mar.tr(),
      AppConstants.apr.tr(), AppConstants.may.tr(), AppConstants.jun.tr(),
      AppConstants.jul.tr(), AppConstants.aug.tr(), AppConstants.sep.tr(),
      AppConstants.oct.tr(), AppConstants.nov.tr(), AppConstants.dec.tr()
    ];

    final startDay = _trip.startDate.day;
    final endDay = _trip.endDate.day;
    final month = months[_trip.startDate.month - 1];
    final year = _trip.startDate.year;

    return '$startDay - $endDay $month $year';
  }

  int _getDaysUntilTrip() {
    final now = DateTime.now();
    final difference = _trip.startDate.difference(now);
    return difference.inDays;
  }

  Future<void> _editTrip() async {
    // Navegar para a página de edição com os dados da viagem
    final result = await Navigator.pushNamed(
      context,
      '/new-trip',
      arguments: _trip,
    );

    if (result != null && result is Trip) {
      setState(() {
        _trip = result;
      });
      widget.onTripUpdated?.call();
      // Emitir evento para atualizar listas globalmente
      try { AppEvents.emitTripsChanged(); } catch(_) {}
      // Recarregar a imagem do destino
      _loadDestinationImage();
    }
  }

  void _goToHome() {
    try { AppEvents.emitTripsChanged(); } catch(_) {}

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _openDayDetails(int dayNumber, DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DayDetailsPage(
          tripId: _trip.id,
          dayNumber: dayNumber,
          date: date,
          tripTitle: _trip.destinationCity,
          tripCity: _trip.destinationCity,
          tripCountry: _trip.destinationCountry,
          isReadOnly: _effectiveReadOnly,
        ),
      ),
    ).then((_) {
      // Quando voltar da página do dia, recarregar os contadores (possíveis alterações)
      _loadDayCounts();
    });
  }

  Future<void> _generateTripCode() async {
    try {
      setState(() => _isLoading = true);

      final code = await _tripsService.generateTripCode(_trip.id);

      if (!mounted) return;

      // Show dialog with the generated code and copy option
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppConstants.shareCodeDialogTitle.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              SelectableText(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(context);
                SnackBarHelper.showSuccess(this.context, AppConstants.codeCopied.tr());
              },
              child: Text(AppConstants.copy.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppConstants.close.tr()),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, '${AppConstants.errorSharingTrip.tr()}: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTrip() async {
    final isMember = _trip.isMember;
    // Mostrar diálogo de confirmação
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isMember ? 'Deixar viagem' : AppConstants.deleteTripTitle.tr()),
        content: Text(isMember
            ? 'Tens a certeza que pretendes deixar de seguir esta viagem partilhada?'
            : AppConstants.deleteTripMessage.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppConstants.cancel.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(isMember ? 'Deixar' : AppConstants.delete.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      final tripsService = TripsService();
      await tripsService.deleteTrip(_trip.id);

      // Only remove notes from local cache for owned trips (members share the owner's notes)
      if (!isMember) {
        try {
          await NotesService.deleteAllForTrip(_trip.id);
        } catch (_) {}
      }

      // Also remove from local cache immediately so lists update optimistically
      try {
        await _cacheService.removeTripFromCache(_trip.id);
      } catch (_) {}

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          isMember ? 'Viagem removida das suas viagens' : AppConstants.tripDeletedSuccess.tr(),
        );
        // Emit event to inform other pages
        try { AppEvents.emitTripsChanged(); } catch (_) {}
        // Voltar para home após apagar
        _goToHome();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, '${AppConstants.errorDeletingTrip.tr()}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTripMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Aviso de modo offline
              if (_effectiveReadOnly)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'offline.read_only_mode'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ListTile(
                leading: Icon(
                  Icons.vpn_key,
                  color: _effectiveReadOnly ? Colors.grey : AppColors.primary,
                ),
                title: Text(
                  AppConstants.generateShareCodeTitle.tr(),
                  style: TextStyle(
                    color: _effectiveReadOnly ? Colors.grey : null,
                  ),
                ),
                subtitle: Text(AppConstants.generateShareCodeSubtitle.tr()),
                enabled: !_effectiveReadOnly,
                onTap: _effectiveReadOnly ? null : () {
                  Navigator.pop(context);
                  _generateTripCode();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.edit,
                  color: _effectiveReadOnly ? Colors.grey : AppColors.primary,
                ),
                title: Text(
                  AppConstants.editTrip.tr(),
                  style: TextStyle(
                    color: _effectiveReadOnly ? Colors.grey : null,
                  ),
                ),
                enabled: !_effectiveReadOnly,
                onTap: _effectiveReadOnly ? null : () {
                  Navigator.pop(context);
                  _editTrip();
                },
              ),
              ListTile(
                leading: Icon(
                  _trip.isMember ? Icons.exit_to_app : Icons.delete_outline,
                  color: _effectiveReadOnly ? Colors.grey : Colors.red,
                ),
                title: Text(
                  _trip.isMember ? 'Deixar viagem' : AppConstants.deleteTrip.tr(),
                  style: TextStyle(
                    color: _effectiveReadOnly ? Colors.grey : Colors.red,
                  ),
                ),
                subtitle: Text(_trip.isMember ? 'Remover das tuas viagens' : AppConstants.deleteTripSubtitle.tr()),
                enabled: !_effectiveReadOnly,
                onTap: _effectiveReadOnly ? null : () {
                  Navigator.pop(context);
                  _deleteTrip();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysUntil = _getDaysUntilTrip();

    return Scaffold(
      body: Stack(
        children: [
          // Background com imagem do destino
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Stack(
              children: [
                if (_destinationImageUrl != null)
                  CachedNetworkImage(
                    imageUrl: _destinationImageUrl!,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withOpacity(0.8),
                            AppColors.primary.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withOpacity(0.8),
                            AppColors.primary.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.8),
                          AppColors.primary.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Conteúdo
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _goToHome,
                      ),
                      Expanded(
                        child: Text(
                          AppConstants.myTrip.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!_effectiveReadOnly)
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: _showTripMenu,
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Trip header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      Text(
                        _trip.destinationCity.isNotEmpty
                            ? _trip.destinationCity
                            : _trip.destinationCountry,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppConstants.startsIn.tr()} $daysUntil ${AppConstants.days.tr()} • ${_trip.durationInDays} ${AppConstants.daysTrip.tr()}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _formatDateRange(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Lista de dias
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.backgroundDark : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _trip.durationInDays,
                            itemBuilder: (context, index) {
                              final currentDay = _trip.startDate.add(Duration(days: index));
                              final dayOfWeek = _getDayOfWeek(currentDay.weekday);
                              final dayNumber = index + 1;

                              return GestureDetector(
                                onTap: () => _openDayDetails(dayNumber, currentDay),
                                child: _DayItem(
                                  dayNumber: dayNumber,
                                  dayOfWeek: dayOfWeek,
                                  date: currentDay,
                                  activitiesCount: _dayItemCounts[dayNumber] ?? 0,
                                  isCompleted: DateTime.now().isAfter(currentDay.add(const Duration(days: 1))),
                                  isLast: index == _trip.durationInDays - 1,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDayOfWeek(int weekday) {
    final days = [
      AppConstants.monday.tr(), AppConstants.tuesday.tr(), AppConstants.wednesday.tr(),
      AppConstants.thursday.tr(), AppConstants.friday.tr(), AppConstants.saturday.tr(),
      AppConstants.sunday.tr()
    ];
    return days[weekday - 1];
  }
}

class _DayItem extends StatelessWidget {
  final int dayNumber;
  final String dayOfWeek;
  final DateTime date;
  final int activitiesCount;
  final bool isCompleted;
  final bool isLast;

  const _DayItem({
    required this.dayNumber,
    required this.dayOfWeek,
    required this.date,
    required this.activitiesCount,
    required this.isCompleted,
    required this.isLast,
  });

  String _formatDate() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.primary
                      : (isDark ? AppColors.grey800 : AppColors.grey200),
                  border: Border.all(
                    color: isCompleted ? AppColors.primary : AppColors.grey100,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.grey800 : AppColors.grey300,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 16),

          // Day info
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppConstants.dayLabel.tr()} $dayNumber',
                          style: TextStyle(
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dayOfWeek, ${_formatDate()}',
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activitiesCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$activitiesCount',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
