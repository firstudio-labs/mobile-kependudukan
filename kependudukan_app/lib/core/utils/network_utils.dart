import 'dart:async';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class NetworkUtils {
  /// Retry mechanism dengan exponential backoff
  static Future<http.Response> retryRequest(
    Future<http.Response> Function() request, {
    int maxRetries = NetworkConstants.maxRetries,
    Duration delay = NetworkConstants.retryDelay,
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await request();
      } catch (e) {
        attempts++;

        if (attempts >= maxRetries) {
          rethrow;
        }

        // Exponential backoff: delay * 2^attempts
        final backoffDelay = Duration(
            milliseconds: delay.inMilliseconds * (1 << (attempts - 1)));

        await Future.delayed(backoffDelay);
      }
    }

    throw Exception('Max retries exceeded');
  }

  /// Optimized HTTP client dengan connection pooling
  static http.Client createOptimizedClient() {
    return http.Client();
  }

  /// Check network quality dan adjust timeout
  static Duration getAdaptiveTimeout(bool isSlowConnection) {
    if (isSlowConnection) {
      return NetworkConstants.longTimeout;
    }
    return NetworkConstants.defaultTimeout;
  }
}
