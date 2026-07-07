import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'model/sky_provider.dart';
import 'model/work.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SkyProvider(),
      child: const MaterialApp(home: SensorTrackerApp()),
    ),
  );
}
