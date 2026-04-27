import 'package:flutter/material.dart';
import '../../kviz_theme.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.accentText, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: context.strongText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
