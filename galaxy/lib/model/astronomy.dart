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

// ── Planet positions ──────────────────────────────────────────────────────────

// Orbital elements at J2000.0 + secular rate per Julian century T.

const _kPlanetElements = <String, List<double>>{
  'mercury': [252.250906, 149474.0722491,  0.387098310, 0.20563175,  0.000020407,  7.004986, -0.0059516,  48.330893, -0.1254229,  77.456119,  0.1588643],
  'venus':   [181.979801,  58519.2130302,  0.723329820, 0.00677188, -0.000047766,  3.394662, -0.0008568,  76.679920, -0.2780559, 131.563707,  0.0048646],
  'earth':   [100.466457,  36000.7698278,  1.000001018, 0.01670862, -0.000042037,  0.0,       0.0,          0.0,       0.0,       102.937348,  0.3225557],
  'mars':    [355.433275,  19141.6964746,  1.523679342, 0.09340062,  0.000090483,  1.849726, -0.0006011,  49.558093, -0.2949846, 336.060234,  0.4438898],
  'jupiter': [ 34.351484,   3036.3027889,  5.202603191, 0.04849485,  0.000163244,  1.303270, -0.0054966, 100.464441,  0.1766828,  14.331309,  0.2155525],
  'saturn':  [ 50.077444,   1223.5110686,  9.554909596, 0.05550862, -0.000346818,  2.488878, -0.0037363, 113.665524, -0.2566649,  93.056787,  0.5665496],
  'uranus':  [314.055005,    429.8640561, 19.218446062, 0.04629590, -0.000027337,  0.773197, -0.0016869,  74.005957,  0.0741431, 173.005291,  0.0893212],
  'neptune': [304.348665,    219.8833092, 30.110386869, 0.00898809,  0.000006408,  1.769952,  0.0002257, 131.784057, -0.0061651,  48.120276,  0.0291866],
};


(double, double, double) _heliocentricEcliptic(String id, double T) {
  final el    = _kPlanetElements[id]!;
  final lDeg  = el[0] + el[1]  * T;
  final a     = el[2];
  final e     = el[3] + el[4]  * T;
  final i     = _toRad(((el[5]  + el[6]  * T) % 360 + 360) % 360);
  final om    = _toRad(((el[7]  + el[8]  * T) % 360 + 360) % 360);
  final varpi = _toRad(((el[9]  + el[10] * T) % 360 + 360) % 360);

  final M = _toRad(((lDeg - _toDeg(varpi)) % 360 + 360) % 360);
  final w = varpi - om; // argument of perihelion (rad)

  double E = M;
  for (int k = 0; k < 10; k++) { E = M + e * sin(E); }

  final v = 2 * atan2(sqrt(1 + e) * sin(E / 2), sqrt(1 - e) * cos(E / 2));
  final r = a * (1 - e * cos(E));
  final u = w + v; 

  final x = r * (cos(om) * cos(u) - sin(om) * sin(u) * cos(i));
  final y = r * (sin(om) * cos(u) + cos(om) * sin(u) * cos(i));
  final z = r * sin(u) * sin(i);
  return (x, y, z);
}

SkyPosition computePlanetPosition(
    String planetId, double lat, double lon, DateTime utc) {
  final jd  = _julianDay(utc);
  final T   = (jd - 2451545.0) / 36525.0;
  final n   = jd - 2451545.0;

  final (xp, yp, zp) = _heliocentricEcliptic(planetId, T);
  final (xe, ye, ze) = _heliocentricEcliptic('earth', T);

  // Geocentric ecliptic coordinates.
  final xg = xp - xe;
  final yg = yp - ye;
  final zg = zp - ze;

  // Rotate ecliptic → equatorial by obliquity.
  final eps = _toRad(23.439 - 0.0000004 * n);
  final xq  = xg;
  final yq  = cos(eps) * yg - sin(eps) * zg;
  final zq  = sin(eps) * yg + cos(eps) * zg;

  final ra  = atan2(yq, xq);
  final rho = sqrt(xq * xq + yq * yq + zq * zq);
  final dec = asin((zq / rho).clamp(-1.0, 1.0));

  final gmst = (6.697375 + 0.0657098242 * n +
      utc.hour + utc.minute / 60.0 + utc.second / 3600.0) % 24;
  final ha = _toRad(((gmst + lon / 15.0) % 24) * 15 - _toDeg(ra));

  final latR = _toRad(lat);
  final alt  = _toDeg(asin(
      sin(latR) * sin(dec) + cos(latR) * cos(dec) * cos(ha)));
  final az   = (_toDeg(atan2(
      -cos(dec) * sin(ha),
      cos(latR) * sin(dec) - sin(latR) * cos(dec) * cos(ha))) + 360) % 360;

  return SkyPosition(az, alt);
}
