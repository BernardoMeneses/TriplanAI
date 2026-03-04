import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../common/app_colors.dart';
import '../../../common/constants/app_constants.dart';

class EmptyTripsState extends StatelessWidget {
  final String? message;
  final String? subtitle;
  final IconData icon;
  
  const EmptyTripsState({
    super.key,
    this.message,
    this.subtitle,
    this.icon = Icons.park_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 120,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              message ?? AppConstants.noTripsYet.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle ?? AppConstants.createYourFirstTrip.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
