import 'package:flutter/material.dart';

/// Paints a 7-piece tangram square silhouette with internal cut lines.
/// Used in practice preview cards to show the tangram figure outline.
class TangramBoardPainter extends CustomPainter {
  TangramBoardPainter({required this.fillColor, required this.lineColor});

  final Color fillColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;
    const margin = 12.0;
    final left = margin;
    final top = margin;
    final right = w - margin;
    final bottom = h - margin;
    final mid = (left + right) / 2;
    final midY = (top + bottom) / 2;

    // Draw the 7 tangram pieces as a square silhouette with cut lines
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, top, right, bottom),
      const Radius.circular(4),
    );
    canvas.drawRRect(outerRect, fill);
    canvas.drawRRect(outerRect, stroke);

    // Internal cut lines
    final path = Path();

    // Center vertical line
    path.moveTo(mid, top);
    path.lineTo(mid, bottom);

    // Center horizontal line
    path.moveTo(left, midY);
    path.lineTo(right, midY);

    // Diagonal 1: mid,top to right,midY
    path.moveTo(mid, top);
    path.lineTo(right, midY);

    // Diagonal 2: left,midY to mid,bottom
    path.moveTo(left, midY);
    path.lineTo(mid, bottom);

    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
