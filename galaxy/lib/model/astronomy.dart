import 'dart:convert';
import 'package:http/http.dart' as http;

const _appId = String.fromEnvironment('ASTRO_APP_ID');
const _appSecret = String.fromEnvironment('ASTRO_APP_SECRET');

Future<List<String>> fetchBodies() async {
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
  return rows.map((b) => b is Map ? b['id'].toString() : b.toString()).toList();
}
