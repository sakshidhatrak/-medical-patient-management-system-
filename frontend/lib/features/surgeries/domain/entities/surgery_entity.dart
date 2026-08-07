import 'package:equatable/equatable.dart';

class SurgeryEntity extends Equatable {
  final String id;
  final String patientId;
  final DateTime surgeryDate;

  final String? yourRole;           // primary/assistant/observer
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
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String syncStatus; // 'synced' | 'pending'

  const SurgeryEntity({
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
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.syncStatus = 'synced',
  });

  String get summary =>
      procedure?.isNotEmpty == true ? procedure! : 'Surgery';

  SurgeryEntity copyWith({
    DateTime? surgeryDate,
    String? yourRole,
    String? preOpDiagnosis,
    String? procedure,
    String? primarySurgeon,
    String? assistantSurgeons,
    String? anesthesiaType,
    String? anesthesiologist,
    String? implants,
    String? intraopFindings,
    String? otNotes,
    String? complications,
    String? postOpPlan,
    String? status,
    bool? isActive,
    String? syncStatus,
  }) =>
      SurgeryEntity(
        id: id,
        patientId: patientId,
        surgeryDate: surgeryDate ?? this.surgeryDate,
        yourRole: yourRole ?? this.yourRole,
        preOpDiagnosis: preOpDiagnosis ?? this.preOpDiagnosis,
        procedure: procedure ?? this.procedure,
        primarySurgeon: primarySurgeon ?? this.primarySurgeon,
        assistantSurgeons: assistantSurgeons ?? this.assistantSurgeons,
        anesthesiaType: anesthesiaType ?? this.anesthesiaType,
        anesthesiologist: anesthesiologist ?? this.anesthesiologist,
        implants: implants ?? this.implants,
        intraopFindings: intraopFindings ?? this.intraopFindings,
        otNotes: otNotes ?? this.otNotes,
        complications: complications ?? this.complications,
        postOpPlan: postOpPlan ?? this.postOpPlan,
        status: status ?? this.status,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        createdBy: createdBy,
        updatedBy: updatedBy,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  @override
  List<Object?> get props => [id, patientId, surgeryDate, procedure, status];
}
