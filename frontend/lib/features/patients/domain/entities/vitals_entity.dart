import 'package:equatable/equatable.dart';

class VitalsEntity extends Equatable {
  final String patientId;
  final double? heightCm;
  final double? weightKg;
  final String? bloodPressure; // e.g. "120/80 mmHg"
  final double? sugarLevel;   // mg/dL
  final int? pulseRate;        // bpm
  final double? oxygenLevel;  // SpO2 %
  final double? temperature;  // °C
  final DateTime recordedAt;

  const VitalsEntity({
    required this.patientId,
    this.heightCm,
    this.weightKg,
    this.bloodPressure,
    this.sugarLevel,
    this.pulseRate,
    this.oxygenLevel,
    this.temperature,
    required this.recordedAt,
  });

  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final hm = heightCm! / 100;
    return weightKg! / (hm * hm);
  }

  @override
  List<Object?> get props => [
        patientId,
        heightCm,
        weightKg,
        bloodPressure,
        sugarLevel,
        pulseRate,
        oxygenLevel,
        temperature,
        recordedAt,
      ];
}
