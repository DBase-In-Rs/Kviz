import 'package:flutter/material.dart';
import '../../kviz_theme.dart';

class AchievementTile extends StatelessWidget {
  const AchievementTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.completed,
    this.progress,
    this.progressLabel,
    this.rarityLabel,
  });

  final String title;
  final String subtitle;
  final bool completed;
  final double? progress;
  final String? progressLabel;
  final String? rarityLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed ? context.successBg : context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed ? context.successColor : context.borderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.emoji_events_rounded
                : Icons.emoji_events_outlined,
            color: completed ? context.successColor : context.accentText,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.strongText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (progress != null && completed == false) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0, 1).toDouble(),
                      minHeight: 6,
                      backgroundColor: context.innerBg,
                      color: context.actionBlue,
                    ),
                  ),
                ],
                if ((progressLabel?.isNotEmpty ?? false) ||
                    (rarityLabel?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (progressLabel?.isNotEmpty ?? false) progressLabel!,
                      if (rarityLabel?.isNotEmpty ?? false) rarityLabel!,
                    ].join('  |  '),
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            completed ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: completed ? context.successColor : context.mutedText,
          ),
        ],
      ),
    );
  }
}
