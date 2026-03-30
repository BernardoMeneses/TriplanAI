import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:triplan_ai_front/shared/widgets/destination_search_modal.dart';
import '../../common/app_colors.dart';
import '../../common/constants/app_constants.dart';
import '../../services/itinerary_items_service.dart';
import '../../services/trips_service.dart';
import '../../services/favorites_service.dart';
import '../../services/trip_cache_service.dart';
import '../../services/connectivity_service.dart';
import '../../shared/widgets/location_filtered_search_modal.dart';
import '../../shared/widgets/ai_chat_modal.dart';
import '../../shared/widgets/upgrade_dialog.dart';
import '../../shared/widgets/snackbar_helper.dart';
import '../../services/subscription_service.dart';
import '../../services/geocoding_service.dart';
import '../notes/notes_page.dart';
import 'trip_map_page.dart';
import 'navigation_page.dart';
import '../../services/real_time_service.dart';

class DayDetailsPage extends StatefulWidget {
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final String tripTitle;
  final String? tripCity;
  final String? tripCountry;
  final bool isReadOnly;

  const DayDetailsPage({
    super.key,
    required this.tripId,
    required this.dayNumber,
    required this.date,
    required this.tripTitle,
    this.tripCity,
    this.tripCountry,
    this.isReadOnly = false,
  });

  @override
  State<DayDetailsPage> createState() => _DayDetailsPageState();
}

