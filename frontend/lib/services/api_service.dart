import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ecg_record.dart';
import '../models/vitals_record.dart';

class ApiService {
  final String baseUrl;
  const ApiService(this.baseUrl);

  Future<List<ECGRecord>> fetchEcg(int length) async {
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/simulate/ecg?length=$length'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) throw Exception('ECG ${response.statusCode}');
      return ECGStream.fromJson(json.decode(response.body)).stream;
    } finally {
      client.close();
    }
  }

  Future<List<VitalsRecord>> fetchVitals(int length) async {
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/simulate/vitals?length=$length'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) throw Exception('Vitals ${response.statusCode}');
      return VitalsStream.fromJson(json.decode(response.body)).stream;
    } finally {
      client.close();
    }
  }
}