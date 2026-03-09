import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../common/app_colors.dart';
import '../../common/constants/app_constants.dart';
import '../../shared/widgets/snackbar_helper.dart';
import '../../services/favorites_service.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoritesService _favoritesService = FavoritesService();
  List<FavoritePlace> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Registar callback para atualizações em background
    _favoritesService.onFavoritesUpdated = (updatedFavorites) {
      if (mounted) {
        setState(() {
          _favorites = updatedFavorites;
        });
      }
    };
    _loadFavorites();
  }
  
  @override
  void dispose() {
    _favoritesService.onFavoritesUpdated = null;
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      setState(() => _isLoading = true);
      final favorites = await _favoritesService.getFavorites();
      if (mounted) {
        setState(() {
          _favorites = favorites;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeFavorite(FavoritePlace favorite) async {
    try {
      await _favoritesService.removeFavorite(favorite.placeId);
      if (mounted) {
        SnackBarHelper.showSuccess(context, AppConstants.removedFromFavorites.tr());
        _loadFavorites();
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, AppConstants.errorRemovingFavorite.tr());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        title: Text(
          AppConstants.myFavorites.tr(),
          style: TextStyle(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 100,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppConstants.noFavorites.tr(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          AppConstants.noFavoritesDescription.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final favorite = _favorites[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (favorite.place.images?.isNotEmpty ?? false)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: favorite.place.images!.first,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    height: 160,
                                    color: AppColors.primary.withOpacity(0.1),
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 160,
                                    color: AppColors.primary.withOpacity(0.1),
                                    child: Center(
                                      child: Icon(
                                        Icons.place,
                                        size: 64,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          favorite.place.name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppColors.textPrimaryDark
                                                : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.bookmark,
                                          color: AppColors.primary,
                                        ),
                                        onPressed: () => _showRemoveDialog(favorite),
                                      ),
                                    ],
                                  ),
                                  if (favorite.place.address != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 16,
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            favorite.place.address!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (favorite.place.rating != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          favorite.place.rating!.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.textPrimaryDark
                                                : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (favorite.notes != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.note,
                                            size: 16,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              favorite.notes!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDark
                                                    ? AppColors.textPrimaryDark
                                                    : AppColors.textPrimaryLight,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    'Added ${DateFormat('MMM d, yyyy').format(favorite.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showRemoveDialog(FavoritePlace favorite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppConstants.removeFavorite.tr()),
        content: Text('Remove "${favorite.place.name}" from favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppConstants.cancel.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFavorite(favorite);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppConstants.remove.tr()),
          ),
        ],
      ),
    );
  }
}
