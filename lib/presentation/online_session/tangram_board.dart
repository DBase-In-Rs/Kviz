part of '../online_session_page.dart';

class _TangramShapePainter extends CustomPainter {
  const _TangramShapePainter({
    required this.shape,
    required this.fillColor,
    required this.outlineColor,
  });

  final Map<String, dynamic>? shape;
  final Color fillColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final polygons = _readPolygons();
    if (polygons.isEmpty) {
      _drawFallback(canvas, size);
      return;
    }

    final sourceRect = _sourceRect(polygons);
    if (sourceRect.width <= 0 || sourceRect.height <= 0) {
      _drawFallback(canvas, size);
      return;
    }

    final padding = size.shortestSide * 0.08;
    final availableWidth = max(1.0, size.width - (padding * 2));
    final availableHeight = max(1.0, size.height - (padding * 2));
    final scale = min(
      availableWidth / sourceRect.width,
      availableHeight / sourceRect.height,
    );
    final offset = Offset(
      (size.width - (sourceRect.width * scale)) / 2 - (sourceRect.left * scale),
      (size.height - (sourceRect.height * scale)) / 2 -
          (sourceRect.top * scale),
    );

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, size.shortestSide * 0.006);

    for (final polygon in polygons) {
      if (polygon.length < 3) {
        continue;
      }

      final path = Path()
        ..moveTo(
          offset.dx + polygon.first.dx * scale,
          offset.dy + polygon.first.dy * scale,
        );
      for (final point in polygon.skip(1)) {
        path.lineTo(offset.dx + point.dx * scale, offset.dy + point.dy * scale);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  List<List<Offset>> _readPolygons() {
    final rawPolygons = shape?['polygons'];
    if (rawPolygons is List) {
      final polygons = rawPolygons
          .map(_readPolygon)
          .where((polygon) => polygon.length >= 3)
          .toList(growable: false);
      if (polygons.isNotEmpty) {
        return polygons;
      }
    }

    final rawPieces = shape?['pieces'];
    if (rawPieces is! List) {
      return const <List<Offset>>[];
    }

    return rawPieces.indexed
        .map((entry) => _readPiecePolygon(entry.$2, entry.$1))
        .where((polygon) => polygon.length >= 3)
        .toList(growable: false);
  }

  List<Offset> _readPiecePolygon(Object? rawPiece, int index) {
    if (rawPiece is! Map) {
      return const <Offset>[];
    }

    final map = Map<Object?, Object?>.from(rawPiece);
    final x = _asDouble(map['x']);
    final y = _asDouble(map['y']);
    if (x == null || y == null) {
      return const <Offset>[];
    }

    return _transformedTangramPolygon(
      _TangramPieceState(
        id: map['id']?.toString() ?? 'shape_piece_$index',
        kind: map['kind']?.toString() ?? 'small_triangle',
        position: Offset(x, y),
        rotation: _asDouble(map['rotation']) ?? 0,
        flipped: map['flipped'] == true,
      ),
    );
  }

  List<Offset> _readPolygon(Object? rawPolygon) {
    if (rawPolygon is! List) {
      return const <Offset>[];
    }

    return rawPolygon
        .map(_readPoint)
        .whereType<Offset>()
        .toList(growable: false);
  }

  Offset? _readPoint(Object? rawPoint) {
    if (rawPoint is Map) {
      final map = Map<Object?, Object?>.from(rawPoint);
      final x = _asDouble(map['x']);
      final y = _asDouble(map['y']);
      if (x != null && y != null) {
        return Offset(x, y);
      }
    }

    if (rawPoint is List && rawPoint.length >= 2) {
      final x = _asDouble(rawPoint[0]);
      final y = _asDouble(rawPoint[1]);
      if (x != null && y != null) {
        return Offset(x, y);
      }
    }

    return null;
  }

  Rect _sourceRect(List<List<Offset>> polygons) {
    final canvas = shape?['canvas'];
    if (canvas is Map) {
      final map = Map<Object?, Object?>.from(canvas);
      final width = _asDouble(map['width']);
      final height = _asDouble(map['height']);
      if (width != null && height != null && width > 0 && height > 0) {
        return Rect.fromLTWH(0, 0, width, height);
      }
    }

    final points = polygons.expand((polygon) => polygon);
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final point in points) {
      minX = min(minX, point.dx);
      minY = min(minY, point.dy);
      maxX = max(maxX, point.dx);
      maxY = max(maxY, point.dy);
    }

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return Rect.zero;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  void _drawFallback(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, size.shortestSide * 0.006);
    final side = size.shortestSide * 0.62;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
    final path = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    canvas.drawLine(rect.topLeft, rect.bottomRight, stroke);
    canvas.drawLine(rect.topRight, rect.bottomLeft, stroke);
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TangramShapePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}

class _TangramPieceState {
  const _TangramPieceState({
    required this.id,
    required this.kind,
    required this.position,
    required this.rotation,
    required this.flipped,
  });

  final String id;
  final String kind;
  final Offset position;
  final double rotation;
  final bool flipped;

  _TangramPieceState copyWith({
    Offset? position,
    double? rotation,
    bool? flipped,
  }) {
    return _TangramPieceState(
      id: id,
      kind: kind,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      flipped: flipped ?? this.flipped,
    );
  }

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'id': id,
      'kind': kind,
      'x': double.parse(position.dx.toStringAsFixed(2)),
      'y': double.parse(position.dy.toStringAsFixed(2)),
      'rotation': double.parse(rotation.toStringAsFixed(2)),
      'flipped': flipped,
    };
  }
}

