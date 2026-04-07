import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../common/constants/app_constants.dart';

class TravelingHeader extends StatelessWidget {
  const TravelingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        AppConstants.myTrips.tr(),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
