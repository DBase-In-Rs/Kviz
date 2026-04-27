import 'package:flutter/material.dart';
import '../../../shared/utils.dart';
import '../../../domain/entities.dart';

class MyNumberCard extends StatelessWidget {
  const MyNumberCard({
    super.key,
    required this.puzzle,
    required this.useCyrillic,
  });

  final MyNumberPuzzle puzzle;
  final bool useCyrillic;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.8),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('Brojevi', 'Бројеви')}: ${puzzle.numbers.join(', ')}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${t('Traženi broj', 'Тражени број')}: ${puzzle.target}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            t(
              'Rešenje unosiš tokom probne partije.',
              'Решење уносиш током пробне партије.',
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
