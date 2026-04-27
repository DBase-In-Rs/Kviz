import 'package:flutter/material.dart';
import '../../kviz_theme.dart';

class QuotaChip extends StatelessWidget {
  const QuotaChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: context.accentText),
          const SizedBox(width: 7),
          Text(
            '$label: ',
            style: TextStyle(
              color: context.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: context.strongText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
