import 'package:json_annotation/json_annotation.dart';
part 'vitals_record.g.dart';

@JsonSerializable()
class VitalsPrediction {
  final String risk;
  final double probability;
  @JsonKey(name: 'actual_risk') final int? actualRisk;
  @JsonKey(name: 'actual_prob') final double? actualProb;

  VitalsPrediction(this.risk, this.probability, this.actualRisk, this.actualProb);

  factory VitalsPrediction.fromJson(Map<String, dynamic> json) =>
      _$VitalsPredictionFromJson(json);
  Map<String, dynamic> toJson() => _$VitalsPredictionToJson(this);
}

@JsonSerializable()
class VitalsData {
  final double spo2;
  @JsonKey(name: 'heart_rate') final double heartRate;
  @JsonKey(name: 'oxygen_flow') final double oxygenFlow;
  @JsonKey(name: 'systolic_bp') final double systolicBp;
  @JsonKey(name: 'diastolic_bp') final double diastolicBp;
  @JsonKey(name: 'derived_pulse_pressure') final double derivedPulsePressure;
  @JsonKey(name: 'derived_hrv') final double derivedHrv;

  VitalsData(this.spo2, this.heartRate, this.oxygenFlow, this.systolicBp,
      this.diastolicBp, this.derivedPulsePressure, this.derivedHrv);

  factory VitalsData.fromJson(Map<String, dynamic> json) =>
      _$VitalsDataFromJson(json);
  Map<String, dynamic> toJson() => _$VitalsDataToJson(this);
}

@JsonSerializable()
class VitalsRecord {
  final DateTime timestamp;
  final VitalsPrediction prediction;
  final VitalsData vitals;

  VitalsRecord(this.timestamp, this.prediction, this.vitals);

  factory VitalsRecord.fromJson(Map<String, dynamic> json) =>
      _$VitalsRecordFromJson(json);
  Map<String, dynamic> toJson() => _$VitalsRecordToJson(this);
}

@JsonSerializable()
class VitalsStream {
  final List<VitalsRecord> stream;
  VitalsStream(this.stream);

  factory VitalsStream.fromJson(Map<String, dynamic> json) =>
      _$VitalsStreamFromJson(json);
  Map<String, dynamic> toJson() => _$VitalsStreamToJson(this);
} 