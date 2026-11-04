import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/diagnostic_report.dart';

class DiagnosticApi {
  Future<Map<String, dynamic>> detectFrame(File image) async {
    if (!await image.exists()) throw Exception('Camera frame could not be found.');
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/detect-frame');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', image.path));
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 10));
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw Exception('The live scan server returned an unreadable response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map ? (decoded['detail'] ?? 'Frame analysis failed') : 'Frame analysis failed';
        throw Exception(message.toString());
      }
      if (decoded is! Map<String, dynamic>) throw Exception('Unexpected live scan response.');
      return decoded;
    } on SocketException {
      throw Exception('Cannot reach the AI Car Doctor server. Check the API address and network.');
    } on TimeoutException {
      throw Exception('Live frame analysis timed out.');
    } on http.ClientException catch (e) {
      throw Exception('Live frame request failed: ${e.message}');
    }
  }

  Future<DiagnosticReport> diagnose(
    File image, {
    String? make,
    String? model,
    String? year,
  }) async {
    if (!await image.exists()) {
      throw Exception('The selected image could not be found. Please choose it again.');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/diagnose');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', image.path));
    if (make?.trim().isNotEmpty == true) request.fields['vehicle_make'] = make!.trim();
    if (model?.trim().isNotEmpty == true) request.fields['vehicle_model'] = model!.trim();
    if (year?.trim().isNotEmpty == true) request.fields['vehicle_year'] = year!.trim();

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 30));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw Exception('The server returned an unreadable response. Check that the API is running.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map
            ? (decoded['detail'] ?? 'Inspection failed')
            : 'Inspection failed (HTTP ${response.statusCode})';
        throw Exception(message.toString());
      }
      if (decoded is! Map<String, dynamic>) {
        throw Exception('The server returned an unexpected response format.');
      }
      return DiagnosticReport.fromJson(decoded);
    } on SocketException {
      throw Exception('Cannot reach the AI Car Doctor server. Check the API address, Wi-Fi, and firewall.');
    } on TimeoutException {
      throw Exception('The inspection request timed out. Check the server and try again.');
    } on http.ClientException catch (e) {
      throw Exception('Network request failed: ${e.message}');
    }
  }
}
