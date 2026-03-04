import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'app_colors.dart';
import 'constants/app_constants.dart';
import '../services/subscription_service.dart';

class AppScaffold extends StatefulWidget {
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
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final status = await SubscriptionService().getStatus();
      if (mounted) {
        setState(() => _isPremium = status.isPremium);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: widget.child,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.navBackground,
        ),
        child: BottomNavigationBar(
          currentIndex: widget.currentIndex,
          onTap: widget.onTabChange,
          backgroundColor: Colors.transparent,
          selectedItemColor: isDark ? AppColors.primary : AppColors.primaryDark,
          unselectedItemColor: isDark ? AppColors.textSecondaryDark : AppColors.primaryDark,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: _isPremium
                  ? _buildCrownIcon(Icons.home_outlined, isDark)
                  : Icon(Icons.home_outlined),
              activeIcon: _isPremium
                  ? _buildCrownIcon(Icons.home, isDark)
                  : Icon(Icons.home),
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

  Widget _buildCrownIcon(IconData homeIcon, bool isDark) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(homeIcon),
        Positioned(
          right: -8,
          top: -6,
          child: Icon(
            Icons.workspace_premium,
            size: 14,
            color: Colors.amber,
          ),
        ),
      ],
    );
  }
}
