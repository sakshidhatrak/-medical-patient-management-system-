import 'dart:convert';

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
  final String? bp;
  final String? temperature;
  final String? weight;
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
    this.bp,
    this.temperature,
    this.weight,
    this.status = 'draft',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.syncStatus = 'synced',
  });

  factory VisitModel.fromJson(Map<String, dynamic> j) {
    // Read vitals directly from flat fields (backend VisitDto returns them separately).
    // For backward compat with old SQLite data_json blobs that embedded vitals inside
    // the examination JSON, fall back to extracting from the blob if flat fields missing.
    String? bpVal         = j['bp'] as String?;
    String? temperatureVal = j['temperature'] as String?;
    String? weightVal      = j['weight'] as String?;

    String? examination = j['examination'] as String?;
    if (examination?.isNotEmpty == true) {
      try {
        final blob = jsonDecode(examination!) as Map<String, dynamic>?;
        if (blob != null) {
          bpVal          ??= blob['bp'] as String?;
          temperatureVal ??= blob['temperature'] as String?;
          weightVal      ??= blob['weight'] as String?;
        }
      } catch (_) {}
    }

    // For older API responses that returned individual columns but no examination blob,
    // rebuild the blob from legacy columns (excluding vitals which are now dedicated).
    if (examination == null || examination.isEmpty) {
      final Map<String, dynamic> rebuilt = {};
      void add(String key, String? val) {
        if (val != null && val.isNotEmpty) rebuilt[key] = val;
      }
      add('pulse',              j['pulse'] as String?);
      add('spo2',               j['spo2'] as String?);
      add('height',             j['height'] as String?);
      add('medications',        j['medications'] as String?);
      add('doctorAssigned',     j['doctorAssigned'] as String?);
      add('examGeneral',        j['examPhysical'] as String?);
      add('examNeurological',   j['examSystemic'] as String?);
      add('imaging',            j['examRadiology'] as String?);
      if (rebuilt.isNotEmpty) {
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
      bp: bpVal?.isNotEmpty == true ? bpVal : null,
      temperature: temperatureVal?.isNotEmpty == true ? temperatureVal : null,
      weight: weightVal?.isNotEmpty == true ? weightVal : null,
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
        'bp': bp,
        'temperature': temperature,
        'weight': weight,
        'status': status,
      };

  Map<String, dynamic> toFullJson() => {
        ...toApiJson(),
        'id': id,
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
        'bp': bp,
        'temperature': temperature,
        'weight': weight,
        'status': status,
      };

  VisitEntity toEntity() => VisitEntity(
        id: id,
        patientId: patientId,
        visitDate: DateTime.parse(visitDate).toLocal(),
        visitType: VisitTypeX.fromValue(visitType),
        complaints: complaints,
        examination: examination,
        clinicalImpression: clinicalImpression,
        plan: plan,
        notes: notes,
        bp: bp,
        temperature: temperature,
        weight: weight,
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
        bp: e.bp,
        temperature: e.temperature,
        weight: e.weight,
        status: e.status,
        isActive: e.isActive,
        createdAt: e.createdAt.toUtc().toIso8601String(),
        updatedAt: e.updatedAt.toUtc().toIso8601String(),
        createdBy: e.createdBy,
        updatedBy: e.updatedBy,
        syncStatus: e.syncStatus,
      );
}
