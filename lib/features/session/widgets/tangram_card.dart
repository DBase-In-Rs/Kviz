import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../shared/utils.dart';
import '../../../domain/entities.dart';
import 'difficulty_badge.dart';

class TangramCard extends StatelessWidget {
  const TangramCard({
    super.key,
    required this.puzzle,
    required this.useCyrillic,
  });

  final TangramPuzzle puzzle;
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
              Icon(Icons.category_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                t('Tangram', 'Танграм'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              DifficultyBadge(
                label: s(puzzle.difficulty),
                difficulty: puzzle.difficulty,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s(puzzle.title),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${puzzle.timeLimitSeconds}s',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.grid_view_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '7 ${t('delova', 'делова')}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${t('Savet', 'Савет')}: ${s(puzzle.hint)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 80,
                  height: 80,
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  child: CustomPaint(
                    painter: _TangramSilhouettePainter(
                      color: scheme.primary.withValues(alpha: 0.35),
                      outlineColor: scheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TangramSilhouettePainter extends CustomPainter {
  _TangramSilhouettePainter({required this.color, required this.outlineColor});

  final Color color;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final outline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final w = size.width;
    final h = size.height;
    final s = math.min(w, h);

    // Draw classic tangram square silhouette outline
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH((w - s * 0.7) / 2, (h - s * 0.7) / 2, s * 0.7, s * 0.7),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, paint);
    canvas.drawRRect(rect, outline);

    // Draw internal lines suggesting tangram pieces
    final path = Path();
    final cx = w / 2;
    final cy = h / 2;
    final r = s * 0.28;

    // Diagonal from top-left to bottom-right
    path.moveTo(cx - r, cy - r);
    path.lineTo(cx + r, cy + r);

    // Diagonal from top-right to bottom-left
    path.moveTo(cx + r, cy - r);
    path.lineTo(cx - r, cy + r);

    // Horizontal center line
    path.moveTo(cx - r, cy);
    path.lineTo(cx + r, cy);

    // Vertical center line
    path.moveTo(cx, cy - r);
    path.lineTo(cx, cy + r);

    canvas.drawPath(path, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
