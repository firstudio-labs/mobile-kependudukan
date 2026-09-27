import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class NetworkTest {
  /// Test basic internet connectivity
  static Future<bool> testBasicConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (e) {
      print('Basic connectivity test failed: ${e.message}');
      if (e.osError != null) {
        print('OS Error Code: ${e.osError!.errorCode}');
        print('OS Error Message: ${e.osError!.message}');
      }
      return false;
    }
  }

  /// Test specific endpoint connectivity
  static Future<bool> testEndpointConnectivity(String url) async {
    try {
      print('Testing endpoint: $url');

      final client = http.Client();
      final response = await client
          .get(Uri.parse(url))
          .timeout(NetworkConstants.shortTimeout);
      client.close();

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body.substring(0, 200)}...');

      return response.statusCode < 500;
    } catch (e) {
      print('Endpoint test failed: $e');
      if (e is SocketException) {
        print('Socket Error: ${e.message}');
        if (e.osError != null) {
          print('OS Error Code: ${e.osError!.errorCode}');
          print('OS Error Message: ${e.osError!.message}');
        }
      } else if (e.toString().contains('TimeoutException')) {
        print('Timeout Error: $e');
      }
      return false;
    }
  }

  /// Test API endpoints
  static Future<void> testAllEndpoints() async {
    print('=== Network Connectivity Test ===');

    // Test basic connectivity
    print('\n1. Testing basic internet connectivity...');
    final basicConnectivity = await testBasicConnectivity();
    print('Basic connectivity: ${basicConnectivity ? "SUCCESS" : "FAILED"}');

    if (!basicConnectivity) {
      print(
          '❌ Basic internet connectivity failed. Check your network connection.');
      return;
    }

    // Test API endpoints
    print('\n2. Testing API endpoints...');

    final authUrl = AppConstants.authApiUrl;
    if (authUrl.isNotEmpty) {
      print('Testing auth API: $authUrl');
      final authConnectivity = await testEndpointConnectivity(authUrl);
      print(
          'Auth API connectivity: ${authConnectivity ? "SUCCESS" : "FAILED"}');
    }

    final apiUrl = AppConstants.goBaseUrl;
    if (apiUrl.isNotEmpty) {
      print('Testing main API: $apiUrl');
      final apiConnectivity = await testEndpointConnectivity(apiUrl);
      print('Main API connectivity: ${apiConnectivity ? "SUCCESS" : "FAILED"}');
    }

    print('\n=== Test Complete ===');
  }
}
