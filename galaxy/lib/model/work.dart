import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'astronomy.dart';

class SensorTrackerApp extends StatefulWidget {
  const SensorTrackerApp({super.key});

  @override
  State<SensorTrackerApp> createState() => _SensorTrackerAppState();
}

class _SensorTrackerAppState extends State<SensorTrackerApp> {
  Position? _currentPosition;
  AccelerometerEvent? _accelerometer;
  MagnetometerEvent? _magnetometer;
  List<String>? _bodies;
  String? _bodiesError;

  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

  @override
  void initState() {
    super.initState();
    _initGPS();
    _initHardwareSensors();
    _loadBodies();
  }

  Future<void> _loadBodies() async {
    try {
      final bodies = await fetchBodies();
      setState(() => _bodies = bodies);
    } catch (e) {
      setState(() => _bodiesError = e.toString());
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
    _accelSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      setState(() => _accelerometer = event);
    });

    _magSubscription = magnetometerEventStream().listen((MagnetometerEvent event) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Tracker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Celestial Bodies', style: Theme.of(context).textTheme.titleMedium),
            if (_bodiesError != null)
              Text('Error: $_bodiesError', style: const TextStyle(color: Colors.red))
            else if (_bodies == null)
              const Text('Loading bodies...')
            else
              Text(_bodies!.join(', ')),
            const Divider(height: 32),
            Text('GPS', style: Theme.of(context).textTheme.titleMedium),
            Text(_currentPosition == null
                ? 'Waiting for location...'
                : 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\n'
                  'Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}\n'
                  'Alt: ${_currentPosition!.altitude.toStringAsFixed(1)} m'),
            const Divider(height: 32),
            Text('Accelerometer', style: Theme.of(context).textTheme.titleMedium),
            Text(_accelerometer == null
                ? 'Waiting for accelerometer...'
                : 'X: ${_accelerometer!.x.toStringAsFixed(3)}\n'
                  'Y: ${_accelerometer!.y.toStringAsFixed(3)}\n'
                  'Z: ${_accelerometer!.z.toStringAsFixed(3)}'),
            const Divider(height: 32),
            Text('Magnetometer', style: Theme.of(context).textTheme.titleMedium),
            Text(_magnetometer == null
                ? 'Waiting for magnetometer...'
                : 'X: ${_magnetometer!.x.toStringAsFixed(3)}\n'
                  'Y: ${_magnetometer!.y.toStringAsFixed(3)}\n'
                  'Z: ${_magnetometer!.z.toStringAsFixed(3)}'),
          ],
        ),
      ),
    );
  }
}
