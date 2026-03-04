import 'package:flutter/material.dart';

class TravelingHeader extends StatelessWidget {
  const TravelingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        'Your trips',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
