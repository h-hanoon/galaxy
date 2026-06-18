import 'dart:math';
import 'package:flutter/material.dart';

const double _kVirtualSize = 2400;
const int _kStarCount = 300;

class _Star {
  final double x, y, radius, opacity;
  const _Star(this.x, this.y, this.radius, this.opacity);
}

final List<_Star> _stars = () {
  final rng = Random(42);
  return List.generate(_kStarCount, (_) => _Star(
    rng.nextDouble() * _kVirtualSize,
    rng.nextDouble() * _kVirtualSize,
    rng.nextDouble() * 2.0 + 0.5,
    rng.nextDouble() * 0.5 + 0.5,
  ));
}();

class StarFieldPainter extends CustomPainter {
  final Offset offset;

  const StarFieldPainter(this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060618),
    );

    final paint = Paint()..isAntiAlias = true;
    for (final s in _stars) {
      final x = (s.x - offset.dx) % _kVirtualSize;
      final y = (s.y - offset.dy) % _kVirtualSize;
      if (x < size.width + s.radius && y < size.height + s.radius) {
        paint.color = Colors.white.withValues(alpha: s.opacity);
        canvas.drawCircle(Offset(x, y), s.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(StarFieldPainter old) => old.offset != offset;
}
