import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../common/app_colors.dart';
import '../../../common/constants/app_constants.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../common/app_events.dart';
import '../../../shared/widgets/destination_search_modal.dart';
import '../../../services/trips_service.dart';
import '../../../services/trip_cache_service.dart';
import '../../../services/destinations_service.dart';
import '../../profile/pages/profile_page.dart';
import '../../trip_details/my_trip_page.dart';
import '../../favorites/favorites_page.dart';
import '../../notes/notes_page.dart';
import '../../../services/subscription_service.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onLogout;

  const HomePage({super.key, this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TripCacheService _tripCacheService = TripCacheService();
  final DestinationsService _destinationsService = DestinationsService();

  List<Trip> _upcomingTrips = [];
  List<Trip> _pastTrips = [];
  bool _isLoading = true;
  bool _isOfflineMode = false;
  bool _isPremium = false;

  final Map<String, String?> _tripImages = {};

  @override
  void initState() {
    super.initState();
    _loadTrips(forceRefresh: true);
    _checkPremiumStatus();
    // Atualizar automaticamente quando houver mudanca nas trips
    AppEvents.onTripsChanged.listen((_) {
      if (mounted) _loadTrips(forceRefresh: true);
    });
    AppEvents.onTripImported.listen((_) {
      if (mounted) _loadTrips(forceRefresh: true);
    });
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final status = await SubscriptionService().getStatus();
      if (mounted) setState(() => _isPremium = status.isPremium);
    } catch (_) {}
  }

  Future<void> _loadTrips({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      final trips = await _tripCacheService.getTrips(forceRefresh: forceRefresh);
      final now = DateTime.now();

      if (!mounted) return;

      setState(() {
        _isOfflineMode = _tripCacheService.isOfflineMode;
        _upcomingTrips = trips
            .where((t) => t.endDate.isAfter(now))
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));

        _pastTrips = trips
            .where((t) =>
        t.endDate.isBefore(now) ||
            t.endDate.isAtSameMomentAs(now))
            .toList()
          ..sort((a, b) => b.endDate.compareTo(a.endDate));

        _isLoading = false;
      });

      // Carregar imagens (do cache primeiro, depois online)
      for (final trip in [..._upcomingTrips, ..._pastTrips]) {
        _loadTripImage(trip);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
      final query =
          '${trip.destinationCity}, ${trip.destinationCountry}';

      final results =
      await _destinationsService.searchDestinations(query);

      if (results.isNotEmpty && mounted) {
        final details = await _destinationsService
            .getDestinationDetails(results.first.placeId);

        if (details?.photoUrl != null) {
          // Guardar em cache
          await _tripCacheService.cacheTripImage(trip.id, details!.photoUrl!);
          setState(() {
            _tripImages[trip.id] = details.photoUrl;
          });
        }
      }
    } catch (_) {}
  }

  // --------------------------------------------------
  // Navigation
  // --------------------------------------------------

  void _openTripDetails(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyTripPage(
          trip: trip,
          onTripUpdated: _loadTrips,
          isReadOnly: _isOfflineMode,
        ),
      ),
    ).then((_) => _loadTrips(forceRefresh: true));
  }

  Future<void> _openDestinationSearch() async {
    final result = await showModalBottomSheet<DestinationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DestinationSearchModal(),
    );

    if (result != null && mounted) {
      Navigator.pushNamed(
        context,
        '/new-trip',
        arguments: result,
      ).then((_) => _loadTrips(forceRefresh: true));
    }
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: AppConstants.homeTitle.tr(),
        isPremium: _isPremium,
        onFavoritesTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FavoritesPage(),
            ),
          );
        },
        onProfileTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProfilePage(onLogout: widget.onLogout),
            ),
          );
        },
        onNotesTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotesPage()),
          );
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(isDark),

            if (_upcomingTrips.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionHeader(
                  AppConstants.upcomingTrips.tr(), isDark),
              const SizedBox(height: 16),
              ..._upcomingTrips.map(
                    (trip) => Padding(
                  padding:
                  const EdgeInsets.only(bottom: 16),
                  child: _TripCard(
                    trip: trip,
                    imageUrl: _tripImages[trip.id],
                    isDark: isDark,
                    onTap: () => _openTripDetails(trip),
                  ),
                ),
              ),
            ],

            if (_upcomingTrips.isEmpty)
              _buildEmptyState(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return GestureDetector(
      onTap: _openDestinationSearch,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.grey800 : AppColors.grey100,
          borderRadius: BorderRadius.circular(12),
        ),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AppConstants.searchDestinations.tr(),
                style: TextStyle(
                  color: isDark
                      ? AppColors.textHintDark
                      : AppColors.textHintLight,
                ),
              ),
            ),
            Icon(Icons.search, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.park_outlined,
                size: 80,
                color: isDark
                    ? AppColors.grey800
                    : Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              AppConstants.noUpcomingTrips.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.startPlanningTrip.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Trip card
// --------------------------------------------------

class _TripCard extends StatelessWidget {
  final Trip trip;
  final String? imageUrl;
  final VoidCallback onTap;
  final bool isDark;

  const _TripCard({
    required this.trip,
    required this.imageUrl,
    required this.onTap,
    required this.isDark,
  });

  String _formatDateRange() {
    final months = [
      AppConstants.jan.tr(), AppConstants.feb.tr(), AppConstants.mar.tr(),
      AppConstants.apr.tr(), AppConstants.may.tr(), AppConstants.jun.tr(),
      AppConstants.jul.tr(), AppConstants.aug.tr(), AppConstants.sep.tr(),
      AppConstants.oct.tr(), AppConstants.nov.tr(), AppConstants.dec.tr()
    ];

    final s = trip.startDate;
    final e = trip.endDate;

    if (s.month == e.month) {
      return '${s.day} - ${e.day} ${months[s.month - 1]} ${s.year}';
    }

    return '${s.day} ${months[s.month - 1]} - '
        '${e.day} ${months[e.month - 1]} ${s.year}';
  }

  @override
  Widget build(BuildContext context) {
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
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? AppColors.grey800 : AppColors.grey200,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
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
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
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
                      trip.destinationCity.isNotEmpty
                          ? trip.destinationCity
                          : trip.destinationCountry,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDateRange()} • ${trip.durationInDays} ${AppConstants.days.tr()}',
                      style:
                      const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.arrow_forward,
                      color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
