import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/diagnostic_report.dart';

class DiagnosticApi {
  Future<DiagnosticReport> diagnose(
    File image, {
    String? make,
    String? model,
    String? year,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/diagnose');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', image.path));
    if (make?.trim().isNotEmpty == true) request.fields['vehicle_make'] = make!.trim();
    if (model?.trim().isNotEmpty == true) request.fields['vehicle_model'] = model!.trim();
    if (year?.trim().isNotEmpty == true) request.fields['vehicle_year'] = year!.trim();

    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map ? (body['detail'] ?? 'Inspection failed') : 'Inspection failed';
      throw Exception(message.toString());
    }
    return DiagnosticReport.fromJson(body as Map<String, dynamic>);
  }
}
