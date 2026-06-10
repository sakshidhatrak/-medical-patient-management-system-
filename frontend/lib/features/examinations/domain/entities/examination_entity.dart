import 'package:equatable/equatable.dart';

class MotorEntry extends Equatable {
  final String joint;
  final String? right;
  final String? left;
  final String? notes;

  const MotorEntry({
    required this.joint,
    this.right,
    this.left,
    this.notes,
  });

  /// Auto-generates a formatted sentence for non-5/5 power.
  String get generatedText {
    final parts = <String>[];
    if (right != null && right != '5/5' && right!.isNotEmpty) {
      parts.add('Right $joint power $right');
    }
    if (left != null && left != '5/5' && left!.isNotEmpty) {
      parts.add('Left $joint power $left');
    }
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() =>
      {'joint': joint, 'right': right, 'left': left, 'notes': notes};

  factory MotorEntry.fromJson(Map<String, dynamic> j) => MotorEntry(
        joint: j['joint'] as String,
        right: j['right'] as String?,
        left:  j['left']  as String?,
        notes: j['notes'] as String?,
      );

  @override
  List<Object?> get props => [joint, right, left];
}

class ExaminationEntity extends Equatable {
  final String id;
  final String visitId;
  final String patientId;

  // Free text (always available — primary input)
  final String? generalText;
  final String? motorText;
  final String? sensoryText;
  final String? reflexesText;
  final String? cerebellarText;
  final String? specialTestsText;

  // Structured helpers
  final List<MotorEntry> motorData;
  final List<Map<String, dynamic>> sensoryData;
  final Map<String, dynamic> reflexData;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ExaminationEntity({
    required this.id,
    required this.visitId,
    required this.patientId,
    this.generalText,
    this.motorText,
    this.sensoryText,
    this.reflexesText,
    this.cerebellarText,
    this.specialTestsText,
    this.motorData = const [],
    this.sensoryData = const [],
    this.reflexData = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  ExaminationEntity copyWith({
    String? generalText,
    String? motorText,
    String? sensoryText,
    String? reflexesText,
    String? cerebellarText,
    String? specialTestsText,
    List<MotorEntry>? motorData,
    List<Map<String, dynamic>>? sensoryData,
    Map<String, dynamic>? reflexData,
  }) =>
      ExaminationEntity(
        id: id,
        visitId: visitId,
        patientId: patientId,
        generalText: generalText ?? this.generalText,
        motorText: motorText ?? this.motorText,
        sensoryText: sensoryText ?? this.sensoryText,
        reflexesText: reflexesText ?? this.reflexesText,
        cerebellarText: cerebellarText ?? this.cerebellarText,
        specialTestsText: specialTestsText ?? this.specialTestsText,
        motorData: motorData ?? this.motorData,
        sensoryData: sensoryData ?? this.sensoryData,
        reflexData: reflexData ?? this.reflexData,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [id, visitId];
}
