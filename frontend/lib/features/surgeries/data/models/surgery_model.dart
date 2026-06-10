import '../../domain/entities/surgery_entity.dart';

class SurgeryModel {
  final String id;
  final String patientId;
  final String surgeryDate;
  final String? yourRole;
  final String? preOpDiagnosis;
  final String? procedure;
  final String? primarySurgeon;
  final String? assistantSurgeons;
  final String? anesthesiaType;
  final String? anesthesiologist;
  final String? implants;
  final String? intraopFindings;
  final String? otNotes;
  final String? complications;
  final String? postOpPlan;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const SurgeryModel({
    required this.id,
    required this.patientId,
    required this.surgeryDate,
    this.yourRole,
    this.preOpDiagnosis,
    this.procedure,
    this.primarySurgeon,
    this.assistantSurgeons,
    this.anesthesiaType,
    this.anesthesiologist,
    this.implants,
    this.intraopFindings,
    this.otNotes,
    this.complications,
    this.postOpPlan,
    this.status = 'draft',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory SurgeryModel.fromJson(Map<String, dynamic> j) => SurgeryModel(
        id: j['id'] as String,
        patientId: j['patient_id'] as String,
        surgeryDate: j['surgery_date'] as String,
        yourRole: j['your_role'] as String?,
        preOpDiagnosis: j['pre_op_diagnosis'] as String?,
        procedure: j['procedure'] as String?,
        primarySurgeon: j['primary_surgeon'] as String?,
        assistantSurgeons: j['assistant_surgeons'] as String?,
        anesthesiaType: j['anesthesia_type'] as String?,
        anesthesiologist: j['anesthesiologist'] as String?,
        implants: j['implants'] as String?,
        intraopFindings: j['intraop_findings'] as String?,
        otNotes: j['ot_notes'] as String?,
        complications: j['complications'] as String?,
        postOpPlan: j['post_op_plan'] as String?,
        status: j['status'] as String? ?? 'draft',
        createdAt: j['created_at'] as String,
        updatedAt: j['updated_at'] as String,
        createdBy: j['created_by'] as String?,
        updatedBy: j['updated_by'] as String?,
      );

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'patient_id': patientId,
        'surgery_date': surgeryDate,
        'your_role': yourRole,
        'pre_op_diagnosis': preOpDiagnosis,
        'procedure': procedure,
        'primary_surgeon': primarySurgeon,
        'assistant_surgeons': assistantSurgeons,
        'anesthesia_type': anesthesiaType,
        'anesthesiologist': anesthesiologist,
        'implants': implants,
        'intraop_findings': intraopFindings,
        'ot_notes': otNotes,
        'complications': complications,
        'post_op_plan': postOpPlan,
        'status': status,
      };

  SurgeryEntity toEntity() => SurgeryEntity(
        id: id,
        patientId: patientId,
        surgeryDate: DateTime.parse(surgeryDate),
        yourRole: yourRole,
        preOpDiagnosis: preOpDiagnosis,
        procedure: procedure,
        primarySurgeon: primarySurgeon,
        assistantSurgeons: assistantSurgeons,
        anesthesiaType: anesthesiaType,
        anesthesiologist: anesthesiologist,
        implants: implants,
        intraopFindings: intraopFindings,
        otNotes: otNotes,
        complications: complications,
        postOpPlan: postOpPlan,
        status: status,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
        createdBy: createdBy,
        updatedBy: updatedBy,
      );

  factory SurgeryModel.fromEntity(SurgeryEntity e) => SurgeryModel(
        id: e.id,
        patientId: e.patientId,
        surgeryDate: e.surgeryDate.toIso8601String(),
        yourRole: e.yourRole,
        preOpDiagnosis: e.preOpDiagnosis,
        procedure: e.procedure,
        primarySurgeon: e.primarySurgeon,
        assistantSurgeons: e.assistantSurgeons,
        anesthesiaType: e.anesthesiaType,
        anesthesiologist: e.anesthesiologist,
        implants: e.implants,
        intraopFindings: e.intraopFindings,
        otNotes: e.otNotes,
        complications: e.complications,
        postOpPlan: e.postOpPlan,
        status: e.status,
        createdAt: e.createdAt.toIso8601String(),
        updatedAt: e.updatedAt.toIso8601String(),
        createdBy: e.createdBy,
        updatedBy: e.updatedBy,
      );
}
