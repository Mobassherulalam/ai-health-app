import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/static_patient_data.dart';
import '../models/dynamic_health_data.dart';

class HealthDataService {
  static const String apiUrl = 'YOUR_API_ENDPOINT';

  Future<StaticPatientData> getStaticPatientData(String patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/patient/$patientId/static'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return StaticPatientData.fromJson(data);
      } else {
        throw Exception('Failed to load static patient data');
      }
    } catch (e) {
      return StaticPatientData(weight: 75.5, height: 175.0, bmi: 24.7);
    }
  }

  Future<DynamicHealthData> getDynamicHealthData(String patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/patient/$patientId/dynamic'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DynamicHealthData.fromJson(data);
      } else {
        throw Exception('Failed to load dynamic health data');
      }
    } catch (e) {
      return DynamicHealthData(
        spo2: 98,
        heartRate: 75,
        ecg: [1.2, 1.5, 0.8, 1.1, 1.4, 0.9, 1.3],
        oxygenFlow: 2.5,
        bloodPressure: '120/80',
        timestamp: DateTime.now(),
      );
    }
  }

  // Stream of dynamic health data updates
  Stream<DynamicHealthData> streamHealthData(String patientId) async* {
    while (true) {
      yield await getDynamicHealthData(patientId);
      await Future.delayed(
        const Duration(seconds: 5),
      ); // Update every 5 seconds
    }
  }
}
