import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:triplan_ai_front/services/auth_service.dart';
import '../widgets/empty_trips_state.dart';
import '../../../common/app_colors.dart';
import '../../../common/constants/app_constants.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../common/app_events.dart';
import '../../../services/trips_service.dart';
import '../../../services/subscription_service.dart';
import '../../../services/trip_cache_service.dart';
import '../../../services/new_trip_draft_service.dart';
import '../../../services/destinations_service.dart';
import '../../profile/pages/profile_page.dart';
import '../../trip_details/my_trip_page.dart';
import '../../trip_details/import_trip_page.dart';
import '../../../shared/widgets/feature_locked_dialog.dart';

class TravelingPage extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onOpenNewTripTab;

  const TravelingPage({super.key, this.onLogout, this.onOpenNewTripTab});

  @override
  State<TravelingPage> createState() => _TravelingPageState();
}

class _TravelingPageState extends State<TravelingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TripCacheService _tripCacheService = TripCacheService();
  final NewTripDraftService _newTripDraftService = NewTripDraftService();
  final DestinationsService _destinationsService = DestinationsService();

  List<Trip> _upcomingTrips = [];
  List<Trip> _pastTrips = [];
  NewTripDraft? _newTripDraft;
  bool _isLoading = true;
  bool _isOfflineMode = false;
  final Map<String, String?> _tripImages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrips();
    _loadDraft();
    // Subscribe to global trip changes to refresh lists
    AppEvents.onTripsChanged.listen((_) {
      if (mounted) _loadTrips();
    });
    AppEvents.onTripImported.listen((_) {
      if (mounted) _loadTrips();
    });
    AppEvents.onDraftChanged.listen((_) {
      if (mounted) _loadDraft();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);

    try {
      final trips = await _tripCacheService.getTrips();
      final now = DateTime.now();

      if (mounted) {
        setState(() {
          _isOfflineMode = _tripCacheService.isOfflineMode;
          _upcomingTrips =
              trips.where((trip) => trip.endDate.isAfter(now)).toList()
                ..sort((a, b) => a.startDate.compareTo(b.startDate));
          _pastTrips =
              trips
                  .where(
                    (trip) =>
                        trip.endDate.isBefore(now) ||
                        trip.endDate.isAtSameMomentAs(now),
                  )
                  .toList()
                ..sort((a, b) => b.endDate.compareTo(a.endDate));
          _isLoading = false;
        });

        // Mostrar aviso se offline
        if (_isOfflineMode && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cloud_off, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('offline.viewing_cached'.tr())),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // Carregar imagens (do cache primeiro, depois online)
        for (final trip in [..._upcomingTrips, ..._pastTrips]) {
          _loadTripImage(trip);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDraft() async {
    final draft = await _newTripDraftService.getDraft();
    if (!mounted) return;

    setState(() {
      _newTripDraft = draft;
    });
  }

  Future<void> _loadTripImage(Trip trip) async {
    // Primeiro tentar carregar do cache
    final cachedImage = await _tripCacheService.getCachedTripImage(trip.id);
    if (cachedImage != null && mounted) {
      setState(() {
        _tripImages[trip.id] = cachedImage;
      });
      return;
    }

    // Se offline, não tentar buscar online
    if (_isOfflineMode) return;

    try {
      final query = '${trip.destinationCity}, ${trip.destinationCountry}';
      final searchResults = await _destinationsService.searchDestinations(
        query,
      );

      if (searchResults.isNotEmpty && mounted) {
        final details = await _destinationsService.getDestinationDetails(
          searchResults.first.placeId,
        );

        if (mounted && details?.photoUrl != null) {
          // Guardar em cache
          await _tripCacheService.cacheTripImage(trip.id, details!.photoUrl!);
          setState(() {
            _tripImages[trip.id] = details.photoUrl;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar imagem: $e');
    }
  }

  void _openTripDetails(Trip trip) {
    final currentUser = AuthService().currentUser;
    final bool isOwner = currentUser != null && trip.userId == currentUser.id;
    final bool isReadOnly = !isOwner || _isOfflineMode || trip.isMember;
    debugPrint(
      'DEBUG [travelling_page] trip.userId: [36m[1m[4m[7m${trip.userId}[0m | currentUser.id: [33m[1m[4m[7m${currentUser?.id}[0m | trip.isMember: [35m${trip.isMember}[0m | isOwner: [32m$isOwner[0m | isReadOnly: [31m$isReadOnly[0m',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyTripPage(
          trip: trip,
          onTripUpdated: _loadTrips,
          isReadOnly: isReadOnly,
        ),
      ),
    ).then((_) => _loadTrips());
  }

  void _openImportTrip() async {
    final allowed = await SubscriptionService().hasFeature('share_trips');
    if (!allowed) {
      await showFeatureLockedDialog(
        context,
        title: AppConstants.importSharedTrip.tr(),
        description: AppConstants.importTripDescription.tr(),
        suggestedPlan: SubscriptionPlan.basic,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImportTripPage()),
    ).then((result) {
      if (result != null) {
        _loadTrips();
      }
    });
  }

  void _openDraft() {
    final openNewTripTab = widget.onOpenNewTripTab;
    if (openNewTripTab != null) {
      openNewTripTab();
      return;
    }

    Navigator.pushNamed(context, '/new-trip').then((_) {
      if (mounted) {
        _loadDraft();
        _loadTrips();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasDraft = _newTripDraft != null;

    return Scaffold(
      appBar: CustomAppBar(
        title: AppConstants.myTrips.tr(),
        actions: [
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: AppConstants.importTrip.tr(),
            onPressed: _openImportTrip,
          ),
        ],
        onProfileTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfilePage(onLogout: widget.onLogout),
            ),
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: AppConstants.upcoming.tr()),
              Tab(text: AppConstants.past.tr()),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Upcoming trips
                      _upcomingTrips.isEmpty && !hasDraft
                          ? const EmptyTripsState()
                          : RefreshIndicator(
                              onRefresh: _loadTrips,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(24),
                                itemCount:
                                    _upcomingTrips.length + (hasDraft ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (hasDraft && index == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: _DraftTripCard(
                                        draft: _newTripDraft!,
                                        onTap: _openDraft,
                                      ),
                                    );
                                  }

                                  final tripIndex = index - (hasDraft ? 1 : 0);
                                  final trip = _upcomingTrips[tripIndex];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _TripCard(
                                      trip: trip,
                                      imageUrl: _tripImages[trip.id],
                                      onTap: () => _openTripDetails(trip),
                                    ),
                                  );
                                },
                              ),
                            ),
                      // Past trips
                      _pastTrips.isEmpty
                          ? EmptyTripsState(
                              message: AppConstants.noPastTrips.tr(),
                              subtitle: AppConstants.noPastTripsSubtitle.tr(),
                              icon: Icons.history,
                            )
                          : RefreshIndicator(
                              onRefresh: _loadTrips,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(24),
                                itemCount: _pastTrips.length,
                                itemBuilder: (context, index) {
                                  final trip = _pastTrips[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _TripCard(
                                      trip: trip,
                                      imageUrl: _tripImages[trip.id],
                                      onTap: () => _openTripDetails(trip),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final String? imageUrl;
  final VoidCallback onTap;

  const _TripCard({
    required this.trip,
    required this.imageUrl,
    required this.onTap,
  });

  String _formatDateRange() {
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
    final startDay = trip.startDate.day;
    final endDay = trip.endDate.day;
    final startMonth = months[trip.startDate.month - 1];
    final endMonth = months[trip.endDate.month - 1];
    final year = trip.startDate.year;

    if (trip.startDate.month == trip.endDate.month) {
      return '$startDay - $endDay $startMonth $year';
    } else {
      return '$startDay $startMonth - $endDay $endMonth $year';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? AppColors.grey800 : AppColors.grey200,
          ),
          child: Stack(
            children: [
              // Imagem de fundo
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? AppColors.grey800 : AppColors.grey200,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark ? AppColors.grey800 : AppColors.grey200,
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.6),
                        AppColors.primary.withOpacity(0.4),
                      ],
                    ),
                  ),
                ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),

              // Conteúdo
              Positioned(
                bottom: 16,
                left: 16,
                right: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.destinationCity.isNotEmpty
                          ? trip.destinationCity
                          : trip.destinationCountry,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_formatDateRange()} • ${trip.durationInDays} ${AppConstants.days.tr()}',
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

              // Botão de navegação
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftTripCard extends StatelessWidget {
  final NewTripDraft draft;
  final VoidCallback onTap;

  static const List<double> _grayscaleMatrix = [
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  const _DraftTripCard({required this.draft, required this.onTap});

  String _title() {
    if ((draft.destinationCity ?? '').trim().isNotEmpty) {
      return draft.destinationCity!.trim();
    }
    if (draft.destinationLabel.trim().isNotEmpty) {
      return draft.destinationLabel.trim();
    }
    if ((draft.destinationCountry ?? '').trim().isNotEmpty) {
      return draft.destinationCountry!.trim();
    }
    return AppConstants.newTrip.tr();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = draft.destinationImageUrl;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? AppColors.grey800 : AppColors.grey200,
          ),
          child: Stack(
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: isDark ? AppColors.grey800 : AppColors.grey200,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? AppColors.grey800 : AppColors.grey200,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.grey.shade700, Colors.grey.shade500],
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((draft.destinationSubtitle ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        draft.destinationSubtitle!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFFFF5A5F),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppConstants.draft.tr(),
                          style: const TextStyle(
                            color: Color(0xFFFF5A5F),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
