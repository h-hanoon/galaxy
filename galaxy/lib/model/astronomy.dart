import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

const _appId = String.fromEnvironment('ASTRO_APP_ID');
const _appSecret = String.fromEnvironment('ASTRO_APP_SECRET');

class SkyObjects {
  final List<String> planets;
  final String sun;
  final String moon;
  final List<String> constellations;

  const SkyObjects({
    required this.planets,
    required this.sun,
    required this.moon,
    required this.constellations,
  });
}

// Planets in order from the Sun
const _planetOrder = [
  'mercury',
  'venus',
  'earth',
  'mars',
  'jupiter',
  'saturn',
  'uranus',
  'neptune',
];

const _selectedConstellations = ['Orion', 'Ursa Major', 'Cassiopeia'];

Future<SkyObjects> fetchSkyObjects() async {
  final credentials = base64Encode(utf8.encode('$_appId:$_appSecret'));
  final response = await http.get(
    Uri.parse('https://api.astronomyapi.com/api/v2/bodies'),
    headers: {'Authorization': 'Basic $credentials'},
  );

  if (response.statusCode != 200) {
    throw Exception('${response.statusCode}: ${response.body}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final rows = data['data']['bodies'] as List<dynamic>;

  // Normalise each entry to an (id, name) pair
  final bodyMap = <String, String>{};
  for (final b in rows) {
    if (b is Map) {
      final id = b['id']?.toString() ?? '';
      final name = b['name']?.toString() ?? id;
      if (id.isNotEmpty) bodyMap[id] = name;
    } else {
      final id = b.toString();
      bodyMap[id] = _capitalize(id);
    }
  }

  // Planets in solar-system order
  final planets = _planetOrder
      .where((id) => bodyMap.containsKey(id))
      .map((id) => bodyMap[id]!)
      .toList();

  return SkyObjects(
    planets: planets,
    sun: bodyMap['sun'] ?? 'Sun',
    moon: bodyMap['moon'] ?? 'Moon',
    constellations: _selectedConstellations,
  );
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ── Sky-position helpers ──────────────────────────────────────────────────────

class SkyPosition {
  final double azimuth;  // degrees, 0=N 90=E 180=S 270=W
  final double altitude; // degrees, -90 to +90
  const SkyPosition(this.azimuth, this.altitude);
}

double _julianDay(DateTime utc) {
  int y = utc.year;
  int m = utc.month;
  final d = utc.day +
      (utc.hour + utc.minute / 60.0 + utc.second / 3600.0) / 24.0;
  if (m <= 2) { y--; m += 12; }
  final a = y ~/ 100;
  final b = 2 - a + a ~/ 4;
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      d + b - 1524.5;
}

double _toRad(double deg) => deg * pi / 180;
double _toDeg(double rad) => rad * 180 / pi;

SkyPosition computeSunPosition(double lat, double lon, DateTime utc) {
  final n = _julianDay(utc) - 2451545.0;
  final L = (280.46 + 0.9856474 * n) % 360;
  final g = _toRad((357.528 + 0.9856003 * n) % 360);
  final lambda = _toRad(L + 1.915 * sin(g) + 0.020 * sin(2 * g));
  final epsilon = _toRad(23.439 - 0.0000004 * n);

  final sinL = sin(lambda);
  final ra = atan2(cos(epsilon) * sinL, cos(lambda));
  final dec = asin(sin(epsilon) * sinL);

  final gmst = (6.697375 + 0.0657098242 * n +
      utc.hour + utc.minute / 60.0 + utc.second / 3600.0) % 24;
  final ha = _toRad(((gmst + lon / 15.0) % 24) * 15 - _toDeg(ra));

  final latR = _toRad(lat);
  final alt = _toDeg(asin(
      sin(latR) * sin(dec) + cos(latR) * cos(dec) * cos(ha)));
  final az = (_toDeg(atan2(
      -cos(dec) * sin(ha),
      cos(latR) * sin(dec) - sin(latR) * cos(dec) * cos(ha))) + 360) % 360;
  return SkyPosition(az, alt);
}

SkyPosition computeMoonPosition(double lat, double lon, DateTime utc) {
  final n = _julianDay(utc) - 2451545.0;
  final l0 = (218.316 + 13.176396 * n) % 360;
  final M  = _toRad((134.963 + 13.064993 * n) % 360);
  final F  = _toRad((93.272  + 13.229350 * n) % 360);

  final lambda = _toRad(l0 + 6.289 * sin(M));
  final beta   = _toRad(5.128 * sin(F));
  final epsilon = _toRad(23.439 - 0.0000004 * n);

  final cb = cos(beta);
  final x = cos(lambda) * cb;
  final y = cos(epsilon) * sin(lambda) * cb - sin(epsilon) * sin(beta);
  final z = sin(epsilon) * sin(lambda) * cb + cos(epsilon) * sin(beta);

  final ra  = atan2(y, x);
  final dec = asin(z);

  final gmst = (6.697375 + 0.0657098242 * n +
      utc.hour + utc.minute / 60.0 + utc.second / 3600.0) % 24;
  final ha = _toRad(((gmst + lon / 15.0) % 24) * 15 - _toDeg(ra));

  final latR = _toRad(lat);
  final alt = _toDeg(asin(
      sin(latR) * sin(dec) + cos(latR) * cos(dec) * cos(ha)));
  final az = (_toDeg(atan2(
      -cos(dec) * sin(ha),
      cos(latR) * sin(dec) - sin(latR) * cos(dec) * cos(ha))) + 360) % 360;
  return SkyPosition(az, alt);
}

// Returns 0 = new moon, 0.5 = full moon, 1 = new moon again.
double computeMoonPhase(DateTime utc) {
  final n = _julianDay(utc) - 2451549.26; // JD of reference new moon
  final p = (n / 29.53058867) % 1.0;
  return p < 0 ? p + 1.0 : p;
}
