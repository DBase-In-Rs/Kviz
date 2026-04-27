import 'package:flutter/material.dart';

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.isLoading = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            isLoading ? '...' : value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
