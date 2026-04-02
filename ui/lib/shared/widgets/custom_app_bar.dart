import 'package:flutter/material.dart';
import '../../common/app_colors.dart';
import '../../services/theme_service.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../services/trip_cache_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../common/constants/app_constants.dart';
import '../../features/premium/subscription_plans_page.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onProfileTap;
  final VoidCallback? onFavoritesTap;
  final List<Widget>? actions;
  final SubscriptionStatus? subscriptionStatus;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.onProfileTap,
    this.onFavoritesTap,
    this.actions,
    this.subscriptionStatus,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      elevation: 0,
      actions: [
        // Custom actions if provided
        if (actions != null) ...actions!,
        // Medalha do plano (separada, à esquerda dos favoritos)
        if (subscriptionStatus != null)
          IconButton(
            icon: Icon(
              Icons.workspace_premium,
              color: subscriptionStatus!.isPremium
                  ? Colors.amber
                  : subscriptionStatus!.isBasic
                  ? Colors.blue
                  : Colors.white,
              size: 28,
            ),
            onPressed: () => _showPlanInfoModal(context),
            tooltip: AppConstants.premium.tr(),
          ),
        // Botão de Favoritos
        if (onFavoritesTap != null)
          IconButton(
            icon: Icon(Icons.bookmark_border, color: AppColors.primary),
            onPressed: onFavoritesTap,
            tooltip: AppConstants.favorites.tr(),
          ),
        // Botão de Theme
        IconButton(
          icon: Icon(
            themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: AppColors.primary,
          ),
          onPressed: () {
            themeService.toggleTheme();
          },
          tooltip: themeService.isDarkMode
              ? AppConstants.themeLight.tr()
              : AppConstants.themeDark.tr(),
        ),
        // Botão de Profile com foto do utilizador
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: onProfileTap,
            child: _buildProfileAvatar(context),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: isDark ? AppColors.grey800 : AppColors.grey100,
        backgroundImage: user?.profilePictureUrl != null
            ? NetworkImage(user!.profilePictureUrl!)
            : null,
        child: user?.profilePictureUrl == null
            ? Text(
                user?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _showPlanInfoModal(BuildContext context) async {
    final status = subscriptionStatus!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int usedTrips = 0;
    if (!status.limits.isUnlimitedTrips) {
      try {
        final trips = await TripCacheService().getTrips(forceRefresh: true);
        usedTrips = trips
            .where((trip) => !trip.isMember)
            .fold(0, (total, trip) => total + 1 + trip.replacementCount);
      } catch (_) {
        usedTrips = 0;
      }
    }

    if (!context.mounted) return;

    final planName = status.isPremium
        ? 'subscription.premium'.tr()
        : status.isBasic
        ? 'subscription.basic'.tr()
        : 'subscription.free'.tr();
    final planColor = status.isPremium
        ? Colors.amber
        : (status.isBasic ? Colors.blue : Colors.white);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone do plano
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: planColor.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      Icons.workspace_premium,
                      color: planColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Nome do plano
                  Text(
                    planName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'subscription.current_plan'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Detalhes do plano
                  _planInfoRow(
                    Icons.card_travel,
                    status.limits.isUnlimitedTrips
                        ? 'subscription.unlimited_trips'.tr()
                        : '$usedTrips/${status.limits.maxTrips} ${'subscription.trips'.tr()}',
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  _planInfoRow(
                    Icons.auto_awesome,
                    status.limits.isUnlimitedAI
                        ? 'subscription.unlimited_ai'.tr()
                        : '${status.aiGenerationsRemaining}/${status.limits.aiGenerationsPerMonth} ${'subscription.ai_month'.tr()}',
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  _planInfoRow(
                    Icons.picture_as_pdf,
                    'subscription.export_pdf'.tr(),
                    isDark,
                    enabled: status.limits.canExportPdf,
                  ),
                  const SizedBox(height: 10),
                  _planInfoRow(
                    Icons.cloud_upload,
                    'subscription.cloud_backup'.tr(),
                    isDark,
                    enabled: status.limits.canBackupCloud,
                  ),
                  const SizedBox(height: 10),
                  _planInfoRow(
                    Icons.share,
                    'subscription.share_trips'.tr(),
                    isDark,
                    enabled: status.limits.canShareTrips,
                  ),
                  if (status.isBasic) ...[
                    const SizedBox(height: 10),
                    _planInfoRow(
                      Icons.backup,
                      'subscription.manual_backup'.tr(),
                      isDark,
                      enabled: true,
                      checkColor: Colors.amber,
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Ações do modal (upgrade / downgrade)
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
                  ] else if (status.isBasic) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await SubscriptionService()
                              .deactivatePlan();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'subscription.downgrade'.tr()
                                    : 'purchase_failed'.tr(),
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('subscription.downgrade_to_free'.tr()),
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
                  ] else ...[
                    // Premium
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
                        child: Text('subscription.downgrade_to_basic'.tr()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await SubscriptionService()
                              .deactivatePlan();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'subscription.downgrade'.tr()
                                    : 'purchase_failed'.tr(),
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('subscription.downgrade_to_free'.tr()),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Close button top-right
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
                tooltip: 'common.close'.tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planInfoRow(
    IconData icon,
    String label,
    bool isDark, {
    bool enabled = true,
    Color? checkColor,
  }) {
    return Row(
      children: [
        Icon(
          enabled ? icon : Icons.lock_outline,
          size: 20,
          color: enabled
              ? AppColors.primary
              : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: enabled
                  ? (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight)
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
          ),
        ),
        Icon(
          enabled ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: enabled ? (checkColor ?? Colors.green) : Colors.red.shade300,
        ),
      ],
    );
  }
}
