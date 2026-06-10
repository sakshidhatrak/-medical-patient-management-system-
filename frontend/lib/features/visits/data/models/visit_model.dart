import '../../domain/entities/visit_entity.dart';

class VisitModel {
  final String id;
  final String patientId;
  final String visitDate;
  final String visitType;
  final String? complaints;
  final String? examination;
  final String? clinicalImpression;
  final String? plan;
  final String? notes;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const VisitModel({
    required this.id,
    required this.patientId,
    required this.visitDate,
    this.visitType = 'opd',
    this.complaints,
    this.examination,
    this.clinicalImpression,
    this.plan,
    this.notes,
    this.status = 'draft',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory VisitModel.fromJson(Map<String, dynamic> j) => VisitModel(
        id: j['id'] as String,
        patientId: j['patient_id'] as String,
        visitDate: j['visit_date'] as String,
        visitType: j['visit_type'] as String? ?? 'opd',
        complaints: j['complaints'] as String?,
        examination: j['examination'] as String?,
        clinicalImpression: j['clinical_impression'] as String?,
        plan: j['plan'] as String?,
        notes: j['notes'] as String?,
        status: j['status'] as String? ?? 'draft',
        createdAt: j['created_at'] as String,
        updatedAt: j['updated_at'] as String,
        createdBy: j['created_by'] as String?,
        updatedBy: j['updated_by'] as String?,
      );

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'patient_id': patientId,
        'visit_date': visitDate,
        'visit_type': visitType,
        'complaints': complaints,
        'examination': examination,
        'clinical_impression': clinicalImpression,
        'plan': plan,
        'notes': notes,
        'status': status,
      };

  VisitEntity toEntity() => VisitEntity(
        id: id,
        patientId: patientId,
        visitDate: DateTime.parse(visitDate),
        visitType: VisitTypeX.fromValue(visitType),
        complaints: complaints,
        examination: examination,
        clinicalImpression: clinicalImpression,
        plan: plan,
        notes: notes,
        status: status,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
        createdBy: createdBy,
        updatedBy: updatedBy,
      );

  factory VisitModel.fromEntity(VisitEntity e) => VisitModel(
        id: e.id,
        patientId: e.patientId,
        visitDate: e.visitDate.toIso8601String(),
        visitType: e.visitType.value,
        complaints: e.complaints,
        examination: e.examination,
        clinicalImpression: e.clinicalImpression,
        plan: e.plan,
        notes: e.notes,
        status: e.status,
        createdAt: e.createdAt.toIso8601String(),
        updatedAt: e.updatedAt.toIso8601String(),
        createdBy: e.createdBy,
        updatedBy: e.updatedBy,
      );
}
