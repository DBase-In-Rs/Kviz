import 'package:flutter/material.dart';
import '../../../shared/utils.dart';
import '../../kviz_theme.dart';

class DailyChallengeCard extends StatelessWidget {
  const DailyChallengeCard({
    super.key,
    required this.useCyrillic,
    required this.completedTasks,
    required this.totalTasks,
    required this.onTap,
  });

  final bool useCyrillic;
  final int completedTasks;
  final int totalTasks;
  final VoidCallback onTap;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);

  @override
  Widget build(BuildContext context) {
    final safeTotal = totalTasks <= 0 ? 1 : totalTasks;
    final safeCompleted = completedTasks.clamp(0, safeTotal);
    final progress = safeCompleted / safeTotal;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A0F13)
                          : const Color(0xFFFFE7E9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.track_changes_rounded,
                      color: Color(0xFFFF2A36),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('Dnevni izazov', 'Дневни изазов'),
                          style: TextStyle(
                            color: context.strongText,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t(
                            '$safeCompleted/$safeTotal današnja zadatka',
                            '$safeCompleted/$safeTotal данашња задатка',
                          ),
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: context.innerBg,
                            color: context.accentText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    Icons.card_giftcard_rounded,
                    color: context.strongText,
                    size: 38,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(
                  t('Izaberi izazov', 'Изабери изазов'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.actionBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
