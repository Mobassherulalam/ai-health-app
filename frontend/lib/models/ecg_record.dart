import 'package:json_annotation/json_annotation.dart';
part 'ecg_record.g.dart';

@JsonSerializable()
class ECGPrediction {
  final int cls;
  final String label;
  final double probability;
  @JsonKey(name: 'actual_class') final int? actualClass;
  @JsonKey(name: 'actual_label') final String? actualLabel;

  ECGPrediction(this.cls, this.label, this.probability,
      this.actualClass, this.actualLabel);

  factory ECGPrediction.fromJson(Map<String, dynamic> json) =>
      _$ECGPredictionFromJson(json);
  Map<String, dynamic> toJson() => _$ECGPredictionToJson(this);
}

@JsonSerializable()
class ECGRecord {
  final DateTime timestamp;
  final ECGPrediction prediction;
  final List<double> signal;

  ECGRecord(this.timestamp, this.prediction, this.signal);

  factory ECGRecord.fromJson(Map<String, dynamic> json) =>
      _$ECGRecordFromJson(json);
  Map<String, dynamic> toJson() => _$ECGRecordToJson(this);
}

@JsonSerializable()
class ECGStream {
  final List<ECGRecord> stream;
  ECGStream(this.stream);

  factory ECGStream.fromJson(Map<String, dynamic> json) =>
      _$ECGStreamFromJson(json);
  Map<String, dynamic> toJson() => _$ECGStreamToJson(this);
} 