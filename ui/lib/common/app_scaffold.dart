import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'app_colors.dart';
import 'constants/app_constants.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTabChange;
  final VoidCallback onLogout;

  const AppScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTabChange,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: child,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.navBackground,
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTabChange,
          backgroundColor: Colors.transparent,
          selectedItemColor: isDark ? AppColors.primary : AppColors.primaryDark,
          unselectedItemColor: isDark ? AppColors.textSecondaryDark : AppColors.primaryDark,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: AppConstants.home.tr(),
            ),
            BottomNavigationBarItem(
              icon: CircleAvatar(
                radius: 28,
                backgroundColor: isDark ? AppColors.primary : AppColors.primaryDark,
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_center_outlined),
              activeIcon: Icon(Icons.business_center),
              label: AppConstants.traveling.tr(),
            ),
          ],
        ),
      ),
    );
  }
}
