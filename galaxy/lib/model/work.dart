import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'astronomy.dart';
import '../ui/star_field.dart';

class SensorTrackerApp extends StatefulWidget {
  const SensorTrackerApp({super.key});

  @override
  State<SensorTrackerApp> createState() => _SensorTrackerAppState();
}

// Raw sensor smoothing — separate alphas because magnetometer is far noisier.
const double _kAccelAlpha = 0.15;
const double _kMagAlpha   = 0.05;

// Second-stage smoothing on the computed angles (handles non-linearity of atan2).
const double _kAngleAlpha = 0.10;

class _SensorTrackerAppState extends State<SensorTrackerApp> {
  Position? _currentPosition;
  AccelerometerEvent? _accelerometer;
  MagnetometerEvent? _magnetometer;
  SkyObjects? _skyObjects;
  String? _skyError;

  // Smoothed sensor values used for rendering (low-pass filtered).
  double _sAccX = 0, _sAccY = 0, _sAccZ = 0;
  double _sMagX = 0, _sMagY = 0, _sMagZ = 0;
  bool _sensorsInitialized = false;

  // Second-stage smoothed output angles.
  double _smoothedAz   = 0;
  double _smoothedElev = 0;
  bool _anglesInitialized = false;

  Offset? _sunVirtual;
  Offset? _moonVirtual;
  double _moonPhase = 0.5;
  SkyPosition? _sunPos;
  SkyPosition? _moonPos;
  Timer? _celestialTimer;
  Timer? _renderTimer;

  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

  @override
  void initState() {
    super.initState();
    _initGPS();
    _initHardwareSensors();
    _loadSkyObjects();
    _celestialTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateCelestialPositions();
    });
    // Repaint canvas at ~30 fps; compute smoothed angles here, not in build.
    _renderTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) {
        _updateSmoothedAngles();
        setState(() {});
      }
    });
  }

  Future<void> _loadSkyObjects() async {
    try {
      final objects = await fetchSkyObjects();
      setState(() => _skyObjects = objects);
    } catch (e) {
      setState(() => _skyError = e.toString());
    }
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
      _accelerometer = event;
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
      _magnetometer = event;
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
    setState(() {
      _sunPos       = sunPos;
      _moonPos      = moonPos;
      _sunVirtual   = skyToVirtual(sunPos.azimuth,  sunPos.altitude);
      _moonVirtual  = skyToVirtual(moonPos.azimuth, moonPos.altitude);
      _moonPhase    = computeMoonPhase(now);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060618),
      body: Stack(
        children: [
          CustomPaint(
            painter: StarFieldPainter(
              _starOffset,
              sunVirtual:  _sunVirtual,
              moonVirtual: _moonVirtual,
              moonPhase:   _moonPhase,
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSkySection(context),
                    const Divider(height: 20, color: Colors.white12),
                    if (_sunPos != null)
                      Text('Sun  az:${_sunPos!.azimuth.toStringAsFixed(1)}°  '
                           'alt:${_sunPos!.altitude.toStringAsFixed(1)}°'),
                    if (_moonPos != null)
                      Text('Moon az:${_moonPos!.azimuth.toStringAsFixed(1)}°  '
                           'alt:${_moonPos!.altitude.toStringAsFixed(1)}°'),
                    if (_anglesInitialized)
                      Text('Device az:${_smoothedAz.toStringAsFixed(1)}°  '
                           'elev:${_smoothedElev.toStringAsFixed(1)}°'),
                    const SizedBox(height: 4),
                    Text(
                      _currentPosition == null
                          ? 'GPS: waiting...'
                          : 'GPS  ${_currentPosition!.latitude.toStringAsFixed(4)}, '
                              '${_currentPosition!.longitude.toStringAsFixed(4)}',
                    ),
                    const SizedBox(height: 4),
                    Text(_accelerometer == null
                        ? 'Accel: waiting...'
                        : 'Accel  x:${_accelerometer!.x.toStringAsFixed(2)} '
                            'y:${_accelerometer!.y.toStringAsFixed(2)} '
                            'z:${_accelerometer!.z.toStringAsFixed(2)}'),
                    const SizedBox(height: 4),
                    Text(_magnetometer == null
                        ? 'Mag: waiting...'
                        : 'Mag  x:${_magnetometer!.x.toStringAsFixed(1)} '
                            'y:${_magnetometer!.y.toStringAsFixed(1)} '
                            'z:${_magnetometer!.z.toStringAsFixed(1)}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkySection(BuildContext context) {
    final titleStyle = Theme.of(context)
        .textTheme
        .titleSmall
        ?.copyWith(color: Colors.white);

    if (_skyError != null) {
      return Text('Error: $_skyError',
          style: const TextStyle(color: Colors.redAccent));
    }

    if (_skyObjects == null) {
      return const Text('Loading sky objects...');
    }

    final obj = _skyObjects!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SkyRow(label: 'Sun', value: obj.sun, style: titleStyle),
        const SizedBox(height: 6),
        _SkyRow(label: 'Moon', value: obj.moon, style: titleStyle),
        const SizedBox(height: 6),
        Text('Planets', style: titleStyle),
        const SizedBox(height: 2),
        Text(obj.planets.join('  ·  ')),
        const SizedBox(height: 6),
        Text('Constellations', style: titleStyle),
        const SizedBox(height: 2),
        Text(obj.constellations.join('  ·  ')),
      ],
    );
  }
}

class _SkyRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;

  const _SkyRow({required this.label, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label  ', style: style),
        Text(value),
      ],
    );
  }
}
