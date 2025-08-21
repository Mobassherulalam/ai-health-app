class DynamicHealthData {
  final int spo2;
  final int heartRate;
  final List<double> ecg;
  final double oxygenFlow;
  final String bloodPressure;
  final DateTime timestamp;

  DynamicHealthData({
    required this.spo2,
    required this.heartRate,
    required this.ecg,
    required this.oxygenFlow,
    required this.bloodPressure,
    required this.timestamp,
  });

  factory DynamicHealthData.fromJson(Map<String, dynamic> json) {
    return DynamicHealthData(
      spo2: json['spo2'] ?? 0,
      heartRate: json['heartRate'] ?? 0,
      ecg: List<double>.from(json['ecg'] ?? []),
      oxygenFlow: json['oxygenFlow']?.toDouble() ?? 0.0,
      bloodPressure: json['bloodPressure'] ?? 'N/A',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
} 