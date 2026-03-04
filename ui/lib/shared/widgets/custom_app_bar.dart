import 'package:flutter/material.dart';
import '../../common/app_colors.dart';
import '../../services/theme_service.dart';
import '../../services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../common/constants/app_constants.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onProfileTap;
  final VoidCallback? onFavoritesTap;
  final List<Widget>? actions;
  final VoidCallback? onNotesTap;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.onProfileTap,
    this.onFavoritesTap,
    this.actions,
    this.onNotesTap,
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
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      elevation: 0,
      actions: [
        // Custom actions if provided
        if (actions != null) ...actions!,
        // Botão de Favoritos
        if (onFavoritesTap != null)
          IconButton(
            icon: Icon(
              Icons.bookmark_border,
              color: AppColors.primary,
            ),
            onPressed: onFavoritesTap,
            tooltip: AppConstants.favorites.tr(),
          ),
        // Notes button (optional)
        if (onNotesTap != null)
          IconButton(
            icon: Icon(Icons.sticky_note_2, color: AppColors.primary),
            onPressed: onNotesTap,
            tooltip: AppConstants.notesTitle.tr(),
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
          tooltip: themeService.isDarkMode ? AppConstants.themeLight.tr() : AppConstants.themeDark.tr(),
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
        border: Border.all(
          color: AppColors.primary,
          width: 2,
        ),
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
}
