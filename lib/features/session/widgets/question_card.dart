import 'package:flutter/material.dart';
import '../../../shared/utils.dart';
import '../../../domain/entities.dart';

class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.useCyrillic,
  });

  final QuizQuestion question;
  final bool useCyrillic;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);
  String s(Object? value) => srScript(useCyrillic, value);

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
          Row(
            children: [
              Icon(Icons.quiz_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                t('Pitanje', 'Питање'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s(question.question),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _buildOptionRow('A', question.optionA, scheme),
          _buildOptionRow('B', question.optionB, scheme),
          _buildOptionRow('C', question.optionC, scheme),
          _buildOptionRow('D', question.optionD, scheme),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  t(
                    'Odgovor se kuca tokom partije.',
                    'Одговор се куца током партије.',
                  ),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(String label, String text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              s(label),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                s(text),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
