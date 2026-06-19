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

// px per degree — lower = less movement per degree of rotation (less jitter).
const double _kAzSensitivity  = _kVirtualSize / 520.0;  // was /360 ≈ 6.7 → now ≈ 4.6
const double _kAltSensitivity = _kVirtualSize / 160.0;  // was /110 ≈ 21.8 → now = 15.0

/// Maps (azimuth °, altitude °) → virtual canvas position.
Offset skyToVirtual(double azimuth, double altitude) {
  final x = azimuth * _kAzSensitivity;
  final y = ((90.0 - altitude) * _kAltSensitivity).clamp(0.0, _kVirtualSize);
  return Offset(x, y);
}

class StarFieldPainter extends CustomPainter {
  final Offset offset;
  final Offset? sunVirtual;
  final Offset? moonVirtual;
  final double moonPhase; // 0=new moon, 0.5=full moon

  const StarFieldPainter(
    this.offset, {
    this.sunVirtual,
    this.moonVirtual,
    this.moonPhase = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060618),
    );

    final paint = Paint()..isAntiAlias = true;
    for (final s in _stars) {
      final x = (s.x - offset.dx + size.width / 2) % _kVirtualSize;
      final y = (s.y - offset.dy + size.height / 2) % _kVirtualSize;
      if (x < size.width + s.radius && y < size.height + s.radius) {
        paint.color = Colors.white.withValues(alpha: s.opacity);
        canvas.drawCircle(Offset(x, y), s.radius, paint);
      }
    }

    if (sunVirtual != null) {
      _drawSun(canvas, _screenPos(sunVirtual!, size));
    }
    if (moonVirtual != null) {
      _drawMoon(canvas, _screenPos(moonVirtual!, size), moonPhase);
    }
  }

  Offset _screenPos(Offset virtual, Size size) {
    // Azimuth: use shortest-path wrap so objects near 0°/360° stay correct.
    final fullAz = 360.0 * _kAzSensitivity; // pixels per full revolution
    var dx = virtual.dx - offset.dx;
    if (dx >  fullAz / 2) dx -= fullAz;
    if (dx < -fullAz / 2) dx += fullAz;
    // Altitude: no wrapping — negative y is above screen, large y is below.
    final dy = virtual.dy - offset.dy;
    // Center the pointing direction on screen rather than the top-left corner.
    return Offset(size.width / 2 + dx, size.height / 2 + dy);
  }

  void _drawSun(Canvas canvas, Offset pos) {
    // Corona layers
    canvas.drawCircle(
      pos, 55,
      Paint()
        ..color = const Color(0xFFFFF176).withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
    canvas.drawCircle(
      pos, 36,
      Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // Disc with radial gradient
    final discRect = Rect.fromCircle(center: pos, radius: 18);
    canvas.drawCircle(
      pos, 18,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFDE7), Color(0xFFFFD600), Color(0xFFFF8F00)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(discRect),
    );
  }

  void _drawMoon(Canvas canvas, Offset pos, double phase) {
    const r = 14.0;
    const bg = Color(0xFF060618);
    const moonColor = Color(0xFFCCCCBB);

    // Subtle glow
    canvas.drawCircle(
      pos, r + 7,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Clip all phase drawing to the moon disc
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: pos, radius: r)));

    // Full lit disc
    canvas.drawCircle(pos, r, Paint()..color = moonColor);

    if (phase < 0.02 || phase > 0.98) {
      // New moon — all dark
      canvas.drawCircle(pos, r, Paint()..color = bg);
    } else {
      // termXRadius: wide near new/full, zero at quarters
      final termXRadius = r * cos(phase * 2 * pi).abs();
      final termRect = Rect.fromCenter(
          center: pos, width: termXRadius * 2, height: r * 2);

      if (phase < 0.5) {
        // Waxing — shadow on left
        canvas.drawRect(
          Rect.fromLTWH(pos.dx - r, pos.dy - r, r, r * 2),
          Paint()..color = bg,
        );
        // phase < 0.25: terminator bulges right → extra dark ellipse
        // phase > 0.25: terminator bulges left  → restore lit ellipse
        canvas.drawOval(
          termRect,
          Paint()..color = phase < 0.25 ? bg : moonColor,
        );
      } else {
        // Waning — shadow on right
        canvas.drawRect(
          Rect.fromLTWH(pos.dx, pos.dy - r, r, r * 2),
          Paint()..color = bg,
        );
        // phase < 0.75: terminator bulges left → restore lit ellipse
        // phase > 0.75: terminator bulges right → extra dark ellipse
        canvas.drawOval(
          termRect,
          Paint()..color = phase < 0.75 ? moonColor : bg,
        );
      }
    }

    canvas.restore();

    // Thin rim highlight
    canvas.drawCircle(
      pos, r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(StarFieldPainter old) =>
      old.offset != offset ||
      old.sunVirtual != sunVirtual ||
      old.moonVirtual != moonVirtual ||
      old.moonPhase != moonPhase;
}