const List<_TangramPieceState> _initialTangramPieces = <_TangramPieceState>[
  _TangramPieceState(
    id: 'large_triangle_1',
    kind: 'large_triangle',
    position: Offset(24, 24),
    rotation: 0,
    flipped: false,
  ),
  _TangramPieceState(
    id: 'large_triangle_2',
    kind: 'large_triangle',
    position: Offset(258, 24),
    rotation: 90,
    flipped: false,
  ),
  _TangramPieceState(
    id: 'medium_triangle',
    kind: 'medium_triangle',
    position: Offset(24, 202),
    rotation: 0,
    flipped: false,
  ),
  _TangramPieceState(
    id: 'square',
    kind: 'square',
    position: Offset(170, 184),
    rotation: 0,
    flipped: false,
  ),
  _TangramPieceState(
    id: 'parallelogram',
    kind: 'parallelogram',
    position: Offset(278, 204),
    rotation: 0,
    flipped: false,
  ),
  _TangramPieceState(
    id: 'small_triangle_1',
    kind: 'small_triangle',
    position: Offset(76, 326),
    rotation: 0,
    flipped: false,
  ),
  _TangramPieceState(
    id: 'small_triangle_2',
    kind: 'small_triangle',
    position: Offset(258, 326),
    rotation: 90,
    flipped: false,
  ),
];

class _TangramInteractionPainter extends CustomPainter {
  const _TangramInteractionPainter({
    required this.shape,
    required this.pieces,
    required this.selectedPieceId,
    required this.targetFillColor,
    required this.targetOutlineColor,
    required this.pieceFillColor,
    required this.pieceOutlineColor,
    required this.selectedColor,
  });

  final Map<String, dynamic>? shape;
  final List<_TangramPieceState> pieces;
  final String? selectedPieceId;
  final Color targetFillColor;
  final Color targetOutlineColor;
  final Color pieceFillColor;
  final Color pieceOutlineColor;
  final Color selectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    _TangramShapePainter(
      shape: shape,
      fillColor: targetFillColor,
      outlineColor: targetOutlineColor,
    ).paint(canvas, size);

    final sourceRect = _tangramSourceRect(shape);
    final transform = _tangramTransform(size, sourceRect);

    for (final piece in pieces) {
      final selected = piece.id == selectedPieceId;
      final fill = Paint()
        ..color = selected
            ? selectedColor.withValues(alpha: 0.28)
            : pieceFillColor.withValues(alpha: 0.82)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = selected ? selectedColor : pieceOutlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.4 : 1.4;

      final logicalPath = _tangramPiecePath(piece);
      final transformMatrix = Matrix4.identity()
        ..translateByDouble(transform.offset.dx, transform.offset.dy, 0, 1)
        ..scaleByDouble(transform.scale, transform.scale, 1, 1);
      final screenPath = logicalPath.transform(transformMatrix.storage);
      canvas.drawPath(screenPath, fill);
      canvas.drawPath(screenPath, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _TangramInteractionPainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.pieces != pieces ||
        oldDelegate.selectedPieceId != selectedPieceId ||
        oldDelegate.targetFillColor != targetFillColor ||
        oldDelegate.targetOutlineColor != targetOutlineColor ||
        oldDelegate.pieceFillColor != pieceFillColor ||
        oldDelegate.pieceOutlineColor != pieceOutlineColor ||
        oldDelegate.selectedColor != selectedColor;
  }
}

class _TangramTransform {
  const _TangramTransform({required this.scale, required this.offset});

