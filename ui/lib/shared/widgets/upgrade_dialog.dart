import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../common/app_colors.dart';
import '../../common/constants/app_constants.dart';
import '../../features/premium/subscription_plans_page.dart';

/// Shows an upgrade dialog when a feature is locked behind a subscription.
///
/// [context] - Build context
/// [feature] - Translation key for the feature name (e.g. 'limits.trip_limit_title')
/// [description] - Translation key for the description
Future<void> showUpgradeDialog({
  required BuildContext context,
  required String feature,
  required String description,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(
        Icons.lock_outline,
        color: AppColors.primary,
        size: 48,
      ),
      title: Text(
        feature,
        style: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        description,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'limits.maybe_later'.tr(),
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionPlansPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            AppConstants.upgradeToPremium.tr(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
