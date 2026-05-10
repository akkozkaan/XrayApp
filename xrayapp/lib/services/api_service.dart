import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String baseUrl = "https://xray-backend.vercel.app/analyze";
  static const String _backendApiKey =
      String.fromEnvironment('BACKEND_API_KEY', defaultValue: '');

// ---> THE HIDDEN WAKE-UP PING <---
  Future<void> warmUpServer() async {
    final warmupUrl = baseUrl.replaceAll('/analyze', '/warmup');
    final headers =
        _backendApiKey.isNotEmpty ? {'X-API-KEY': _backendApiKey} : {};
    try {
      // Add .catchError directly to the unawaited Future to prevent app crashes!
      http
          .get(Uri.parse(warmupUrl), headers: headers)
          .timeout(const Duration(seconds: 3))
          .catchError((error) {
        if (kDebugMode) {
          print("Warmup ping timed out (this is expected and fine!).");
        }
        return http.Response('timeout', 408);
      });
      if (kDebugMode) {
        print("Warmup ping sent to server!");
      }
    } catch (_) {
      // Silently ignore synchronous errors
    }
  }

  Future<Map<String, dynamic>> uploadXray(
      File imageFile, String mode, String lang) async {
    var request = http.MultipartRequest('POST', Uri.parse(baseUrl));

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );
    // mode will be either "chest" or "bone"
    request.fields['mode'] = mode;
    request.fields['lang'] = lang; // e.g., "en" for English, "tr" for Turkish
    if (_backendApiKey.isNotEmpty) {
      request.headers['X-API-KEY'] = _backendApiKey;
    }

    try {
      var streamedResponse = await request.send().timeout(
            const Duration(
                seconds: 45), // bumped slightly for dual-engine inference
          );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print("\n\n=== RAW VERCEL RESPONSE ===");
          print(response.body);
          print("===========================\n\n");
        }
        return json.decode(response.body);
      } else {
        return {
          "success": false,
          "error": "Server error: ${response.statusCode}"
        };
      }
    } catch (e) {
      return {"success": false, "error": "Connection timed out or failed: $e"};
    }
  }
}
