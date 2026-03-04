import 'package:flutter/material.dart';

class TravelingTabs extends StatelessWidget {
  const TravelingTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: const [
          _TabItem(label: 'Upcoming', selected: true),
          SizedBox(width: 12),
          _TabItem(label: 'Past', selected: false),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool selected;

  const _TabItem({
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: selected ? Colors.black : Colors.grey,
      ),
    );
  }
}
