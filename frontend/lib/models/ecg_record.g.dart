part of 'ecg_record.dart';

ECGPrediction _$ECGPredictionFromJson(Map<String, dynamic> json) =>
    ECGPrediction(
      (json['cls'] as num).toInt(),
      json['label'] as String,
      (json['probability'] as num).toDouble(),
      (json['actual_class'] as num?)?.toInt(),
      json['actual_label'] as String?,
    );

Map<String, dynamic> _$ECGPredictionToJson(ECGPrediction instance) =>
    <String, dynamic>{
      'cls': instance.cls,
      'label': instance.label,
      'probability': instance.probability,
      'actual_class': instance.actualClass,
      'actual_label': instance.actualLabel,
    };

ECGRecord _$ECGRecordFromJson(Map<String, dynamic> json) => ECGRecord(
  DateTime.parse(json['timestamp'] as String),
  ECGPrediction.fromJson(json['prediction'] as Map<String, dynamic>),
  (json['signal'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
);

Map<String, dynamic> _$ECGRecordToJson(ECGRecord instance) => <String, dynamic>{
  'timestamp': instance.timestamp.toIso8601String(),
  'prediction': instance.prediction,
  'signal': instance.signal,
};

ECGStream _$ECGStreamFromJson(Map<String, dynamic> json) => ECGStream(
  (json['stream'] as List<dynamic>)
      .map((e) => ECGRecord.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ECGStreamToJson(ECGStream instance) => <String, dynamic>{
  'stream': instance.stream,
};
