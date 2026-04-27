import 'package:flutter/material.dart';
import '../../../shared/utils.dart';

class AssociationColumn extends StatelessWidget {
  const AssociationColumn({
    super.key,
    required this.title,
    required this.clues,
    required this.useCyrillic,
  });

  final String title;
  final List<String> clues;
  final bool useCyrillic;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);
  String s(Object? value) => srScript(useCyrillic, value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 155,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('Kolona', 'Колона')} ${srAssociationTargetLabel(useCyrillic, title)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          ...clues.map(
            (clue) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                s(clue),
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
