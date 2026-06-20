import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'astronomy.dart';
import '../ui/star_field.dart';
import '../ui/body_detail.dart';

class SensorTrackerApp extends StatefulWidget {
  const SensorTrackerApp({super.key});

  @override
  State<SensorTrackerApp> createState() => _SensorTrackerAppState();
}

const _kVisiblePlanets = [
  'mercury', 'venus', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune',
];

const double _kAccelAlpha = 0.15;
const double _kMagAlpha   = 0.05;

const double _kAngleAlpha = 0.10;

class _SensorTrackerAppState extends State<SensorTrackerApp> {
  Position? _currentPosition;

  double _sAccX = 0, _sAccY = 0, _sAccZ = 0;
  double _sMagX = 0, _sMagY = 0, _sMagZ = 0;
  bool _sensorsInitialized = false;

  double _smoothedAz   = 0;
  double _smoothedElev = 0;
  bool _anglesInitialized = false;

  Offset? _sunVirtual;
  Offset? _moonVirtual;
  double _moonPhase = 0.5;
  Map<String, Offset> _planetVirtuals = {};
  Map<String, ConstellationVirtual> _constellationVirtuals = {};
  Timer? _celestialTimer;
  Timer? _renderTimer;

  String? _targetBody;

  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

  @override
  void initState() {
    super.initState();
    _initGPS();
    _initHardwareSensors();
    _celestialTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateCelestialPositions();
    });
    _renderTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) {
        _updateSmoothedAngles();
        setState(() {});
      }
    });
  }

  Future<void> _initGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      setState(() => _currentPosition = position);
      _updateCelestialPositions();
    });
  }

  void _initHardwareSensors() {
    _accelSubscription =
        accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!_sensorsInitialized) {
        _sAccX = event.x; _sAccY = event.y; _sAccZ = event.z;
      } else {
        _sAccX += _kAccelAlpha * (event.x - _sAccX);
        _sAccY += _kAccelAlpha * (event.y - _sAccY);
        _sAccZ += _kAccelAlpha * (event.z - _sAccZ);
      }
    });

    _magSubscription =
        magnetometerEventStream().listen((MagnetometerEvent event) {
      if (!_sensorsInitialized) {
        _sMagX = event.x; _sMagY = event.y; _sMagZ = event.z;
        _sensorsInitialized = true;
      } else {
        _sMagX += _kMagAlpha * (event.x - _sMagX);
        _sMagY += _kMagAlpha * (event.y - _sMagY);
        _sMagZ += _kMagAlpha * (event.z - _sMagZ);
      }
    });
  }

  void _updateCelestialPositions() {
    final pos = _currentPosition;
    if (pos == null) return;
    final now = DateTime.now().toUtc();
    final sunPos  = computeSunPosition(pos.latitude, pos.longitude, now);
    final moonPos = computeMoonPosition(pos.latitude, pos.longitude, now);
    final planets = <String, Offset>{};
    for (final id in _kVisiblePlanets) {
      final p = computePlanetPosition(id, pos.latitude, pos.longitude, now);
      planets[id] = skyToVirtual(p.azimuth, p.altitude);
    }
    const constellationNames = ['Orion', 'Ursa Major', 'Cassiopeia'];
    final constellations = <String, ConstellationVirtual>{};
    for (final name in constellationNames) {
      final layout = computeConstellationLayout(name, pos.latitude, pos.longitude, now);
      constellations[name] = ConstellationVirtual(
        stars: layout.stars.map((s) => skyToVirtual(s.azimuth, s.altitude)).toList(),
        lines: layout.lines,
      );
    }
    setState(() {
      _sunVirtual              = skyToVirtual(sunPos.azimuth,  sunPos.altitude);
      _moonVirtual             = skyToVirtual(moonPos.azimuth, moonPos.altitude);
      _moonPhase               = computeMoonPhase(now);
      _planetVirtuals          = planets;
      _constellationVirtuals   = constellations;
    });
  }

  @override
  void dispose() {
    _celestialTimer?.cancel();
    _renderTimer?.cancel();
    _gpsSubscription?.cancel();
    _accelSubscription?.cancel();
    _magSubscription?.cancel();
    super.dispose();
  }

  void _updateSmoothedAngles() {
    if (!_sensorsInitialized) return;

    final norm = sqrt(_sAccX * _sAccX + _sAccY * _sAccY + _sAccZ * _sAccZ);
    if (norm < 0.01) return;
    final gx = _sAccX / norm, gy = _sAccY / norm, gz = _sAccZ / norm;

    final elevDeg = asin((-gz).clamp(-1.0, 1.0)) * 180.0 / pi;

    final roll  = atan2(gy, gz);
    final pitch = atan2(-gx, sqrt(gy * gy + gz * gz));
    final mx2 = _sMagX * cos(pitch) + _sMagZ * sin(pitch);
    final my2 = _sMagX * sin(roll) * sin(pitch) +
                _sMagY * cos(roll) -
                _sMagZ * sin(roll) * cos(pitch);
    final az = (atan2(-mx2, my2) * 180.0 / pi % 360 + 360) % 360;

    if (!_anglesInitialized) {
      _smoothedAz   = az;
      _smoothedElev = elevDeg;
      _anglesInitialized = true;
      return;
    }

    // Shortest-path interpolation for azimuth to avoid 0°/360° jump.
    double azDiff = az - _smoothedAz;
    if (azDiff >  180) azDiff -= 360;
    if (azDiff < -180) azDiff += 360;
    _smoothedAz   = (_smoothedAz + _kAngleAlpha * azDiff + 360) % 360;
    _smoothedElev += _kAngleAlpha * (elevDeg - _smoothedElev);
  }

  Offset get _starOffset {
    if (!_anglesInitialized) return skyToVirtual(0, 0);
    return skyToVirtual(_smoothedAz, _smoothedElev);
  }

  Offset? _targetVirtual() {
    if (_targetBody == null) return null;
    if (_targetBody == 'sun') return _sunVirtual;
    if (_targetBody == 'moon') return _moonVirtual;
    final pv = _planetVirtuals[_targetBody];
    if (pv != null) return pv;
    // Constellation: guide to the centroid of its stars.
    final cv = _constellationVirtuals[_targetBody];
    if (cv != null && cv.stars.isNotEmpty) {
      final dx = cv.stars.map((s) => s.dx).reduce((a, b) => a + b) / cv.stars.length;
      final dy = cv.stars.map((s) => s.dy).reduce((a, b) => a + b) / cv.stars.length;
      return Offset(dx, dy);
    }
    return null;
  }

  Color _bodyColor(String body) => switch (body) {
    'sun'         => Colors.amber,
    'moon'        => const Color(0xFFB0BEC5),
    'Orion' || 'Ursa Major' || 'Cassiopeia' => const Color(0xFF8EC8E8),
    _             => planetColor(body),
  };

  void _onCanvasTap(BuildContext context, Offset tapPos) {
    final size = MediaQuery.of(context).size;
    const hitRadius = 44.0;

    if (_sunVirtual != null) {
      if ((tapPos - skyToScreen(_sunVirtual!, _starOffset, size)).distance < hitRadius) {
        _showBodyDetail(context, 'sun');
        return;
      }
    }
    if (_moonVirtual != null) {
      if ((tapPos - skyToScreen(_moonVirtual!, _starOffset, size)).distance < hitRadius) {
        _showBodyDetail(context, 'moon');
        return;
      }
    }
    for (final id in _kVisiblePlanets) {
      final virt = _planetVirtuals[id];
      if (virt != null &&
          (tapPos - skyToScreen(virt, _starOffset, size)).distance < hitRadius) {
        _showBodyDetail(context, id);
        return;
      }
    }
    for (final entry in _constellationVirtuals.entries) {
      for (final starVirt in entry.value.stars) {
        if ((tapPos - skyToScreen(starVirt, _starOffset, size)).distance < hitRadius) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060618),
      body: Stack(
        children: [
          GestureDetector(
            onTapUp: (details) => _onCanvasTap(context, details.localPosition),
            child: CustomPaint(
              painter: StarFieldPainter(
                _starOffset,
                sunVirtual:            _sunVirtual,
                moonVirtual:           _moonVirtual,
                moonPhase:             _moonPhase,
                planetVirtuals:        _planetVirtuals,
                constellationVirtuals: _constellationVirtuals,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          if (_targetBody != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GuideArrowPainter(
                    deviceOffset: _starOffset,
                    targetVirtual: _targetVirtual(),
                    arrowColor: _bodyColor(_targetBody!),
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
                  _buildChip('Sun', Icons.wb_sunny, Colors.amber, 'sun'),
                  const SizedBox(width: 10),
                  _buildChip('Moon', Icons.nightlight_round,
                      const Color(0xFFB0BEC5), 'moon'),
                  ..._kVisiblePlanets.map((id) => Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: _buildChip(
                      '${id[0].toUpperCase()}${id.substring(1)}',
                      Icons.circle,
                      planetColor(id),
                      id,
                    ),
                  )),
                  ...['Orion', 'Ursa Major', 'Cassiopeia'].map((name) => Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: _buildConstellationChip(name),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstellationChip(String name) {
    const color = Color(0xFF8EC8E8);
    final selected = _targetBody == name;
    return GestureDetector(
      onTap: () => setState(() => _targetBody = selected ? null : name),
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

  Widget _buildChip(String label, IconData icon, Color color, String body) {
    final selected = _targetBody == body;
    return GestureDetector(
      onTap: () => setState(() => _targetBody = selected ? null : body),
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
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final center = Offset(size.width / 2, size.height / 2);

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
    // Triangle pointing in `angle` direction, base behind origin.
    final tip   = origin + Offset(cos(angle) * r,        sin(angle) * r);
    final left  = origin + Offset(cos(angle + 2.6) * r * 0.6, sin(angle + 2.6) * r * 0.6);
    final right = origin + Offset(cos(angle - 2.6) * r * 0.6, sin(angle - 2.6) * r * 0.6);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    // Glow
    canvas.drawPath(
      path,
      Paint()
        ..color = arrowColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Fill
    canvas.drawPath(path, Paint()..color = arrowColor);
    // Rim
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
