import 'package:flutter/material.dart';

class TogglePill extends StatelessWidget {
  const TogglePill({
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
    final selectedBg = Theme.of(context).brightness == Brightness.dark
        ? scheme.primaryContainer
        : scheme.primary;
    final selectedFg = Theme.of(context).brightness == Brightness.dark
        ? scheme.onPrimaryContainer
        : scheme.onPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? selectedBg : scheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: selected ? selectedBg : scheme.outline,
            width: selected ? 1.4 : 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? selectedFg : scheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? selectedFg : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
