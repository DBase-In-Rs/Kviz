import 'package:flutter/material.dart';
import '../../kviz_theme.dart';

class SettingsChoiceTile extends StatelessWidget {
  const SettingsChoiceTile({
    super.key,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? scheme.primaryContainer : scheme.primary;
    final selectedFg = isDark ? scheme.onPrimaryContainer : scheme.onPrimary;
    final bg = selected ? selectedBg : context.innerBg;
    final fg = selected ? selectedFg : context.strongText;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? selectedBg : context.borderColor,
              width: selected ? 1.4 : 1.1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: fg, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
