import 'package:flutter/material.dart';

import '../../presentation/kviz_theme.dart';

class StatBadge extends StatelessWidget {
  const StatBadge({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: context.accentText, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: context.strongText,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: context.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
