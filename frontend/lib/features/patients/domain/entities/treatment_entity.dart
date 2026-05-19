import 'package:equatable/equatable.dart';

enum VisitType { newVisit, followUp, emergency }

extension VisitTypeLabel on VisitType {
  String get label => switch (this) {
        VisitType.newVisit => 'New Visit',
        VisitType.followUp => 'Follow-up',
        VisitType.emergency => 'Emergency',
      };
}

class TreatmentEntity extends Equatable {
  final String patientId;
  final String chiefComplaint;
  final String? diagnosis;
  final String? treatmentPlan;
  final List<String> medications;
  final List<String> existingConditions;
  final String? doctorAssigned;
  final String? department;
  final VisitType visitType;
  final DateTime? appointmentDateTime;
  final String? notes;

  // Per-visit vitals snapshot
  final double? weightKg;
  final String? bloodPressure;
  final double? temperature;

  // Follow-up instructions
  final String? followUpInstructions;

  const TreatmentEntity({
    required this.patientId,
    required this.chiefComplaint,
    this.diagnosis,
    this.treatmentPlan,
    this.medications = const [],
    this.existingConditions = const [],
    this.doctorAssigned,
    this.department,
    this.visitType = VisitType.newVisit,
    this.appointmentDateTime,
    this.notes,
    this.weightKg,
    this.bloodPressure,
    this.temperature,
    this.followUpInstructions,
  });

  @override
  List<Object?> get props => [
        patientId,
        chiefComplaint,
        diagnosis,
        treatmentPlan,
        medications,
        existingConditions,
        doctorAssigned,
        department,
        visitType,
        appointmentDateTime,
        notes,
        weightKg,
        bloodPressure,
        temperature,
        followUpInstructions,
      ];
}
