


import 'package:flutter/material.dart';
import '../../common/app_colors.dart';
import '../../services/destinations_service.dart';
import '../../shared/widgets/destination_search_modal.dart';

class LocationFilteredSearchModal extends StatefulWidget {
  final String? cityFilter;
  final String? countryFilter;
  final int? dayNumber;

  const LocationFilteredSearchModal({
    super.key,
    this.cityFilter,
    this.countryFilter,
    this.dayNumber,
  });

  @override
  State<LocationFilteredSearchModal> createState() => _LocationFilteredSearchModalState();
}

class _LocationFilteredSearchModalState extends State<LocationFilteredSearchModal> {
  final DestinationsService _destinationsService = DestinationsService();
  final TextEditingController _searchController = TextEditingController();

  List<Destination> _results = [];
  bool _isLoading = false;

  String get _locationLabel {
    if (widget.cityFilter != null && widget.cityFilter!.trim().isNotEmpty) {
      return widget.cityFilter!;
    }
    if (widget.countryFilter != null && widget.countryFilter!.trim().isNotEmpty) {
      return widget.countryFilter!;
    }
    return '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      String searchQuery = query;
      // Sempre priorizar cidade sobre país para pesquisa mais específica
      if (widget.cityFilter != null && widget.cityFilter!.trim().isNotEmpty) {
        searchQuery = '$query, ${widget.cityFilter}';
      } else if (widget.countryFilter != null && widget.countryFilter!.trim().isNotEmpty) {
        searchQuery = '$query, ${widget.countryFilter}';
      }

      final results = await _destinationsService.searchDestinations(searchQuery);

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
        ),
      );
    }
  }

  IconData _getIconForType(List<String> types) {
    if (types.contains('tourist_attraction')) return Icons.attractions;
    if (types.contains('museum')) return Icons.museum;
    if (types.contains('park')) return Icons.park;
    if (types.contains('restaurant')) return Icons.restaurant;
    if (types.contains('cafe')) return Icons.local_cafe;
    if (types.contains('shopping_mall')) return Icons.shopping_bag;
    if (types.contains('locality')) return Icons.location_city;
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        if (_locationLabel.isNotEmpty)
                          Text(
                            'Searching in $_locationLabel',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                      ],
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
                  hintText: 'Search attractions, museums, restaurants...',
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
                      setState(() {
                        _results = [];
                      });
                    },
                  )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _results.isEmpty && !_isLoading && _searchController.text.isNotEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results found',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                )
                    : _results.isEmpty
                    ? Center(
                  child: Text(
                    'Search for attractions, museums, restaurants...',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  itemCount: _results.length,
                  itemBuilder: (_, index) {
                    final destination = _results[index];
                    return ListTile(
                      leading: Icon(
                        _getIconForType(destination.types),
                        color: AppColors.primary,
                      ),
                      title: Text(
                        destination.name,
                        style: TextStyle(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      subtitle: Text(
                        destination.subtitle,
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      onTap: () => _selectDestination(destination),
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