  final double scale;
  final Offset offset;
}

Rect _tangramSourceRect(Map<String, dynamic>? shape) {
  final canvas = shape?['canvas'];
  if (canvas is Map) {
    final map = Map<Object?, Object?>.from(canvas);
    final width = _asTangramDouble(map['width']);
    final height = _asTangramDouble(map['height']);
    if (width != null && height != null && width > 0 && height > 0) {
      return Rect.fromLTWH(0, 0, width, height);
    }
  }

  return const Rect.fromLTWH(0, 0, 420, 420);
}

_TangramTransform _tangramTransform(Size size, Rect sourceRect) {
  final padding = size.shortestSide * 0.08;
  final availableWidth = max(1.0, size.width - (padding * 2));
  final availableHeight = max(1.0, size.height - (padding * 2));
  final scale = min(
    availableWidth / sourceRect.width,
    availableHeight / sourceRect.height,
  );
  final offset = Offset(
    (size.width - (sourceRect.width * scale)) / 2 - (sourceRect.left * scale),
    (size.height - (sourceRect.height * scale)) / 2 - (sourceRect.top * scale),
  );

  return _TangramTransform(scale: scale, offset: offset);
}

Offset _clampTangramPosition(Offset position) {
  return Offset(
    position.dx.clamp(-180, 520).toDouble(),
    position.dy.clamp(-180, 520).toDouble(),
  );
}

Offset _snapTangramPosition(Offset position) {
  const step = 5.0;
  return _clampTangramPosition(
    Offset(
      (position.dx / step).roundToDouble() * step,
      (position.dy / step).roundToDouble() * step,
    ),
  );
}

bool _tangramPieceHitTest(_TangramPieceState piece, Offset point) {
  final path = _tangramPiecePath(piece);
  if (path.contains(point)) {
    return true;
  }

  const tolerance = 18.0;
  final polygon = _transformedTangramPolygon(piece);
  if (!path.getBounds().inflate(tolerance).contains(point)) {
    return false;
  }

  for (var i = 0; i < polygon.length; i += 1) {
    final start = polygon[i];
    final end = polygon[(i + 1) % polygon.length];
    if (_distanceToSegment(point, start, end) <= tolerance) {
      return true;
    }
  }

  return false;
}

double _distanceToSegment(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.distanceSquared;
  if (lengthSquared == 0) {
    return (point - start).distance;
  }

  final relative = point - start;
  final projection =
      ((relative.dx * segment.dx) + (relative.dy * segment.dy)) / lengthSquared;
  final clampedProjection = projection.clamp(0.0, 1.0).toDouble();
  final closest = Offset(
    start.dx + segment.dx * clampedProjection,
    start.dy + segment.dy * clampedProjection,
  );
  return (point - closest).distance;
}

Offset _screenToTangramPoint(
  Offset screenPoint,
  Size boardSize,
  Map<String, dynamic>? shape,
) {
  final sourceRect = _tangramSourceRect(shape);
  final transform = _tangramTransform(boardSize, sourceRect);
  return Offset(
    (screenPoint.dx - transform.offset.dx) / transform.scale,
    (screenPoint.dy - transform.offset.dy) / transform.scale,
  );
}

Offset _screenToTangramDelta(
  Offset screenDelta,
  Size boardSize,
  Map<String, dynamic>? shape,
) {
  final sourceRect = _tangramSourceRect(shape);
  final transform = _tangramTransform(boardSize, sourceRect);
  return Offset(
    screenDelta.dx / transform.scale,
    screenDelta.dy / transform.scale,
  );
}

Path _tangramPiecePath(_TangramPieceState piece) {
  final transformed = _transformedTangramPolygon(piece);
  final path = Path()..moveTo(transformed.first.dx, transformed.first.dy);
  for (final point in transformed.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  path.close();
  return path;
}

List<Offset> _transformedTangramPolygon(_TangramPieceState piece) {
  final rotation = piece.rotation * pi / 180;
  final cosValue = cos(rotation);
  final sinValue = sin(rotation);

  return _baseTangramPolygon(piece.kind)
      .map((point) {
        final x = piece.flipped ? -point.dx : point.dx;
        final y = point.dy;
        return Offset(
          piece.position.dx + (x * cosValue) - (y * sinValue),
          piece.position.dy + (x * sinValue) + (y * cosValue),
        );
      })
      .toList(growable: false);
}

List<Offset> _baseTangramPolygon(String kind) {
  return switch (kind) {
    'large_triangle' => const <Offset>[
      Offset(0, 0),
      Offset(140, 0),
      Offset(0, 140),
    ],
    'medium_triangle' => const <Offset>[
      Offset(0, 0),
      Offset(100, 0),
      Offset(0, 100),
    ],
    'small_triangle' => const <Offset>[
      Offset(0, 0),
      Offset(70, 0),
      Offset(0, 70),
    ],
    'square' => const <Offset>[
      Offset(0, 0),
      Offset(62, 0),
      Offset(62, 62),
      Offset(0, 62),
    ],
    'parallelogram' => const <Offset>[
      Offset(0, 0),
      Offset(88, 0),
      Offset(124, 54),
      Offset(36, 54),
    ],
    _ => const <Offset>[Offset(0, 0), Offset(60, 0), Offset(0, 60)],
  };
}

double? _asTangramDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}
