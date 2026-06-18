import 'dart:convert';
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
