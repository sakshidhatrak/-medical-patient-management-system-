import 'package:equatable/equatable.dart';

class DrugEntry extends Equatable {
  final String id;
  final String genericName;
  final String? brandName;
  final String? composition;
  final String? dose;
  final String? frequency;
  final String? duration;
  final String? instructions;
  final List<TaperingStep> taperingSteps;

  const DrugEntry({
    required this.id,
    required this.genericName,
    this.brandName,
    this.composition,
    this.dose,
    this.frequency,
    this.duration,
    this.instructions,
    this.taperingSteps = const [],
  });

  String get displayName =>
      brandName?.isNotEmpty == true ? brandName! : genericName;

  String get displayDosage {
    final parts = [dose, frequency, duration]
        .where((e) => e?.isNotEmpty == true)
        .join(' – ');
    return parts;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'generic_name': genericName,
        'brand_name': brandName,
        'composition': composition,
        'dose': dose,
        'frequency': frequency,
        'duration': duration,
        'instructions': instructions,
        'tapering_steps': taperingSteps.map((s) => s.toJson()).toList(),
      };

  factory DrugEntry.fromJson(Map<String, dynamic> j) => DrugEntry(
        id: j['id'] as String? ?? '',
        genericName: j['generic_name'] as String? ?? '',
        brandName: j['brand_name'] as String?,
        composition: j['composition'] as String?,
        dose: j['dose'] as String?,
        frequency: j['frequency'] as String?,
        duration: j['duration'] as String?,
        instructions: j['instructions'] as String?,
        taperingSteps: (j['tapering_steps'] as List<dynamic>?)
                ?.map((e) => TaperingStep.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  List<Object?> get props => [id, genericName, brandName, dose, frequency];
}

class TaperingStep extends Equatable {
  final String dose;
  final String duration;
  final String? instructions;

  const TaperingStep({
    required this.dose,
    required this.duration,
    this.instructions,
  });

  Map<String, dynamic> toJson() =>
      {'dose': dose, 'duration': duration, 'instructions': instructions};

  factory TaperingStep.fromJson(Map<String, dynamic> j) => TaperingStep(
        dose: j['dose'] as String,
        duration: j['duration'] as String,
        instructions: j['instructions'] as String?,
      );

  @override
  List<Object?> get props => [dose, duration];
}

class PrescriptionEntity extends Equatable {
  final String id;
  final String patientId;
  final String? visitId;
  final String? text;           // primary free text
  final List<DrugEntry> drugs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PrescriptionEntity({
    required this.id,
    required this.patientId,
    this.visitId,
    this.text,
    this.drugs = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  PrescriptionEntity copyWith({
    String? text,
    List<DrugEntry>? drugs,
  }) =>
      PrescriptionEntity(
        id: id,
        patientId: patientId,
        visitId: visitId,
        text: text ?? this.text,
        drugs: drugs ?? this.drugs,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [id, patientId, visitId];
}

class DrugMaster extends Equatable {
  final String id;
  final String genericName;
  final List<String> brandNames;
  final String? composition;
  final String? category;
  final String? defaultDose;
  final String? defaultFrequency;
  final String? defaultDuration;

  const DrugMaster({
    required this.id,
    required this.genericName,
    this.brandNames = const [],
    this.composition,
    this.category,
    this.defaultDose,
    this.defaultFrequency,
    this.defaultDuration,
  });

  factory DrugMaster.fromJson(Map<String, dynamic> j) => DrugMaster(
        id: j['id'] as String,
        genericName: j['generic_name'] as String,
        brandNames: (j['brand_names'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        composition: j['composition'] as String?,
        category: j['category'] as String?,
        defaultDose: j['default_dose'] as String?,
        defaultFrequency: j['default_frequency'] as String?,
        defaultDuration: j['default_duration'] as String?,
      );

  @override
  List<Object?> get props => [id, genericName];
}
