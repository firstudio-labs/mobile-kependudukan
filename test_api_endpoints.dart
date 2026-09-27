import 'dart:convert';
import 'dart:io';

// Script untuk test API endpoints
void main() async {
  // ENV diambil dari environment OS (tanpa flutter_dotenv) agar skrip ini bisa dijalankan sebagai pure Dart.
  // Contoh:
  //   export AUTH_API_URL="https://auth.example.com"
  //   export API_URL="https://api.example.com"
  //   export API_KEY="KORIE"
  final authApiUrl = (Platform.environment['AUTH_API_URL'] ?? '').trim();
  final apiUrl = (Platform.environment['API_URL'] ?? '').trim();
  final apiKey = (Platform.environment['API_KEY'] ?? '').trim();

  print('AUTH API URL: $authApiUrl');
  print('API URL: $apiUrl');
  print('API Key: ${apiKey.isNotEmpty ? 'Set' : 'Not Set'}');

  if (authApiUrl.isEmpty || apiUrl.isEmpty || apiKey.isEmpty) {
    print(
      'ERROR: Pastikan AUTH_API_URL, API_URL, dan API_KEY sudah di-set sebagai environment variables.',
    );
    exitCode = 2;
    return;
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  Future<HttpClientResponse> _get(String url) async {
    final uri = Uri.parse(url);
    final req = await client.getUrl(uri);
    req.headers.set('Accept', 'application/json');
    req.headers.set('X-API-Key', apiKey);
    return await req.close();
  }

  Future<String> _readBody(HttpClientResponse res) async {
    return await res.transform(utf8.decoder).join();
  }

  // Test pengumuman endpoint (tidak butuh village ID)
  print('\n=== TESTING PENGUMUMAN ===');
  try {
    final res = await _get('$authApiUrl/user/pengumuman?format=json');
    final body = await _readBody(res);

    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = json.decode(body);
      print('Response: ${json.encode(data)}');

      if (data['status'] == 'success') {
        final payload = data['data'];
        final items = payload is List
            ? payload
            : (payload is Map && payload['items'] is List)
                ? payload['items']
                : [];
        print('Pengumuman count: ${items.length}');
      }
    } else {
      print('Error: $body');
    }
  } catch (e) {
    print('Exception: $e');
  }

  // Test berita desa endpoint (dengan village ID)
  print('\n=== TESTING BERITA DESA ===');
  try {
    const villageId = 38269;
    final url =
        '$authApiUrl/user/berita-desa?format=json&villages_id=$villageId&village_id=$villageId&desa_id=$villageId';
    print('URL: $url');

    final res = await _get(url);
    final body = await _readBody(res);

    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = json.decode(body);
      print('Response: ${json.encode(data)}');

      if (data['status'] == 'success') {
        final payload = data['data'];
        final items = payload is List
            ? payload
            : (payload is Map && payload['items'] is List)
                ? payload['items']
                : [];
        print('Berita Desa count: ${items.length}');

        // Check village ID filtering
        for (var item in items) {
          if (item is Map<String, dynamic>) {
            final villageIdFromItem =
                item['village_id'] ?? item['villages_id'] ?? item['desa_id'];
            print('Item village_id: $villageIdFromItem (expected: $villageId)');
          }
        }
      }
    } else {
      print('Error: $body');
    }
  } catch (e) {
    print('Exception: $e');
  }

  // Test agenda endpoint (dengan village ID)
  print('\n=== TESTING AGENDA ===');
  try {
    const villageId = 38269;
    final url =
        '$authApiUrl/user/agenda-desa?format=json&villages_id=$villageId&village_id=$villageId&desa_id=$villageId';
    print('URL: $url');

    final res = await _get(url);
    final body = await _readBody(res);

    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = json.decode(body);
      print('Response: ${json.encode(data)}');

      if (data['status'] == 'success') {
        final payload = data['data'];
        final items = payload is List
            ? payload
            : (payload is Map && payload['items'] is List)
                ? payload['items']
                : [];
        print('Agenda count: ${items.length}');
      }
    } else {
      print('Error: $body');
    }
  } catch (e) {
    print('Exception: $e');
  }

  // Test village ID resolution (tanpa tarik /all-citizens)
  print('\n=== TESTING VILLAGE ID RESOLUTION (DETAIL BY NIK) ===');
  try {
    const testNik = '3374110101010001'; // Ganti dengan NIK yang ada di sistem
    final res = await _get('$apiUrl/api/citizens/$testNik');
    final body = await _readBody(res);

    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = json.decode(body);
      final payload = (data is Map) ? data['data'] : null;
      if (payload is Map) {
        print(
            'Found citizen with NIK $testNik, village_id: ${payload['village_id']}');
      } else {
        print('Unexpected response shape: $body');
      }
    } else {
      print('Error: $body');
    }
  } catch (e) {
    print('Exception: $e');
  }

  // Test village stats endpoint (baru)
  print('\n=== TESTING VILLAGE STATS (V2) ===');
  try {
    const villageId = 38269;
    final res = await _get('$apiUrl/api/v2/villages/$villageId/stats');
    final body = await _readBody(res);
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = json.decode(body);
      print('Response: ${json.encode(data)}');
    } else {
      print('Error: $body');
    }
  } catch (e) {
    print('Exception: $e');
  }

  client.close(force: true);
}
