import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/medicine.dart';
import '../models/dose.dart';
import 'dart:typed_data';
// ignore: unused_import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  // Using 127.0.0.1 for local Chrome development on port 8080
  static const String baseUrl = 'http://127.0.0.1:8080';

  final http.Client _client = http.Client();

  Map<String, String> get _headers {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Prescription Scan ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> scanPrescription(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/prescriptions/scan'),
    )..headers.addAll(_headers);
    
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _checkStatus(response);
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> scanPrescriptionBytes(Uint8List bytes) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/prescriptions/scan'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes,
          filename: 'prescription.jpg'), // [cite: 91]
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _checkStatus(response);
    return json.decode(response.body);
  }

  // ─── Medicines ───────────────────────────────────────────────────────────────

  Future<List<Medicine>> getMedicines() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/medicines'),
      headers: _headers,
    );
    _checkStatus(response);
    final List data = json.decode(response.body);
    return data.map((j) => Medicine.fromJson(j)).toList();
  }

  Future<Medicine> createMedicine(Medicine medicine) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/medicines'),
      headers: _headers,
      body: json.encode(medicine.toJson()),
    );
    _checkStatus(response);
    return Medicine.fromJson(json.decode(response.body));
  }

  Future<Medicine> updateMedicine(int id, Map<String, dynamic> updates) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/api/medicines/$id'),
      headers: _headers,
      body: json.encode(updates),
    );
    _checkStatus(response);
    return Medicine.fromJson(json.decode(response.body));
  }

  Future<void> deleteMedicine(int id) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/medicines/$id'),
      headers: _headers,
    );
    _checkStatus(response);
  }

  // ─── Doses ───────────────────────────────────────────────────────────────────

  Future<List<TodayDose>> getTodayDoses() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/doses/today'),
      headers: _headers,
    );
    _checkStatus(response);
    final List data = json.decode(response.body);
    return data.map((j) => TodayDose.fromJson(j)).toList();
  }

  Future<Map<String, dynamic>> logDose({
    required int medicineId,
    required String scheduledTime,
    required bool taken,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/doses/log'),
      headers: _headers,
      body: json.encode({
        'medicine_id': medicineId,
        'scheduled_time': scheduledTime,
        'taken': taken,
      }),
    );
    _checkStatus(response);
    return json.decode(response.body);
  }

  Future<List<Map<String, dynamic>>> getDoseHistory({
    int? medicineId,
    int days = 7,
  }) async {
    var url = '$baseUrl/api/doses/history?days=$days';
    if (medicineId != null) url += '&medicine_id=$medicineId';
    final response = await _client.get(Uri.parse(url), headers: _headers);
    _checkStatus(response);
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  Future<List<Map<String, dynamic>>> getStats() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/doses/stats'),
      headers: _headers,
    );
    _checkStatus(response);
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        _tryParseError(response.body),
      );
    }
  }

  String _tryParseError(String body) {
    try {
      final j = json.decode(body);
      return j['detail'] ?? body;
    } catch (_) {
      return body;
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
