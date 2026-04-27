import 'package:flutter/material.dart';
import '../../kviz_theme.dart';

class StatSummaryTile extends StatelessWidget {
  const StatSummaryTile({
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
    return SizedBox(
      width: 158,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.accentText, size: 24),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: context.strongText,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
