import 'package:flutter/material.dart';
import '../../kviz_theme.dart';

class ModeCard extends StatelessWidget {
  const ModeCard({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.cta,
    required this.onTap,
  });

  final Widget badge;
  final String title;
  final String subtitle;
  final Color accent;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWarm = accent == const Color(0xFFEF5350);
    final isGold = accent == const Color(0xFFE0A800);
    final darkColors = isWarm
        ? const [Color(0xFFB80013), Color(0xFFE01826)]
        : isGold
        ? const [Color(0xFF5F4500), Color(0xFF9E7600)]
        : const [Color(0xFF07345F), Color(0xFF0E4C86)];
    final lightColors = isWarm
        ? const [Color(0xFFFFF3F3), Color(0xFFFFDADC)]
        : isGold
        ? const [Color(0xFFFFF8E1), Color(0xFFFFE082)]
        : const [Color(0xFFFFFFFF), Color(0xFFE0F0FF)];
    final borderColor = isDark
        ? (isWarm
              ? const Color(0xFFFF3344)
              : isGold
              ? const Color(0xFFE0A800)
              : const Color(0xFF1565C0))
        : (isWarm
              ? const Color(0xFFE9444C)
              : isGold
              ? const Color(0xFFE0A800)
              : const Color(0xFF5C93C8));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? darkColors : lightColors,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: borderColor.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                badge,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : context.strongText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFE3ECF5)
                              : context.mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white : context.accentText,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
