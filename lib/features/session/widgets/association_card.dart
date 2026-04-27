import 'package:flutter/material.dart';
import '../../../shared/utils.dart';
import '../../../domain/entities.dart';
import 'association_column.dart';

class AssociationCard extends StatelessWidget {
  const AssociationCard({
    super.key,
    required this.association,
    required this.useCyrillic,
  });

  final AssociationPuzzle association;
  final bool useCyrillic;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalClues =
        association.cluesA.length +
        association.cluesB.length +
        association.cluesC.length +
        association.cluesD.length;

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
              Icon(Icons.grid_view_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                t('Asocijacija', 'Асоцијација'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '$totalClues ${t('pojmova', 'појмова')}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AssociationColumn(
                title: 'A',
                clues: association.cluesA,
                useCyrillic: useCyrillic,
              ),
              AssociationColumn(
                title: 'B',
                clues: association.cluesB,
                useCyrillic: useCyrillic,
              ),
              AssociationColumn(
                title: 'C',
                clues: association.cluesC,
                useCyrillic: useCyrillic,
              ),
              AssociationColumn(
                title: 'D',
                clues: association.cluesD,
                useCyrillic: useCyrillic,
              ),
            ],
          ),
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
                  Icons.lock_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  t(
                    'Rešenje je skriveno. Provera je tokom partije.',
                    'Решење је скривено. Провера је током партије.',
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
}
