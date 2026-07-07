import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sky_provider.dart';
import '../ui/star_field.dart';
import '../ui/body_detail.dart';

class SensorTrackerApp extends StatelessWidget {
  const SensorTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final sky = context.watch<SkyProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF060618),
      body: Stack(
        children: [
          GestureDetector(
            onTapUp: (details) =>
                _onCanvasTap(context, details.localPosition, sky),
            child: CustomPaint(
              painter: StarFieldPainter(
                sky.starOffset,
                sunVirtual:            sky.sunVirtual,
                moonVirtual:           sky.moonVirtual,
                moonPhase:             sky.moonPhase,
                planetVirtuals:        sky.planetVirtuals,
                constellationVirtuals: sky.constellationVirtuals,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          if (sky.targetBody != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GuideArrowPainter(
                    deviceOffset:  sky.starOffset,
                    targetVirtual: sky.targetVirtual,
                    arrowColor:    _bodyColor(sky.targetBody!),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildChip(sky, 'Sun',  Icons.wb_sunny,        Colors.amber,             'sun'),
                  const SizedBox(width: 10),
                  _buildChip(sky, 'Moon', Icons.nightlight_round, const Color(0xFFB0BEC5), 'moon'),
                  ...kVisiblePlanets.map((id) => Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: _buildChip(
                      sky,
                      '${id[0].toUpperCase()}${id.substring(1)}',
                      Icons.circle,
                      planetColor(id),
                      id,
                    ),
                  )),
                  ...['Orion', 'Ursa Major', 'Cassiopeia'].map((name) => Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: _buildConstellationChip(sky, name),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onCanvasTap(BuildContext context, Offset tapPos, SkyProvider sky) {
    final size = MediaQuery.of(context).size;
    const hitRadius = 44.0;

    if (sky.sunVirtual != null &&
        (tapPos - skyToScreen(sky.sunVirtual!, sky.starOffset, size)).distance < hitRadius) {
      _showBodyDetail(context, 'sun');
      return;
    }
    if (sky.moonVirtual != null &&
        (tapPos - skyToScreen(sky.moonVirtual!, sky.starOffset, size)).distance < hitRadius) {
      _showBodyDetail(context, 'moon');
      return;
    }
    for (final id in kVisiblePlanets) {
      final virt = sky.planetVirtuals[id];
      if (virt != null &&
          (tapPos - skyToScreen(virt, sky.starOffset, size)).distance < hitRadius) {
        _showBodyDetail(context, id);
        return;
      }
    }
    for (final entry in sky.constellationVirtuals.entries) {
      for (final starVirt in entry.value.stars) {
        if ((tapPos - skyToScreen(starVirt, sky.starOffset, size)).distance < hitRadius) {
          _showBodyDetail(context, entry.key);
          return;
        }
      }
    }
  }

  void _showBodyDetail(BuildContext context, String body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BodyDetailSheet(body: body),
    );
  }

  Widget _buildChip(SkyProvider sky, String label, IconData icon, Color color, String body) {
    final selected = sky.targetBody == body;
    return GestureDetector(
      onTap: () => sky.setTargetBody(selected ? null : body),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : Colors.white24,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? color : Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.white70,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstellationChip(SkyProvider sky, String name) {
    const color = Color(0xFF8EC8E8);
    final selected = sky.targetBody == name;
    return GestureDetector(
      onTap: () => sky.setTargetBody(selected ? null : name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome,
                color: selected ? color : color.withValues(alpha: 0.65),
                size: 15),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: selected ? color : color.withValues(alpha: 0.65),
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _bodyColor(String body) => switch (body) {
  'sun'         => Colors.amber,
  'moon'        => const Color(0xFFB0BEC5),
  'Orion' || 'Ursa Major' || 'Cassiopeia' => const Color(0xFF8EC8E8),
  _             => planetColor(body),
};

class _GuideArrowPainter extends CustomPainter {
  final Offset deviceOffset;
  final Offset? targetVirtual;
  final Color arrowColor;

  const _GuideArrowPainter({
    required this.deviceOffset,
    required this.targetVirtual,
    required this.arrowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (targetVirtual == null) return;

    final screenPos = skyToScreen(targetVirtual!, deviceOffset, size);
    final center    = Offset(size.width / 2, size.height / 2);

    const pad = 64.0;
    final onScreen = Rect.fromLTWH(
      pad, pad, size.width - pad * 2, size.height - pad * 2,
    ).contains(screenPos);

    if (onScreen) {
      _drawTargetRing(canvas, screenPos);
    } else {
      final angle = atan2(screenPos.dy - center.dy, screenPos.dx - center.dx);
      _drawArrow(canvas, _edgePoint(center, angle, size), angle);
    }
  }

  void _drawTargetRing(Canvas canvas, Offset pos) {
    final paint = Paint()
      ..color = arrowColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(pos, 30, paint);
    canvas.drawLine(Offset(pos.dx - 12, pos.dy), Offset(pos.dx + 12, pos.dy), paint);
    canvas.drawLine(Offset(pos.dx, pos.dy - 12), Offset(pos.dx, pos.dy + 12), paint);
  }

  Offset _edgePoint(Offset center, double angle, Size size) {
    const margin = 44.0;
    final c = cos(angle), s = sin(angle);
    double t = double.infinity;
    if (c >  1e-6) t = min(t, (size.width  - margin - center.dx) / c);
    if (c < -1e-6) t = min(t, (margin - center.dx) / c);
    if (s >  1e-6) t = min(t, (size.height - margin - center.dy) / s);
    if (s < -1e-6) t = min(t, (margin - center.dy) / s);
    return Offset(center.dx + t * c, center.dy + t * s);
  }

  void _drawArrow(Canvas canvas, Offset origin, double angle) {
    const r = 22.0;
    final tip   = origin + Offset(cos(angle) * r,              sin(angle) * r);
    final left  = origin + Offset(cos(angle + 2.6) * r * 0.6, sin(angle + 2.6) * r * 0.6);
    final right = origin + Offset(cos(angle - 2.6) * r * 0.6, sin(angle - 2.6) * r * 0.6);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = arrowColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(path, Paint()..color = arrowColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_GuideArrowPainter old) =>
      old.deviceOffset != deviceOffset ||
      old.targetVirtual != targetVirtual ||
      old.arrowColor != arrowColor;
}
