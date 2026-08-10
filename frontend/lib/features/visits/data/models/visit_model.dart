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
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String syncStatus;

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
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.syncStatus = 'synced',
  });

  factory VisitModel.fromJson(Map<String, dynamic> j) {
    // If the backend returns individual columns instead of a combined examination
    // JSON blob (e.g. older visits or visits created via SQL), rebuild the blob.
    String? examination = j['examination'] as String?;
    if (examination == null || examination.isEmpty) {
      final Map<String, dynamic> rebuilt = {};
      void add(String key, String? val) {
        if (val != null && val.isNotEmpty) rebuilt[key] = val;
      }
      add('bp',                 j['bp'] as String?);
      add('weight',             j['weight'] as String?);
      add('temperature',        j['temperature'] as String?);
      add('pulse',              j['pulse'] as String?);
      add('spo2',               j['spo2'] as String?);
      add('height',             j['height'] as String?);
      add('medications',        j['medications'] as String?);
      add('doctorAssigned',     j['doctorAssigned'] as String?);
      add('examGeneral',        j['examPhysical'] as String?);
      add('examNeurological',   j['examSystemic'] as String?);
      add('imaging',            j['examRadiology'] as String?);
      if (rebuilt.isNotEmpty) {
        // ignore: avoid_dynamic_calls
        examination = _jsonEncode(rebuilt);
      }
    }
    return VisitModel(
      id: (j['id'] as Object).toString(),
      patientId: (j['patientId'] ?? j['patient_id'])!.toString(),
      visitDate: (j['visitDate'] ?? j['visit_date']) as String,
      visitType: (j['visitType'] ?? j['visit_type']) as String? ?? 'opd',
      complaints: j['complaints'] as String?,
      examination: examination,
      clinicalImpression: (j['clinicalImpression'] ?? j['clinical_impression']) as String?,
      plan: j['plan'] as String?,
      notes: j['notes'] as String?,
      status: j['status'] as String? ?? 'draft',
      createdAt: (j['createdAt'] ?? j['created_at']) as String,
      updatedAt: (j['updatedAt'] ?? j['updated_at']) as String,
      createdBy: (j['createdBy'] ?? j['created_by']) as String?,
      updatedBy: (j['updatedBy'] ?? j['updated_by']) as String?,
      isActive: (j['isActive'] ?? j['is_active']) as bool? ?? true,
      syncStatus: (j['syncStatus'] ?? j['sync_status']) as String? ?? 'synced',
    );
  }

  static String _jsonEncode(Map<String, dynamic> m) {
    final buf = StringBuffer('{');
    var first = true;
    m.forEach((k, v) {
      if (!first) buf.write(',');
      first = false;
      buf.write('"$k":"${(v as String).replaceAll('"', '\\"')}"');
    });
    buf.write('}');
    return buf.toString();
  }

  Map<String, dynamic> toApiJson() => {
        'clientId': id,
        'visitDate': visitDate,
        'visitType': visitType,
        'complaints': complaints,
        'examination': examination,
        'clinicalImpression': clinicalImpression,
        'plan': plan,
        'notes': notes,
        'status': status,
      };

  Map<String, dynamic> toFullJson() => {
        ...toApiJson(),
        'id': id, // toApiJson uses 'clientId'; local cache needs 'id'
        'patientId': patientId,
        'isActive': isActive,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'syncStatus': syncStatus,
      };

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
        isActive: isActive,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
        createdBy: createdBy,
        updatedBy: updatedBy,
        syncStatus: syncStatus,
      );

  factory VisitModel.fromEntity(VisitEntity e) => VisitModel(
        id: e.id,
        patientId: e.patientId,
        visitDate: e.visitDate.toUtc().toIso8601String(),
        visitType: e.visitType.value,
        complaints: e.complaints,
        examination: e.examination,
        clinicalImpression: e.clinicalImpression,
        plan: e.plan,
        notes: e.notes,
        status: e.status,
        isActive: e.isActive,
        createdAt: e.createdAt.toUtc().toIso8601String(),
        updatedAt: e.updatedAt.toUtc().toIso8601String(),
        createdBy: e.createdBy,
        updatedBy: e.updatedBy,
        syncStatus: e.syncStatus,
      );
}
