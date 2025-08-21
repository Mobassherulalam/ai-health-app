class BloodPressure {
  final int systolic;
  final int diastolic;
  final DateTime timestamp;

  BloodPressure({
    required this.systolic,
    required this.diastolic,
    required this.timestamp,
  });

  factory BloodPressure.fromJson(Map<String, dynamic> json) {
    return BloodPressure(
      systolic: json['systolic'] ?? 0,
      diastolic: json['diastolic'] ?? 0,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  @override
  String toString() => '$systolic/$diastolic';
}
