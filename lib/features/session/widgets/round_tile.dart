import 'package:flutter/material.dart';
import '../../../domain/entities.dart'; // RoundInfo
import '../../../shared/utils.dart';

class RoundTile extends StatelessWidget {
  const RoundTile({
    super.key,
    required this.index,
    required this.round,
    required this.durationSeconds,
    required this.useCyrillic,
  });

  final int index;
  final RoundInfo round;
  final int? durationSeconds;
  final bool useCyrillic;

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
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              srScript(useCyrillic, round.title),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          if (durationSeconds != null)
            Text(
              '${durationSeconds!}s',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
