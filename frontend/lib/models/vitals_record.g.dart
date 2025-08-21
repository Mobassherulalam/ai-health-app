part of 'vitals_record.dart';

VitalsPrediction _$VitalsPredictionFromJson(Map<String, dynamic> json) =>
    VitalsPrediction(
      json['risk'] as String,
      (json['probability'] as num).toDouble(),
      (json['actual_risk'] as num?)?.toInt(),
      (json['actual_prob'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$VitalsPredictionToJson(VitalsPrediction instance) =>
    <String, dynamic>{
      'risk': instance.risk,
      'probability': instance.probability,
      'actual_risk': instance.actualRisk,
      'actual_prob': instance.actualProb,
    };

VitalsData _$VitalsDataFromJson(Map<String, dynamic> json) => VitalsData(
  (json['spo2'] as num).toDouble(),
  (json['heart_rate'] as num).toDouble(),
  (json['oxygen_flow'] as num).toDouble(),
  (json['systolic_bp'] as num).toDouble(),
  (json['diastolic_bp'] as num).toDouble(),
  (json['derived_pulse_pressure'] as num).toDouble(),
  (json['derived_hrv'] as num).toDouble(),
);

Map<String, dynamic> _$VitalsDataToJson(VitalsData instance) =>
    <String, dynamic>{
      'spo2': instance.spo2,
      'heart_rate': instance.heartRate,
      'oxygen_flow': instance.oxygenFlow,
      'systolic_bp': instance.systolicBp,
      'diastolic_bp': instance.diastolicBp,
      'derived_pulse_pressure': instance.derivedPulsePressure,
      'derived_hrv': instance.derivedHrv,
    };

VitalsRecord _$VitalsRecordFromJson(Map<String, dynamic> json) => VitalsRecord(
  DateTime.parse(json['timestamp'] as String),
  VitalsPrediction.fromJson(json['prediction'] as Map<String, dynamic>),
  VitalsData.fromJson(json['vitals'] as Map<String, dynamic>),
);

Map<String, dynamic> _$VitalsRecordToJson(VitalsRecord instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp.toIso8601String(),
      'prediction': instance.prediction,
      'vitals': instance.vitals,
    };

VitalsStream _$VitalsStreamFromJson(Map<String, dynamic> json) => VitalsStream(
  (json['stream'] as List<dynamic>)
      .map((e) => VitalsRecord.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$VitalsStreamToJson(VitalsStream instance) =>
    <String, dynamic>{'stream': instance.stream};
