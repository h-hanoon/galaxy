import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'astronomy.dart';
import '../ui/star_field.dart';

const kVisiblePlanets = [
  'mercury', 'venus', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune',
];

const _kAccelAlpha = 0.15;
const _kMagAlpha   = 0.05;
const _kAngleAlpha = 0.10;

class SkyProvider extends ChangeNotifier {
  Position? _position;

  double _sAccX = 0, _sAccY = 0, _sAccZ = 0;
  double _sMagX = 0, _sMagY = 0, _sMagZ = 0;
  bool _sensorsInitialized = false;

  double _smoothedAz   = 0;
  double _smoothedElev = 0;
  bool _anglesInitialized = false;

  Offset? sunVirtual;
  Offset? moonVirtual;
  double moonPhase = 0.5;
  Map<String, Offset> planetVirtuals = {};
  Map<String, ConstellationVirtual> constellationVirtuals = {};

  String? targetBody;

  Timer? _celestialTimer;
  Timer? _renderTimer;
  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

  SkyProvider() {
    _initGPS();
    _initHardwareSensors();
    _celestialTimer = Timer.periodic(
      const Duration(minutes: 1), (_) => _updateCelestialPositions());
    _renderTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _updateSmoothedAngles();
      notifyListeners();
    });
  }

  Offset get starOffset {
    if (!_anglesInitialized) return skyToVirtual(0, 0);
    return skyToVirtual(_smoothedAz, _smoothedElev);
  }

  Offset? get targetVirtual {
    if (targetBody == null) return null;
    if (targetBody == 'sun') return sunVirtual;
    if (targetBody == 'moon') return moonVirtual;
    final pv = planetVirtuals[targetBody];
    if (pv != null) return pv;
    final cv = constellationVirtuals[targetBody];
    if (cv != null && cv.stars.isNotEmpty) {
      final dx = cv.stars.map((s) => s.dx).reduce((a, b) => a + b) / cv.stars.length;
      final dy = cv.stars.map((s) => s.dy).reduce((a, b) => a + b) / cv.stars.length;
      return Offset(dx, dy);
    }
    return null;
  }

  void setTargetBody(String? body) {
    targetBody = body;
    notifyListeners();
  }

  Future<void> _initGPS() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
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
    ).listen((pos) {
      _position = pos;
      _updateCelestialPositions();
    });
  }

  void _initHardwareSensors() {
    _accelSubscription = accelerometerEventStream().listen((event) {
      if (!_sensorsInitialized) {
        _sAccX = event.x; _sAccY = event.y; _sAccZ = event.z;
      } else {
        _sAccX += _kAccelAlpha * (event.x - _sAccX);
        _sAccY += _kAccelAlpha * (event.y - _sAccY);
        _sAccZ += _kAccelAlpha * (event.z - _sAccZ);
      }
    });

    _magSubscription = magnetometerEventStream().listen((event) {
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
    final pos = _position;
    if (pos == null) return;
    final now = DateTime.now().toUtc();

    final sunPos  = computeSunPosition(pos.latitude, pos.longitude, now);
    final moonPos = computeMoonPosition(pos.latitude, pos.longitude, now);

    final planets = <String, Offset>{};
    for (final id in kVisiblePlanets) {
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

    sunVirtual            = skyToVirtual(sunPos.azimuth,  sunPos.altitude);
    moonVirtual           = skyToVirtual(moonPos.azimuth, moonPos.altitude);
    moonPhase             = computeMoonPhase(now);
    planetVirtuals        = planets;
    constellationVirtuals = constellations;
    notifyListeners();
  }

  void _updateSmoothedAngles() {
    if (!_sensorsInitialized) return;

    final norm = sqrt(_sAccX * _sAccX + _sAccY * _sAccY + _sAccZ * _sAccZ);
    if (norm < 0.01) return;
    final gx = _sAccX / norm, gy = _sAccY / norm, gz = _sAccZ / norm;

    final elevDeg = asin((-gz).clamp(-1.0, 1.0)) * 180.0 / pi;

    final roll  = atan2(gy, gz);
    final pitch = atan2(-gx, sqrt(gy * gy + gz * gz));
    final mx2   = _sMagX * cos(pitch) + _sMagZ * sin(pitch);
    final my2   = _sMagX * sin(roll) * sin(pitch) +
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

  @override
  void dispose() {
    _celestialTimer?.cancel();
    _renderTimer?.cancel();
    _gpsSubscription?.cancel();
    _accelSubscription?.cancel();
    _magSubscription?.cancel();
    super.dispose();
  }
}
