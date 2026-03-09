import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../common/app_colors.dart';
import '../../common/constants/app_constants.dart';
import 'snackbar_helper.dart';
import '../../services/api_service.dart';
import '../../services/subscription_service.dart';
import 'upgrade_dialog.dart';

class AIChatModal extends StatefulWidget {
  final String? cityFilter;
  final String? countryFilter;
  final int dayNumber;
  final String? itineraryId;
  final String? tripId;
  final Function(String placeId, String name, String description)? onPlaceAdded;

  const AIChatModal({
    super.key,
    this.cityFilter,
    this.countryFilter,
    required this.dayNumber,
    this.itineraryId,
    this.tripId,
    this.onPlaceAdded,
  });

  @override
  State<AIChatModal> createState() => _AIChatModalState();
}

class _AIChatModalState extends State<AIChatModal> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _loadExistingConversation();
  }

  Future<void> _loadExistingConversation() async {
    setState(() => _isLoadingHistory = true);
    
    if (widget.tripId != null) {
      try {
        // Try to load existing conversation for this trip and day
        final response = await _apiService.get(
          '/ai/conversations?tripId=${widget.tripId}&dayNumber=${widget.dayNumber}'
        );

        if (response != null && response is List && response.isNotEmpty) {
          // Found existing conversation
          final conversation = response[0];
          _conversationId = conversation['id'];
          
          // Load conversation with messages
          final conversationData = await _apiService.get('/ai/conversations/$_conversationId');
          
          if (conversationData != null && conversationData['messages'] != null) {
            setState(() {
              // Convert database messages to ChatMessage format
              _messages = (conversationData['messages'] as List).map((msg) {
                List<PlaceSuggestion>? places;
                
                // Restore places from metadata if available
                if (msg['metadata'] != null && msg['metadata']['places'] != null) {
                  places = (msg['metadata']['places'] as List)
                      .map((p) => PlaceSuggestion.fromJson(p))
                      .toList();
                }
                
                return ChatMessage(
                  text: msg['content'],
                  isUser: msg['role'] == 'user',
                  places: places,
                );
              }).toList();
              _isLoadingHistory = false;
            });
            
            _scrollToBottom();
            return;
          }
        }
      } catch (e) {
        print('Error loading existing conversation: $e');
      }
    }
    
    // If no existing conversation found, show welcome message
    setState(() {
      _addWelcomeMessage();
      _isLoadingHistory = false;
    });
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: AppConstants.aiChatWelcome.tr(),
      isUser: false,
    ));

    _messages.add(ChatMessage(
      text: AppConstants.aiChatSuggestionExample.tr(),
      isUser: false,
      isSuggestion: true,
    ));
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Check AI prompt limit
    final subStatus = await SubscriptionService().getStatus(forceRefresh: true);
    if (!subStatus.canUseAI) {
      if (mounted) {
        showUpgradeDialog(
          context: context,
          feature: AppConstants.aiLimitTitle.tr(),
          description: AppConstants.aiLimitDesc.tr(),
        );
      }
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final location = widget.cityFilter != null
          ? '${widget.cityFilter}, ${widget.countryFilter}'
          : 'the destination';

      // Get current app language to send to AI
      final language = context.locale.languageCode;

      final response = await _apiService.post('/ai/suggestions', body: {
        'query': message,
        'location': location,
        'dayNumber': widget.dayNumber,
        'conversationId': _conversationId,
        'tripId': widget.tripId,
        'language': language,
      });

      if (mounted) {
        // Save conversation ID for subsequent messages
        if (response['conversationId'] != null) {
          _conversationId = response['conversationId'];
        }

        List<PlaceSuggestion>? places;
        if (response['places'] != null) {
          places = (response['places'] as List)
              .map((p) => PlaceSuggestion.fromJson(p))
              .toList();
        }

        setState(() {
          _messages.add(ChatMessage(
            text: response['response'] ?? AppConstants.aiChatFallbackResponse.tr(),
            isUser: false,
            places: places,
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: AppConstants.aiChatErrorResponse.tr(),
            isUser: false,
          ));
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmAddPlace(PlaceSuggestion place) async {
    // Buscar placeId real do Google Places se não tiver
    String? finalPlaceId = place.placeId;
    Map<String, dynamic>? placeDetails;

    if (finalPlaceId == null || finalPlaceId.isEmpty || finalPlaceId.startsWith('temp_')) {
      // Buscar lugar no Google Places usando o nome e localização
      try {
        final location = widget.cityFilter != null
            ? '${widget.cityFilter}, ${widget.countryFilter}'
            : '';

        final searchResponse = await _apiService.get(
            '/maps/destinations/search?query=${Uri.encodeComponent('${place.name} $location')}'
        );

        if (searchResponse != null && searchResponse is List && searchResponse.isNotEmpty) {
          finalPlaceId = searchResponse[0]['placeId'];
          placeDetails = searchResponse[0];
          print('Search response for ${place.name}: $placeDetails');
        }
      } catch (e) {
        print('Error searching for place: $e');
      }
    } else {
      // Get place details if we have the placeId
      try {
        placeDetails = await _apiService.get('/maps/destinations/$finalPlaceId');
        print('Place details for $finalPlaceId: $placeDetails');
      } catch (e) {
        print('Error getting place details: $e');
      }
    }

    if (finalPlaceId == null || finalPlaceId.isEmpty) {
      if (mounted) {
        SnackBarHelper.showError(context, AppConstants.aiChatPlaceNotFound.tr());
      }
      return;
    }

    // Show confirmation modal with place details
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddPlaceConfirmationModal(
        place: place,
        placeDetails: placeDetails,
        dayNumber: widget.dayNumber,
      ),
    );

    if (confirmed == true) {
      if (widget.onPlaceAdded != null) {
        widget.onPlaceAdded!(
          finalPlaceId,
          place.name,
          place.description ?? place.category,
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? AppColors.backgroundDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
        Text(
                      AppConstants.aiChatDayHeader.tr(namedArgs: {'day': widget.dayNumber.toString()}),
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.cityFilter ?? '',
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: _isLoadingHistory 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: isDark ? AppColors.primary : AppColors.primaryDark,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppConstants.aiChatLoadingConversation.tr(),
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.grey800 : AppColors.grey200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const SizedBox(
                            width: 40,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 4),
                                SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 4),
                                SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final message = _messages[index];
                    return Column(
                      crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        _MessageBubble(
                          message: message,
                          isDark: isDark,
                          onTap: message.isSuggestion ? () => _sendMessage(message.text) : null,
                        ),
                        if (message.places != null && message.places!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: message.places!.map((place) {
                                return _PlaceCard(
                                  place: place,
                                  isDark: isDark,
                                  onAdd: () => _confirmAddPlace(place),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // Input
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: AppConstants.aiChatInputHint.tr(),
                            hintStyle: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isDark ? AppColors.grey800 : AppColors.grey200,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          style: TextStyle(
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _sendMessage(_messageController.text),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
    }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final VoidCallback? onTap;

  const _MessageBubble({
    required this.message,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: message.isUser
                ? AppColors.primary
                : message.isSuggestion
                ? (isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primary.withOpacity(0.1))
                : (isDark ? AppColors.grey800 : AppColors.grey200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: message.isUser
                  ? Colors.white
                  : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final PlaceSuggestion place;
  final bool isDark;
  final VoidCallback onAdd;

  const _PlaceCard({
    required this.place,
    required this.isDark,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E3A3A) : const Color(0xFF2D5A5A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconForCategory(place.category),
              color: Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  place.category,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    final lowerCategory = category.toLowerCase();
    if (lowerCategory.contains('hotel') || lowerCategory.contains('accommodation')) {
      return Icons.hotel;
    } else if (lowerCategory.contains('restaurant') || lowerCategory.contains('food')) {
      return Icons.restaurant;
    } else if (lowerCategory.contains('park') || lowerCategory.contains('garden')) {
      return Icons.park;
    } else if (lowerCategory.contains('museum')) {
      return Icons.museum;
    } else if (lowerCategory.contains('shopping')) {
      return Icons.shopping_bag;
    } else if (lowerCategory.contains('outdoor') || lowerCategory.contains('nature')) {
      return Icons.landscape;
    } else if (lowerCategory.contains('activities') || lowerCategory.contains('experience')) {
      return Icons.local_activity;
    }
    return Icons.place;
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isSuggestion;
  final List<PlaceSuggestion>? places;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isSuggestion = false,
    this.places,
  });
}

class PlaceSuggestion {
  final String name;
  final String category;
  final String? placeId;
  final String? description;

  PlaceSuggestion({
    required this.name,
    required this.category,
    this.placeId,
    this.description,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      placeId: json['placeId'],
      description: json['description'],
    );
  }
}

// Confirmation modal to add place to plan
class _AddPlaceConfirmationModal extends StatelessWidget {
  final PlaceSuggestion place;
  final Map<String, dynamic>? placeDetails;
  final int dayNumber;

  const _AddPlaceConfirmationModal({
    required this.place,
    this.placeDetails,
    required this.dayNumber,
  });

  String _getOpeningHours() {
    if (placeDetails == null) {
      print('No placeDetails for opening hours');
      return '';
    }

    print('Getting opening hours from placeDetails');
    print('PlaceDetails full: $placeDetails');

    try {
      // Try opening_hours field (from our backend)
      var openingHours = placeDetails!['opening_hours'];
      if (openingHours == null) {
        openingHours = placeDetails!['openingHours'];
      }

      print('Opening hours raw: $openingHours');

      if (openingHours != null) {
        if (openingHours is Map) {
          print('Opening hours is a Map');
          // Try weekdayText first
          final weekdayText = openingHours['weekdayText'] ?? openingHours['weekday_text'];
          print('WeekdayText: $weekdayText');
          if (weekdayText != null && weekdayText is List && weekdayText.isNotEmpty) {
            final now = DateTime.now();
            final dayIndex = now.weekday - 1; // 0 = Monday, 6 = Sunday
            print('Current day index: $dayIndex');
            if (dayIndex < weekdayText.length) {
              final todayText = weekdayText[dayIndex];
              print('Today text: $todayText');
              // Remove day name prefix (e.g., "Monday: 9:00 AM – 6:00 PM" -> "9:00 AM – 6:00 PM")
              final colonIndex = todayText.indexOf(':');
              if (colonIndex != -1) {
                final result = todayText.substring(colonIndex + 1).trim();
                print('Returning hours: $result');
                return result;
              }
              return todayText;
            }
          }

          // Try periods format
          final periods = openingHours['periods'];
          if (periods != null && periods is List && periods.isNotEmpty) {
            final today = periods[0];
            if (today['open'] != null && today['close'] != null) {
              return 'Open ${today['open']['time']} - ${today['close']['time']}';
            }
          }

          // Check if open now
          final isOpenNow = openingHours['isOpenNow'] ?? openingHours['open_now'];
          if (isOpenNow != null) {
            return isOpenNow ? 'Open now' : 'Closed now';
          }
        }
      }
    } catch (e) {
      print('Error parsing opening hours: $e');
    }

    print('No opening hours found, returning empty');
    return '';
  }

  String _getDescription() {
    if (place.description != null && place.description!.isNotEmpty) {
      return place.description!;
    }

    if (placeDetails != null) {
      final description = placeDetails!['description'] ?? placeDetails!['editorial_summary']?['overview'];
      if (description != null && description.isNotEmpty) {
        return description;
      }
    }

    return '';
  }

  String _getImageUrl() {
    if (placeDetails != null) {
      print('PlaceDetails keys: ${placeDetails!.keys}');

      // Try images field first (from our backend)
      final images = placeDetails!['images'];
      print('Images field: $images');
      if (images != null) {
        if (images is List && images.isNotEmpty) {
          print('Found image in list: ${images[0]}');
          return images[0];
        } else if (images is String && images.isNotEmpty) {
          print('Found image as string: $images');
          return images;
        }
      }

      // Try photos field (Google Places format)
      final photos = placeDetails!['photos'];
      print('Photos field: $photos');
      if (photos != null && photos is List && photos.isNotEmpty) {
        // Photos can be either strings (URLs) or objects with 'url' field
        if (photos[0] is String) {
          print('Found photo as string: ${photos[0]}');
          return photos[0];
        } else if (photos[0] is Map) {
          final photoUrl = photos[0]['url'] ?? photos[0]['photo_reference'] ?? '';
          print('Found photo in map: $photoUrl');
          return photoUrl;
        }
      }

      // Try photoUrl field (single photo)
      final photoUrl = placeDetails!['photoUrl'];
      if (photoUrl != null && photoUrl.isNotEmpty) {
        print('Found photoUrl: $photoUrl');
        return photoUrl;
      }
    }
    print('No image found, returning empty');
    return '';
  }

  String _getAddress() {
    if (placeDetails != null) {
      print('Getting address from placeDetails: $placeDetails');
      // Try subtitle first (our backend format)
      final subtitle = placeDetails!['subtitle'];
      if (subtitle != null && subtitle.isNotEmpty) {
        print('Address found in subtitle: $subtitle');
        return subtitle;
      }

      // Fallback to other fields
      final address = placeDetails!['address'] ?? placeDetails!['formatted_address'] ?? placeDetails!['vicinity'] ?? '';
      print('Address found: $address');
      return address;
    }
    print('No placeDetails for address');
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = _getImageUrl();
    final address = _getAddress();
    final openingHours = _getOpeningHours();
    final description = _getDescription();

    return Container(
      margin: const EdgeInsets.only(top: 100),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppConstants.aiChatAddYourSpot.tr(),
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.grey800 : AppColors.grey200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.grey800 : AppColors.grey200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.image, size: 64, color: Colors.grey),
                          ),
                        ),
                      )
                          : Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.grey800 : AppColors.grey200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.place, size: 64, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Category badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIconForCategory(place.category),
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            place.category,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Place name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      place.name,
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      description.isNotEmpty ? description : AppConstants.aiChatDefaultDescription.tr(),
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Address
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
              address.isNotEmpty ? address : AppConstants.aiChatAddressNotAvailable.tr(),
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Opening hours
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
              openingHours.isNotEmpty ? openingHours : AppConstants.aiChatHoursNotAvailable.tr(),
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Add to plan button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppConstants.aiChatAddToPlan.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    final lowerCategory = category.toLowerCase();
    if (lowerCategory.contains('hotel') || lowerCategory.contains('accommodation')) {
      return Icons.hotel;
    } else if (lowerCategory.contains('restaurant') || lowerCategory.contains('food')) {
      return Icons.restaurant;
    } else if (lowerCategory.contains('park') || lowerCategory.contains('garden')) {
      return Icons.park;
    } else if (lowerCategory.contains('museum')) {
      return Icons.museum;
    } else if (lowerCategory.contains('shopping')) {
      return Icons.shopping_bag;
    } else if (lowerCategory.contains('outdoor') || lowerCategory.contains('nature')) {
      return Icons.landscape;
    } else if (lowerCategory.contains('activities') || lowerCategory.contains('experience')) {
      return Icons.local_activity;
    }
    return Icons.place;
  }
}
