import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../common/app_colors.dart';
import '../../common/constants/app_constants.dart';
import '../../services/subscription_service.dart';
import '../../features/premium/subscription_plans_page.dart';

/// Shows a standardized dialog when a feature is locked for the current plan.
/// - [title] should be a localized string (call `.tr()` before passing if needed).
/// - [description] optional message describing why it's locked.
/// - [suggestedPlan] the minimum plan that unlocks the feature (e.g. Basic).
Future<void> showFeatureLockedDialog(
  BuildContext context, {
  required String title,
  String? description,
  required SubscriptionPlan suggestedPlan,
}) async {
  final status = await SubscriptionService().getStatus();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final planColor = status.isPremium
      ? Colors.amber
      : (status.isBasic ? Colors.blue : Colors.grey);

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: planColor.withOpacity(0.12),
                  ),
                  child: Icon(Icons.lock_outline, color: planColor, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  description ?? AppConstants.featureLockedDefault.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Actions depending on current status
                if (status.isFree) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubscriptionPlansPage(
                              initialPlan: SubscriptionPlan.basic,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('subscription.upgrade_to_basic'.tr()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubscriptionPlansPage(
                              initialPlan: SubscriptionPlan.premium,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(AppConstants.upgradeToPremium.tr()),
                    ),
                  ),
                ] else if (status.isBasic &&
                    suggestedPlan == SubscriptionPlan.premium) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubscriptionPlansPage(
                              initialPlan: SubscriptionPlan.premium,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(AppConstants.upgradeToPremium.tr()),
                    ),
                  ),
                ] else ...[
                  // Default: provide a Close button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppConstants.close.tr()),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Close X top-right
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.close,
                size: 20,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              tooltip: AppConstants.close.tr(),
            ),
          ),
        ],
      ),
    ),
  );
}