class _DayDetailsPageState extends State<DayDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ItineraryItemsService _itemsService = ItineraryItemsService();
  final TripCacheService _cacheService = TripCacheService();
  final TripsService _tripsService = TripsService();
  final FavoritesService _favoritesService = FavoritesService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final GeocodingService _geocodingService = GeocodingService();

  double? _destinationLat;
  double? _destinationLng;
  bool _isGeocoding = false;
  String? _destinationCountry;

  List<ItineraryItem> _items = [];
  bool _isLoading = true;
  String? _itineraryId;
  int _totalDays = 7;
  DateTime? _startDate;
  int _currentDayNumber = 1;
  bool _isReordering = false;

  // Connectivity state
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySubscription;
  // Assinatura para atualizações em tempo real
  StreamSubscription<dynamic>? _realtimeSubscription;

  /// ReadOnly efetivo - true se offline OU se widget.isReadOnly
  bool get _effectiveReadOnly => widget.isReadOnly || !_isOnline;

  @override
  void initState() {
    super.initState();
    _currentDayNumber = widget.dayNumber;
    // Iniciar verificação de conectividade
    _isOnline = _connectivityService.isOnline;
    _connectivitySubscription = _connectivityService.connectivityStream.listen((
      isOnline,
    ) {
      if (mounted && _isOnline != isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
    _loadTripData();
    _geocodeDestination();
    // Atualização em tempo real para não-owners usando WebSocket
    if (widget.isReadOnly) {
      _realtimeSubscription = RealTimeService().subscribeToItinerary(
        widget.tripId,
        _currentDayNumber,
        () {
          if (mounted) _loadItems(forceRefresh: true);
        },
      );
    }
  }

  Future<void> _geocodeDestination() async {
    // If already have coords, skip
    if (_destinationLat != null && _destinationLng != null) return;

    final city = widget.tripCity?.trim() ?? '';
    final country = widget.tripCountry?.trim() ?? '';
    final addressParts = <String>[];
    if (city.isNotEmpty) addressParts.add(city);
    if (country.isNotEmpty) addressParts.add(country);
    final address = addressParts.join(', ');
    if (address.isEmpty) return;

    try {
      setState(() => _isGeocoding = true);
      final res = await _geocodingService.geocodeAddress(address);
      if (res != null) {
        final lat = (res['lat'] as num?)?.toDouble();
        final lng = (res['lng'] as num?)?.toDouble();
        String? countryFromResponse;
        try {
          final comps = res['components'];
          if (comps is Map && comps['country'] != null) {
            countryFromResponse = comps['country'] as String;
          }
        } catch (_) {}
        if (countryFromResponse == null) {
          final formatted = res['formattedAddress'] as String?;
          if (formatted != null) {
            final parts = formatted.split(',').map((s) => s.trim()).toList();
            if (parts.isNotEmpty) countryFromResponse = parts.last;
          }
        }

        setState(() {
          _destinationLat = lat;
          _destinationLng = lng;
          if (countryFromResponse != null &&
              countryFromResponse.trim().isNotEmpty) {
            _destinationCountry = countryFromResponse;
          }
        });
      }
    } catch (e) {
      print('Error geocoding destination: $e');
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _loadTripData() async {
    try {
      final trip = await _tripsService.getTripById(widget.tripId);
      _totalDays = trip.durationInDays;
      _startDate = trip.startDate;

      if (mounted) {
        setState(() {
          _tabController = TabController(
            length: _totalDays,
            vsync: this,
            initialIndex: widget.dayNumber - 1,
          );
          _tabController.addListener(_onTabChanged);
        });
        _loadItems(forceRefresh: true);
      }
    } catch (e) {
      print('Error loading trip data: $e');
      // Fallback: usar 7 dias se falhar
      if (mounted) {
        setState(() {
          _totalDays = 7;
          _startDate = widget.date;
          _tabController = TabController(
            length: 7,
            vsync: this,
            initialIndex: widget.dayNumber - 1,
          );
          _tabController.addListener(_onTabChanged);
        });
        _loadItems(forceRefresh: true);
      }
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      final newDayNumber = _tabController.index + 1;
      if (newDayNumber != _currentDayNumber) {
        setState(() {
          _currentDayNumber = newDayNumber;
        });
        _loadItems(forceRefresh: true);
      }
    }
  }

  Future<void> _loadItems({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      // Buscar ou criar o itinerary correto para este dia (com cache)
      final itinerary = await _cacheService.getOrCreateItineraryByDay(
        widget.tripId,
        _currentDayNumber,
      );

      if (itinerary == null) {
        if (mounted) {
          setState(() {
            _items = [];
            _isLoading = false;
          });
        }
        return;
      }

      _itineraryId = itinerary.id;

      final items = await _cacheService.getItemsByItinerary(
        _itineraryId!,
        forceRefresh: forceRefresh,
      );

      print(
        '📥 Loaded ${items.length} items (offline: ${_cacheService.isOfflineMode}, forceRefresh: $forceRefresh):',
      );
      for (int i = 0; i < items.length; i++) {
        print(
          '  Item $i: ${items[i].title} - startTime: ${items[i].startTime}',
        );
      }

      // Skip reorder check if offline - can't write to backend
      if (_cacheService.isOfflineMode) {
        if (mounted) {
          setState(() {
            _items = items;
            _isLoading = false;
          });
        }
        return;
      }

      // Verify order_index consistency and fix if needed (online only)
      bool needsReorder = false;
      for (int i = 0; i < items.length; i++) {
        if (items[i].orderIndex != i) {
          print(
            '⚠️ Order index mismatch: Item "${items[i].title}" has order_index ${items[i].orderIndex} but should be $i',
          );
          needsReorder = true;
        }
      }

      if (needsReorder) {
        print('🔧 Fixing order indices...');
        final itemIds = items.map((item) => item.id).toList();
        try {
          // Optimistic update
          setState(() {
            _items = items;
          });

          await _itemsService.reorderItems(_itineraryId!, itemIds);

          // Fetch updated items from backend
          final freshItems = await _itemsService.getItemsByItinerary(
            _itineraryId!,
          );
          if (mounted) {
            setState(() {
              _items = freshItems;
              _isLoading = false;
            });
          }
        } catch (e) {
          print('Error reordering items: $e');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _items = items;
            _isLoading = false;
          });
          print('✅ State updated with ${items.length} items');
        }
      }
    } catch (e) {
      print('Error loading items: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addPlace() async {
    // Check activity limit per day
    final subStatus = await SubscriptionService().getStatus();
    if (!subStatus.limits.isUnlimitedActivities &&
        _items.length >= subStatus.limits.maxActivitiesPerDay) {
      if (mounted) {
        showUpgradeDialog(
          context: context,
          feature: AppConstants.activityLimitTitle.tr(),
          description: AppConstants.activityLimitDesc.tr(),
        );
      }
      return;
    }

    final result = await showModalBottomSheet<DestinationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationFilteredSearchModal(
        cityFilter: widget.tripCity,
        countryFilter: widget.tripCountry ?? _destinationCountry,
        dayNumber: widget.dayNumber,
        centerLat: _destinationLat,
        centerLng: _destinationLng,
      ),
    );

    if (result != null && _itineraryId != null) {
      try {
        // Calculate start time based on previous items
        String startTime = '09:00:00'; // Default start time
        if (_items.isNotEmpty) {
          final lastItem = _items.last;
          startTime = _calculateNextStartTime(lastItem);
        }

        // Optimistic update
        final newItem = ItineraryItem(
          id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          title: result.title,
          description: result.subtitle,
          orderIndex: _items.length,
          startTime: startTime,
          durationMinutes: 60,
          itemType: 'activity',
          itineraryId: _itineraryId!,
          status: 'planned',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        setState(() {
          _items.add(newItem);
        });

        // Criar novo itinerary item com o lugar selecionado
        await _itemsService.createItem(
          itineraryId: _itineraryId!,
          googlePlaceId: result.placeId,
          orderIndex: _items.length - 1,
          title: result.title,
          description: result.subtitle,
          itemType: 'activity',
          durationMinutes: 60, // Duração padrão de 1 hora
          startTime: startTime,
        );

        // Recarregar lista para obter os dados de distância/transporte calculados pelo backend
        await _loadItems(forceRefresh: true);
        if (mounted) {
          setState(() {}); // Ensure UI refresh
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    AppConstants.addedToDay.tr(
                      args: [widget.dayNumber.toString()],
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        print('Error adding place: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppConstants.errorAddingLocation.tr(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _reorderItems(List<ItineraryItem> items) async {
    // Skip reorder check if offline - can't write to backend
    if (_cacheService.isOfflineMode) {
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
      return;
    }

    // Verify order_index consistency and fix if needed (online only)
    bool needsReorder = false;
    for (int i = 0; i < items.length; i++) {
      if (items[i].orderIndex != i) {
        print(
          '⚠️ Order index mismatch: Item "${items[i].title}" has order_index ${items[i].orderIndex} but should be $i',
        );
        needsReorder = true;
      }
    }

    if (needsReorder) {
      print('🔧 Fixing order indices...');
      final itemIds = items.map((item) => item.id).toList();
      try {
        // Optimistic update
        setState(() {
          _items = items;
        });

        await _itemsService.reorderItems(_itineraryId!, itemIds);

        // Fetch updated items from backend
        final freshItems = await _itemsService.getItemsByItinerary(
          _itineraryId!,
        );
        if (mounted) {
          setState(() {
            _items = freshItems;
          });
        }
      } catch (e) {
        print('Error reordering items: $e');
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _realtimeSubscription?.cancel();
    RealTimeService().dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final months = [
      '${AppConstants.jan.tr()}',
      '${AppConstants.feb.tr()}',
      '${AppConstants.mar.tr()}',
      '${AppConstants.apr.tr()}',
      '${AppConstants.may.tr()}',
      '${AppConstants.jun.tr()}',
      '${AppConstants.jul.tr()}',
      '${AppConstants.aug.tr()}',
      '${AppConstants.sep.tr()}',
      '${AppConstants.oct.tr()}',
      '${AppConstants.nov.tr()}',
      '${AppConstants.dec.tr()}',
    ];
    final days = [
      '${AppConstants.monday.tr()}',
      '${AppConstants.tuesday.tr()}',
      '${AppConstants.wednesday.tr()}',
      '${AppConstants.thursday.tr()}',
      '${AppConstants.friday.tr()}',
      '${AppConstants.saturday.tr()}',
      '${AppConstants.sunday.tr()}',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  String _getDayOfWeek(DateTime date) {
    final days = [
      '${AppConstants.monday.tr()}',
      '${AppConstants.tuesday.tr()}',
      '${AppConstants.wednesday.tr()}',
      '${AppConstants.thursday.tr()}',
      '${AppConstants.friday.tr()}',
      '${AppConstants.saturday.tr()}',
      '${AppConstants.sunday.tr()}',
    ];
    return days[date.weekday - 1];
  }

  String _formatDuration(int? minutes) {
    if (minutes == null || minutes == 0) return '';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '$hours h $mins min';
    } else if (hours > 0) {
      return '$hours h';
    } else {
      return '$mins min';
    }
  }

  // Funcionalidade de verificação de horários de encerramento removida
  // pois o sistema terá integração direta com Google Maps

  /// Gerar e compartilhar itinerário em PDF
  Future<void> _downloadItinerary() async {
    // Check PDF export permission
    final subStatus = await SubscriptionService().getStatus();
    if (!subStatus.limits.canExportPdf) {
      if (mounted) {
        showUpgradeDialog(
          context: context,
          feature: AppConstants.pdfLockedTitle.tr(),
          description: AppConstants.pdfLockedDesc.tr(),
        );
      }
      return;
    }

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      final pdf = pw.Document();
      final tripTitle =
          widget.tripCity ?? widget.tripCountry ?? widget.tripTitle;
      final dayTitle = '${'common.day'.tr()} ${_currentDayNumber}';

      // Criar página do PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              margin: const pw.EdgeInsets.only(bottom: 24),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#7ED9C8'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    tripTitle,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    dayTitle,
                    style: pw.TextStyle(fontSize: 18, color: PdfColors.white),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    DateFormat('EEEE, d MMMM yyyy').format(widget.date),
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 12),
              margin: const pw.EdgeInsets.only(top: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'trip_details.pdf.generated_by'.tr(),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    '${context.pageNumber}/${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return _items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColor.fromHex('#E0E0E0'),
                    width: 1,
                  ),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Badge de transporte desde o ponto anterior (se não for o primeiro)
                    if (index > 0 &&
                        item.travelTimeFromPreviousText != null) ...[
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        margin: const pw.EdgeInsets.only(bottom: 12),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#E8F5E9'),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(6),
                          ),
                          border: pw.Border.all(
                            color: PdfColor.fromHex('#4CAF50'),
                            width: 1,
                          ),
                        ),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              '→ ${_getTransportLabel(item.transportMode)} - ${item.travelTimeFromPreviousText}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromHex('#2E7D32'),
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            if (item.distanceFromPreviousText != null) ...[
                              pw.Text(
                                ' (${item.distanceFromPreviousText})',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  color: PdfColor.fromHex('#2E7D32'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    // Número e título
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 32,
                          height: 32,
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#7ED9C8'),
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              '${index + 1}',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.title,
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (item.place?.address != null) ...[
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  item.place!.address!,
                                  style: const pw.TextStyle(
                                    fontSize: 12,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    // Detalhes (horário, duração)
                    pw.Row(
                      children: [
                        if (item.startTime != null) ...[
                          pw.Text(
                            '⏰ ${item.startTime!.substring(0, 5)}',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey800,
                            ),
                          ),
                          pw.SizedBox(width: 16),
                        ],
                        if (item.durationMinutes != null) ...[
                          pw.Text(
                            '⌛ ' + _formatDuration(item.durationMinutes!),
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Descrição (se existir)
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        item.description!,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList();
          },
        ),
      );

      // Fechar loading
      Navigator.pop(context);

      // Compartilhar PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            '${'trip_details.pdf.filename_itinerary'.tr()}_${tripTitle.replaceAll(' ', '_')}_${'trip_details.pdf.filename_day'.tr()}${_currentDayNumber}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('trip_details.pdf.itinerary_exported'.tr()),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Fechar loading se estiver aberto
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('Erro ao gerar PDF: $e');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          '${'trip_details.pdf.error_generating_pdf'.tr()}: $e',
        );
      }
    }
  }

  String _getTransportLabel(String? mode) {
    switch (mode) {
      case 'walking':
        return 'trip_details.transport.walking'.tr();
      case 'driving':
        return 'trip_details.transport.driving'.tr();
      case 'transit':
        return 'trip_details.transport.transit'.tr();
      case 'bicycling':
        return 'trip_details.transport.bicycling'.tr();
      default:
        return 'trip_details.transport.walking'.tr();
    }
  }

  /// Calcula o próximo horário de início baseado no item anterior
  String _calculateNextStartTime(ItineraryItem previousItem) {
    try {
      // Parse do startTime do item anterior (formato HH:MM:SS ou HH:MM)
      final startTimeParts = previousItem.startTime?.split(':') ?? [];
      if (startTimeParts.isEmpty) return '09:00:00';

      final hours = int.parse(startTimeParts[0]);
      final minutes = int.parse(startTimeParts[1]);

      // Criar DateTime com horário do item anterior
      var nextTime = DateTime(2024, 1, 1, hours, minutes);

      // Adicionar APENAS a duração do item anterior (padrão 60 minutos)
      // O tempo de viagem é calculado automaticamente pelo backend
      final durationMinutes = previousItem.durationMinutes ?? 60;
      nextTime = nextTime.add(Duration(minutes: durationMinutes));

      // Formatar como HH:MM:SS
      return '${nextTime.hour.toString().padLeft(2, '0')}:${nextTime.minute.toString().padLeft(2, '0')}:00';
    } catch (e) {
      print('Error calculating next start time: $e');
      return '09:00:00';
    }
  }

  /// Recalcula todos os horários dos itens após uma edição
  Future<void> _recalculateAllTimes() async {
    if (_items.isEmpty || _itineraryId == null) return;

    try {
      for (int i = 1; i < _items.length; i++) {
        final previousItem = _items[i - 1];
        final currentItem = _items[i];

        final newStartTime = _calculateNextStartTime(previousItem);

        // Atualizar apenas se o horário mudou
        if (currentItem.startTime != newStartTime) {
          await _itemsService.updateItem(
            currentItem.id,
            startTime: newStartTime,
          );
        }
      }

      // Recarregar lista após recalcular
      await _loadItems(forceRefresh: true);
    } catch (e) {
      print('Error recalculating times: $e');
    }
  }

  /// Editar horário de início e duração de um item
  Future<void> _editItemTime(ItineraryItem item, int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TimeEditDialog(
        item: item,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );

    if (result != null && _itineraryId != null) {
      try {
        print('📝 Updating item ${item.id} (index: $index):');
        print('  - New startTime: ${result['startTime']}');
        print('  - New durationMinutes: ${result['durationMinutes']}');

        // Atualizar o item - o backend recalculará automaticamente os horários dos próximos itens
        await _itemsService.updateItem(
          item.id,
          startTime: result['startTime'],
          durationMinutes: result['durationMinutes'],
        );

        // Recarregar lista para obter os novos horários calculados
        await _loadItems(forceRefresh: true);

        if (mounted) {
          setState(() {}); // Ensure UI refresh
          SnackBarHelper.showSuccess(
            context,
            AppConstants.timeUpdatedSuccess.tr(),
          );
        }
      } catch (e) {
        print('❌ Error updating time: $e');
        if (mounted) {
          SnackBarHelper.showError(
            context,
            '${AppConstants.errorUpdatingTime.tr()}: $e',
          );
        }
      }
    }
  }

  Future<void> _editItemTransport(ItineraryItem item, int index) async {
    if (item.isStartingPoint) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _EditTransportDialog(
        item: item,
        currentTransportMode: item.transportMode ?? 'walking',
        currentTravelTime: item.travelTimeFromPreviousText,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );

    if (result != null && _itineraryId != null) {
      try {
        // 🔥 Atualização otimista local
        setState(() {
          _items[index] = _items[index].copyWith(
            transportMode: result['transportMode'],
          );
        });

        await _itemsService.updateItem(
          item.id,
          transportMode: result['transportMode'],
        );

        await _itemsService.recalculateDistances(_itineraryId!);

        // 🔥 Buscar dados reais do backend
        final freshItems = await _itemsService.getItemsByItinerary(
          _itineraryId!,
        );

        await _cacheService.cacheItineraryItems(_itineraryId!, freshItems);

        if (mounted) {
          setState(() {
            _items = freshItems;
          });
        }

        SnackBarHelper.showSuccess(
          context,
          AppConstants.transportUpdatedSuccess.tr(),
        );
      } catch (e) {
        SnackBarHelper.showError(
          context,
          '${AppConstants.errorUpdatingTransport.tr()}: $e',
        );
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await _itemsService.deleteItem(itemId);
      await _loadItems(forceRefresh: true);
      if (mounted) {
        setState(() {}); // Ensure UI refresh
        SnackBarHelper.showSuccess(
          context,
          AppConstants.placeRemovedSuccess.tr(),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          '${AppConstants.errorRemovingPlace.tr()}: $e',
        );
      }
    }
  }

  Future<void> _moveItemToDay(String itemId, int targetDay) async {
    if (targetDay == _currentDayNumber) return;

    try {
      // Get target day's itinerary
      final targetItinerary = await _itemsService.getOrCreateItineraryByDay(
        widget.tripId,
        targetDay,
      );

      // Move item
      await _itemsService.moveItemToDay(itemId, targetItinerary.id);

      // Recalculate distances for both days
      if (_itineraryId != null) {
        await _itemsService.recalculateDistances(_itineraryId!);
      }
      await _itemsService.recalculateDistances(targetItinerary.id);

      // Reload items
      await _loadItems(forceRefresh: true);

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          AppConstants.placeMovedToDay.tr(args: [targetDay.toString()]),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          '${AppConstants.errorMovingPlace.tr()}: $e',
        );
      }
    }
  }

  Future<void> _reorderItem(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex || _itineraryId == null) return;

    setState(() => _isReordering = true);

    try {
      // Reorder in local list
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);

      // Get item IDs in new order
      final itemIds = _items.map((item) => item.id).toList();

      // Send to backend
      await _itemsService.reorderItems(_itineraryId!, itemIds);

      // Recalculate distances
      await _itemsService.recalculateDistances(_itineraryId!);

      // Reload to get updated distances
      await _loadItems(forceRefresh: true);
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          '${AppConstants.errorReordering.tr()}: $e',
        );
      }
    } finally {
      setState(() => _isReordering = false);
    }
  }

  Future<int?> _showMoveToDayDialog(ItineraryItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: Text(
          'Move "${item.title}"',
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose the day to move this place to:',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(_totalDays, (index) {
                    final dayNumber = index + 1;
                    if (dayNumber == _currentDayNumber) {
                      return const SizedBox.shrink(); // Don't show current day
                    }

                    final dayDate = _startDate?.add(Duration(days: index));
                    final dateStr = dayDate != null
                        ? DateFormat('MMM d').format(dayDate)
                        : '';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$dayNumber',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        '${AppConstants.day.tr()} $dayNumber',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: dateStr.isNotEmpty
                          ? Text(
                              dateStr,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            )
                          : null,
                      onTap: () => Navigator.pop(context, dayNumber),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('${AppConstants.cancel.tr()}'),
          ),
        ],
      ),
    );
  }

  void _showAddToFavoritesSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final placesWithInfo = _items
        .where((item) => item.place?.id != null)
        .toList();

    if (placesWithInfo.isEmpty) {
      SnackBarHelper.showWarning(context, AppConstants.noPlacesToFavorite.tr());
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.bookmark_border, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    AppConstants.addToFavorites.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: placesWithInfo.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = placesWithInfo[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.place?.images?.isNotEmpty ?? false
                          ? CachedNetworkImage(
                              imageUrl: item.place!.images!.first,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 50,
                                height: 50,
                                color: AppColors.primary.withOpacity(0.1),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: AppColors.primary.withOpacity(0.1),
                                child: Icon(
                                  Icons.place,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: AppColors.primary.withOpacity(0.1),
                              child: Icon(
                                Icons.place,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    subtitle: item.place?.address != null
                        ? Text(
                            item.place!.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          )
                        : null,
                    trailing: IconButton(
                      icon: Icon(Icons.bookmark_add, color: AppColors.primary),
                      onPressed: () async {
                        final added = await _favoritesService.addFavoriteSafe(
                          item.place!.id,
                        );
                        Navigator.pop(
                          context,
                        ); // Fecha o modal antes do feedback
                        if (!added) {
                          if (mounted) {
                            SnackBarHelper.showWarning(
                              this.context,
                              AppConstants.duplicateFavoriteMessage.tr(),
                            );
                          }
                          return;
                        }
                        if (mounted) {
                          SnackBarHelper.showSuccess(
                            this.context,
                            AppConstants.addedToFavorites.tr(),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(ItineraryItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppConstants.removePlace.tr()),
          content: Text(AppConstants.deleteTripMessage.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppConstants.cancel.tr()),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteItem(item.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(AppConstants.remove.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.tripCity != null && widget.tripCity!.isNotEmpty
              ? widget.tripCity!
              : widget.tripCountry ?? widget.tripTitle,
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Notes button
          IconButton(
            icon: Icon(
              Icons.edit_note_sharp,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotesPage(tripId: widget.tripId),
                ),
              );
            },
            tooltip: AppConstants.notesTitle.tr(),
          ),
          // Map button - only when online
          if (_isOnline)
            IconButton(
              icon: Icon(
                Icons.map,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              onPressed: (_isGeocoding && _items.isEmpty)
                  ? null
                  : () async {
                      // Ensure we have destination coords when there are no items
                      if (_items.isEmpty &&
                          (_destinationLat == null ||
                              _destinationLng == null)) {
                        await _geocodeDestination();
                      }

                      final wasUpdated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripMapPage(
                            tripId: widget.tripId,
                            dayNumber: _currentDayNumber,
                            activities: _items,
                            destinationLat: _destinationLat,
                            destinationLng: _destinationLng,
                          ),
                        ),
                      );

                      // If transport mode was updated in the map, refresh the list
                      if (wasUpdated == true) {
                        _loadItems(forceRefresh: true);
                      }
                    },
            ),
          // Favorites button - only when online
          if (_isOnline)
            IconButton(
              icon: Icon(
                Icons.bookmark_border,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              onPressed: _showAddToFavoritesSheet,
            ),
        ],
      ),
      floatingActionButton: _effectiveReadOnly
          ? null
          : FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AIChatModal(
                    cityFilter: widget.tripCity,
                    countryFilter: widget.tripCountry,
                    dayNumber: _currentDayNumber,
                    itineraryId: _itineraryId,
                    tripId: widget.tripId,
                    onPlaceAdded: (placeId, name, description) async {
                      if (_itineraryId != null) {
                        // Check activity limit per day
                        final subStatus = await SubscriptionService()
                            .getStatus();
                        if (!subStatus.limits.isUnlimitedActivities &&
                            _items.length >=
                                subStatus.limits.maxActivitiesPerDay) {
                          if (mounted) {
                            Navigator.pop(context); // Close AI modal
                            showUpgradeDialog(
                              context: context,
                              feature: AppConstants.activityLimitTitle.tr(),
                              description: AppConstants.activityLimitDesc.tr(),
                            );
                          }
                          return;
                        }
                        try {
                          // O backend calculará automaticamente o start_time baseado nos itens anteriores
                          await _itemsService.createItem(
                            itineraryId: _itineraryId!,
                            googlePlaceId: placeId,
                            orderIndex: _items.length,
                            title: name,
                            description: description,
                            itemType: 'activity',
                            durationMinutes: 60, // Duração padrão de 1 hora
                          );
                          await _loadItems(forceRefresh: true);

                          if (mounted) {
                            Navigator.pop(context); // Close AI modal
                            SnackBarHelper.showSuccess(
                              context,
                              AppConstants.addedToDay.tr(
                                args: [_currentDayNumber.toString()],
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error adding place from AI: $e');
                          if (mounted) {
                            Navigator.pop(context); // Close AI modal
                            SnackBarHelper.showError(
                              context,
                              AppConstants.errorAddingLocation.tr(),
                            );
                          }
                        }
                      }
                    },
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person, color: Colors.white),
            ),
      body: Column(
        children: [
          // Tabs dos dias
          if (_startDate != null)
            Container(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.primary,
                labelColor: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                unselectedLabelColor: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                indicatorPadding: EdgeInsets.zero,
                tabs: List.generate(_totalDays, (index) {
                  final date = _startDate!.add(Duration(days: index));
                  final isSelected = index == _tabController.index;
                  return Tab(
                    height: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getDayOfWeek(date),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.day}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

          // Lista de atividades
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 64,
                            color: isDark
                                ? AppColors.grey800
                                : Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppConstants.noActivitiesYet.tr(),
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const SizedBox(height: 24),
                          if (!_effectiveReadOnly)
                            ElevatedButton.icon(
                              onPressed: _addPlace,
                              icon: const Icon(Icons.add),
                              label: Text(AppConstants.addActivity.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _effectiveReadOnly
                        ? _items.length
                        : _items.length + 1,
                    buildDefaultDragHandles: false,
                    onReorder: _effectiveReadOnly
                        ? (_, __) {}
                        : (oldIndex, newIndex) {
                            if (oldIndex < _items.length &&
                                newIndex <= _items.length) {
                              // Adjust newIndex if moving down
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              _reorderItem(oldIndex, newIndex);
                            }
                          },
                    itemBuilder: (context, index) {
                      if (!_effectiveReadOnly && index == _items.length) {
                        // Botão para adicionar mais atividades
                        return Padding(
                          key: const ValueKey('add_button'),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: OutlinedButton.icon(
                            onPressed: _addPlace,
                            icon: const Icon(Icons.add),
                            label: Text(AppConstants.addAnotherActivity.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        );
                      }

                      final item = _items[index];
                      final isFirstItem = index == 0;

                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: _effectiveReadOnly
                            ? DismissDirection.none
                            : DismissDirection.horizontal,
                        confirmDismiss: _effectiveReadOnly
                            ? null
                            : (direction) async {
                                // Show dialog to choose target day
                                final targetDay = await _showMoveToDayDialog(
                                  item,
                                );
                                if (targetDay != null) {
                                  await _moveItemToDay(item.id, targetDay);
                                }
                                return false; // Don't actually dismiss, just trigger the action
                              },
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_back, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                '${AppConstants.moveToAnotherDay.tr()}',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${AppConstants.moveToAnotherDay.tr()}',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                        child: ReorderableDelayedDragStartListener(
                          index: index,
                          enabled: !_effectiveReadOnly,
                          child: _ActivityCard(
                            number: index + 1,
                            title: item.title,
                            subtitle: item.description ?? '',
                            imageUrl: item.place?.images?.firstOrNull ?? '',
                            time: item.startTime ?? '',
                            duration: _formatDuration(item.durationMinutes),
                            durationMinutes: item.durationMinutes ?? 60,
                            openingHours: item.place?.openingHours
                                ?.getTodayHours(),
                            rating: item.place?.rating,
                            placeType: item.place?.placeType,
                            latitude: item.place?.latitude,
                            longitude: item.place?.longitude,
                            isFirstItem: isFirstItem,
                            isDark: isDark,
                            // New distance fields from backend
                            isStartingPoint: item.isStartingPoint,
                            distanceFromPreviousText:
                                item.distanceFromPreviousText,
                            travelTimeFromPreviousText:
                                item.travelTimeFromPreviousText,
                            transportMode: item.transportMode,
                            allItems: _items,
                            itemIndex: index,
                            isReadOnly: _effectiveReadOnly,
                            onTimeEdit: _effectiveReadOnly
                                ? null
                                : () => _editItemTime(item, index),
                            onTransportEdit: _effectiveReadOnly
                                ? null
                                : () => _editItemTransport(item, index),
                            onRefresh: () => _loadItems(forceRefresh: true),
                            onDelete: _effectiveReadOnly
                                ? null
                                : () => _showDeleteConfirmation(item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatefulWidget {
  final int number;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String time;
  final String duration;
  final int durationMinutes;
  final String? openingHours;
  final double? rating;
  final String? placeType;
  final double? latitude;
  final double? longitude;
  final bool isFirstItem;
  final bool isDark;
  final bool isStartingPoint;
  final String? distanceFromPreviousText;
  final String? travelTimeFromPreviousText;
  final String? transportMode; // walking, driving, transit
  final List<ItineraryItem> allItems;
  final int itemIndex;
  final bool isReadOnly;
  final VoidCallback? onDelete;
  final VoidCallback? onTimeEdit;
  final VoidCallback? onTransportEdit;
  final VoidCallback? onRefresh;

  const _ActivityCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.time,
    required this.duration,
    required this.durationMinutes,
    this.openingHours,
    this.rating,
    this.placeType,
    this.latitude,
    this.longitude,
    this.isFirstItem = false,
    required this.isDark,
    this.isStartingPoint = false,
    this.distanceFromPreviousText,
    this.travelTimeFromPreviousText,
    this.transportMode,
    required this.allItems,
    required this.itemIndex,
    this.isReadOnly = false,
    this.onDelete,
    this.onTimeEdit,
    this.onTransportEdit,
    this.onRefresh,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  @override
  void initState() {
    super.initState();
  }

  String _getOpeningHoursText(String? openingHours) {
    if (openingHours == null) return '';
    // Corrigir "Aberto 24 horas" hardcoded para tradução
    if (openingHours.trim().toLowerCase() == 'aberto 24 horas' ||
        openingHours.trim().toLowerCase() == 'open 24 hours') {
      return 'trip_details.open_24_hours'.tr();
    }
    return openingHours;
  }

  IconData _getPlaceTypeIcon(String? placeType) {
    switch (placeType) {
      case 'museum':
        return Icons.museum;
      case 'restaurant':
        return Icons.restaurant;
      case 'park':
        return Icons.park;
      case 'hotel':
        return Icons.hotel;
      case 'shopping':
        return Icons.shopping_bag;
      case 'attraction':
      default:
        return Icons.place;
    }
  }

  IconData _getTransportIcon(String? transportMode) {
    switch (transportMode) {
      case 'walking':
        return Icons.directions_walk;
      case 'driving':
        return Icons.directions_car;
      case 'transit':
        return Icons.directions_transit;
      case 'bicycling':
        return Icons.directions_bike;
      default:
        return Icons.directions_walk; // Default to walking
    }
  }

  void _openNavigationPage() async {
    if (widget.latitude == null || widget.longitude == null) return;

    // Get current item ID from allItems
    final currentItem = widget.allItems[widget.itemIndex];

    // Get previous item if exists
    String? originName;
    double? originLat;
    double? originLng;

    if (widget.itemIndex > 0 && widget.itemIndex <= widget.allItems.length) {
      final previousItem = widget.allItems[widget.itemIndex - 1];
      originName = previousItem.title;
      originLat = previousItem.place?.latitude;
      originLng = previousItem.place?.longitude;
    }

    final updatedTransportMode = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationPage(
          destinationName: widget.title,
          destinationLat: widget.latitude!,
          destinationLng: widget.longitude!,
          originName: originName,
          originLat: originLat,
          originLng: originLng,
          transportMode: widget.transportMode, // Use backend calculated mode
          itineraryItemId:
              currentItem.id, // Pass item ID to save transport changes
        ),
      ),
    );

    // If transport mode was updated, refresh the activity card
    if (updatedTransportMode != null &&
        updatedTransportMode != widget.transportMode) {
      widget.onRefresh?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStart = widget.isStartingPoint;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: widget.isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (widget.latitude != null && widget.longitude != null) {
                // ...existing code for opening details...
              }
            },
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: widget.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 200,
                            color: widget.isDark
                                ? AppColors.grey800
                                : AppColors.grey200,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            color: widget.isDark
                                ? AppColors.grey800
                                : AppColors.grey200,
                            child: const Center(
                              child: Icon(
                                Icons.place,
                                size: 64,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 200,
                          color: widget.isDark
                              ? AppColors.grey800
                              : AppColors.grey200,
                          child: const Center(
                            child: Icon(
                              Icons.place,
                              size: 64,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
                // Overlay: só para não-ponto de partida (garantido)
                if (!isStart)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                // Para ponto de partida, NÃO renderiza overlay preto
                // Bolinhas "infinito" topo esquerdo (mais juntas)
                if (!isStart)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${widget.number}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _getPlaceTypeIcon(widget.placeType),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Botão de apagar canto superior direito (sempre visível se não readOnly)
                if (!widget.isReadOnly)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                // Ponto de partida: bandeira + tipo de place ao lado
                if (isStart)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.flag,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _getPlaceTypeIcon(widget.placeType),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
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
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (widget.time.isNotEmpty) ...[
                            GestureDetector(
                              onTap: widget.onTimeEdit,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.history,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.time.substring(0, 5),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (widget.duration.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: widget.onTimeEdit,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.hourglass_bottom,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.duration,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ...restante do card (ações, horários, etc.)
          if (!isStart)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.travelTimeFromPreviousText != null)
                        GestureDetector(
                          onTap: widget.onTransportEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getTransportIcon(widget.transportMode),
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.travelTimeFromPreviousText!,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (!widget.isReadOnly)
                        GestureDetector(
                          onTap: _openNavigationPage,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions,
                                size: 24,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppConstants.getDirections.tr(),
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (widget.openingHours != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: widget.isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _getOpeningHoursText(widget.openingHours),
                            style: TextStyle(
                              color: widget.isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          // Para ponto de partida, só horários e botão de apagar (já está na imagem)
          if (isStart)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.openingHours != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: widget.isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _getOpeningHoursText(widget.openingHours),
                            style: TextStyle(
                              color: widget.isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 13,
                            ),
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

// Diálogo para editar horário de início e duração
class _TimeEditDialog extends StatefulWidget {
  final ItineraryItem item;
  final bool isDark;

  const _TimeEditDialog({required this.item, required this.isDark});

  @override
  State<_TimeEditDialog> createState() => _TimeEditDialogState();
}

class _TimeEditDialogState extends State<_TimeEditDialog> {
  late TimeOfDay _startTime;
  late int _durationMinutes;

  @override
  void initState() {
    super.initState();

    // Parse do horário atual
    if (widget.item.startTime != null && widget.item.startTime!.isNotEmpty) {
      final parts = widget.item.startTime!.split(':');
      _startTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } else {
      _startTime = const TimeOfDay(hour: 9, minute: 0);
    }

    _durationMinutes = widget.item.durationMinutes ?? 60;
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: widget.isDark
                  ? AppColors.surfaceDark
                  : Colors.white,
              hourMinuteTextColor: widget.isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              dialHandColor: AppColors.primary,
              dialBackgroundColor: widget.isDark
                  ? AppColors.grey800
                  : AppColors.grey200,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  void _changeDuration(int minutes) {
    setState(() {
      _durationMinutes = (_durationMinutes + minutes).clamp(
        15,
        480,
      ); // Min 15min, Max 8h
    });
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '$hours h $mins min';
    } else if (hours > 0) {
      return '$hours h';
    } else {
      return '$mins min';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppConstants.editTime.tr()}',
              style: TextStyle(
                color: widget.isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.title,
              style: TextStyle(
                color: widget.isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Horário de início
            Text(
              '${AppConstants.startTime.tr()}',
              style: TextStyle(
                color: widget.isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickStartTime,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.isDark ? AppColors.grey800 : AppColors.grey200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: widget.isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.edit, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Duração
            Text(
              '${AppConstants.duration.tr()}',
              style: TextStyle(
                color: widget.isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isDark ? AppColors.grey800 : AppColors.grey200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _changeDuration(-15),
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppColors.primary,
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            _formatDuration(_durationMinutes),
                            style: TextStyle(
                              color: widget.isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeDuration(15),
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botões
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '${AppConstants.cancel.tr()}',
                    style: TextStyle(
                      color: widget.isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'startTime':
                          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00',
                      'durationMinutes': _durationMinutes,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text('${AppConstants.save.tr()}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Modal para editar meio de transporte e tempo de viagem
class _EditTransportDialog extends StatefulWidget {
  final ItineraryItem item;
  final String currentTransportMode;
  final String? currentTravelTime;
  final bool isDark;

  const _EditTransportDialog({
    required this.item,
    required this.currentTransportMode,
    this.currentTravelTime,
    required this.isDark,
  });

  @override
  State<_EditTransportDialog> createState() => _EditTransportDialogState();
}

class _EditTransportDialogState extends State<_EditTransportDialog> {
  late String _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.currentTransportMode;
  }

  IconData _getTransportIcon(String mode) {
    switch (mode) {
      case 'walking':
        return Icons.directions_walk;
      case 'driving':
        return Icons.directions_car;
      case 'transit':
        return Icons.directions_transit;
      case 'bicycling':
        return Icons.directions_bike;
      default:
        return Icons.directions_walk;
    }
  }

  String _getTransportLabel(String mode) {
    switch (mode) {
      case 'walking':
        return '${AppConstants.walking.tr()}';
      case 'driving':
        return '${AppConstants.driving.tr()}';
      case 'transit':
        return '${AppConstants.transit.tr()}';
      case 'bicycling':
        return '${AppConstants.bicycling.tr()}';
      default:
        return '${AppConstants.walking.tr()}';
    }
  }

  String _getEstimatedTime(String mode) {
    // Show actual time for current mode, placeholder for others
    if (mode == widget.currentTransportMode &&
        widget.currentTravelTime != null) {
      return widget.currentTravelTime!;
    }
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? AppColors.grey100 : AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  widget.item.title,
                  style: TextStyle(
                    color: widget.isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.currentTravelTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${AppConstants.current.tr()}: ${widget.currentTravelTime}',
                    style: TextStyle(
                      color: widget.isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Transport options in clean list
                ...['driving', 'transit', 'walking', 'bicycling'].map((mode) {
                  final isSelected = mode == _selectedMode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // Save automatically on tap
                          Navigator.pop(context, {'transportMode': mode});
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (widget.isDark
                                      ? AppColors.primary.withOpacity(0.2)
                                      : const Color(0xFFE8F5E9))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getTransportIcon(mode),
                                size: 22,
                                color: isSelected
                                    ? AppColors.primary
                                    : (widget.isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _getTransportLabel(mode),
                                style: TextStyle(
                                  color: widget.isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _getEstimatedTime(mode),
                                style: TextStyle(
                                  color: widget.isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
