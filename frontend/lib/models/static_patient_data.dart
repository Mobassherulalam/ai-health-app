class StaticPatientData {
  final double weight;
  final double height;
  final double bmi;

  StaticPatientData({
    required this.weight,
    required this.height,
    required this.bmi,
  });

  factory StaticPatientData.fromJson(Map<String, dynamic> json) {
    return StaticPatientData(
      weight: json['weight']?.toDouble() ?? 0.0,
      height: json['height']?.toDouble() ?? 0.0,
      bmi: json['bmi']?.toDouble() ?? 0.0,
    );
  }
} 