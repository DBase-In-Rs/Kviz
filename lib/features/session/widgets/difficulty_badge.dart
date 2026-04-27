import 'package:flutter/material.dart';

/// A small coloured badge showing puzzle difficulty (lako/srednje/teško).
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({
    super.key,
    required this.label,
    required this.difficulty,
    ColorScheme? scheme,
  }) : _scheme = scheme;

  final String label;
  final String difficulty;
  final ColorScheme? _scheme;

  Color _color(ColorScheme scheme) => switch (difficulty) {
    'lako' => const Color(0xFF4CAF50),
    'srednje' => const Color(0xFFFF9800),
    'teško' => const Color(0xFFEF5350),
    _ => scheme.primary,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = _scheme ?? Theme.of(context).colorScheme;
    final color = _color(scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
