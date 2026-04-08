import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NewTripDraft {
  final String destinationLabel;
  final String? destinationSubtitle;
  final String? destinationImageUrl;
  final String? destinationCity;
  final String? destinationCountry;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime savedAt;

  const NewTripDraft({
    required this.destinationLabel,
    this.destinationSubtitle,
    this.destinationImageUrl,
    this.destinationCity,
    this.destinationCountry,
    this.startDate,
    this.endDate,
    required this.savedAt,
  });

  bool get hasContent {
    if (destinationLabel.trim().isNotEmpty) return true;
    if (startDate != null || endDate != null) return true;
    if ((destinationSubtitle ?? '').trim().isNotEmpty) return true;
    if ((destinationCity ?? '').trim().isNotEmpty) return true;
    if ((destinationCountry ?? '').trim().isNotEmpty) return true;
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'destination_label': destinationLabel,
      if (destinationSubtitle != null)
        'destination_subtitle': destinationSubtitle,
      if (destinationImageUrl != null)
        'destination_image_url': destinationImageUrl,
      if (destinationCity != null) 'destination_city': destinationCity,
      if (destinationCountry != null) 'destination_country': destinationCountry,
      if (startDate != null) 'start_date': startDate!.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
      'saved_at': savedAt.toIso8601String(),
    };
  }

  factory NewTripDraft.fromJson(Map<String, dynamic> json) {
    DateTime? tryParseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return NewTripDraft(
      destinationLabel: (json['destination_label'] ?? '').toString(),
      destinationSubtitle: json['destination_subtitle']?.toString(),
      destinationImageUrl: json['destination_image_url']?.toString(),
      destinationCity: json['destination_city']?.toString(),
      destinationCountry: json['destination_country']?.toString(),
      startDate: tryParseDate(json['start_date']),
      endDate: tryParseDate(json['end_date']),
      savedAt: tryParseDate(json['saved_at']) ?? DateTime.now(),
    );
  }
}

class NewTripDraftService {
  static const String _draftKey = 'new_trip_draft_v1';
  static const Duration draftTtl = Duration(hours: 48);

  Future<void> saveDraft(NewTripDraft draft) async {
    if (!draft.hasContent) {
      await clearDraft();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  Future<NewTripDraft?> getDraft({bool purgeExpired = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final rawDraft = prefs.getString(_draftKey);

    if (rawDraft == null || rawDraft.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawDraft);
      if (decoded is! Map) {
        await clearDraft();
        return null;
      }

      final mapped = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      final draft = NewTripDraft.fromJson(mapped);
      final isExpired = DateTime.now().isAfter(draft.savedAt.add(draftTtl));

      if (isExpired) {
        if (purgeExpired) {
          await clearDraft();
        }
        return null;
      }

      if (!draft.hasContent) {
        await clearDraft();
        return null;
      }

      return draft;
    } catch (_) {
      await clearDraft();
      return null;
    }
  }

  Future<bool> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_draftKey);
  }
}
