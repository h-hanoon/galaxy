import 'dart:async';
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

class _SensorTrackerAppState extends State<SensorTrackerApp> {
  Position? _currentPosition;
  AccelerometerEvent? _accelerometer;
  MagnetometerEvent? _magnetometer;
  SkyObjects? _skyObjects;
  String? _skyError;

  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

  @override
  void initState() {
    super.initState();
    _initGPS();
    _initHardwareSensors();
    _loadSkyObjects();
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
    });
  }

  void _initHardwareSensors() {
    _accelSubscription =
        accelerometerEventStream().listen((AccelerometerEvent event) {
      setState(() => _accelerometer = event);
    });

    _magSubscription =
        magnetometerEventStream().listen((MagnetometerEvent event) {
      setState(() => _magnetometer = event);
    });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _accelSubscription?.cancel();
    _magSubscription?.cancel();
    super.dispose();
  }

  Offset get _starOffset {
    if (_accelerometer == null) return Offset.zero;
    const sensitivity = 20.0;
    return Offset(
      (_accelerometer!.x * sensitivity) % 2400,
      (_accelerometer!.y * sensitivity) % 2400,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060618),
      body: Stack(
        children: [
          CustomPaint(
            painter: StarFieldPainter(_starOffset),
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
