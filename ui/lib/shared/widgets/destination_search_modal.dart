import 'package:flutter/material.dart';
import 'dart:async';
import '../../common/app_colors.dart';
import '../../services/destinations_service.dart';

class DestinationResult {
  final String placeId;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? city;
  final String? country;

  DestinationResult({
    required this.placeId,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.city,
    this.country,
  });
}

class DestinationSearchModal extends StatefulWidget {
  const DestinationSearchModal({super.key});

  @override
  State<DestinationSearchModal> createState() => _DestinationSearchModalState();
}

class _DestinationSearchModalState extends State<DestinationSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  final DestinationsService _destinationsService = DestinationsService();

  List<Destination> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchDestinations(query);
    });
  }

  Future<void> _searchDestinations(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await _destinationsService.searchDestinations(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDestination(Destination destination) async {
    // Obter detalhes do destino (incluindo foto)
    setState(() => _isLoading = true);

    final details = await _destinationsService.getDestinationDetails(destination.placeId);

    if (mounted) {
      Navigator.pop(
        context,
        DestinationResult(
          placeId: destination.placeId,
          title: destination.name,
          subtitle: destination.subtitle,
          imageUrl: details?.photoUrl,
          city: destination.city,
          country: destination.country,
        ),
      );
    }
  }

  IconData _getIconForType(List<String> types) {
    if (types.contains('country')) return Icons.flag;
    if (types.contains('locality')) return Icons.location_city;
    if (types.contains('administrative_area_level_1')) return Icons.map;
    if (types.contains('administrative_area_level_2')) return Icons.map_outlined;
    return Icons.place;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Where to?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'To country or city',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textHintDark : AppColors.textHintLight,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.grey800 : AppColors.grey100,
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                      : _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _results = []);
                    },
                  )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _results.isEmpty && !_isLoading
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.travel_explore,
                        size: 64,
                        color: isDark ? AppColors.grey800 : Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Search for a destination'
                            : 'No destinations found',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  itemCount: _results.length,
                  itemBuilder: (_, index) {
                    final item = _results[index];
                    return ListTile(
                      leading: Icon(
                        _getIconForType(item.types),
                        color: AppColors.primary,
                      ),
                      title: Text(
                        item.name,
                        style: TextStyle(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      subtitle: Text(
                        item.subtitle,
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      onTap: () => _selectDestination(item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
