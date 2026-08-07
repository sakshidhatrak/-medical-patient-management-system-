import '../../domain/entities/patient_entity.dart';

class PatientModel {
  final String id;
  final String prn;
  final String firstName;
  final String lastName;
  final int? age;
  final String? dateOfBirth;
  final String? sex;
  final String? phone;
  final String? address;

  // ── Contact ──────────────────────────────────────────────────────
  final String? altPhone;
  final String? email;

  // ── ID Proof ─────────────────────────────────────────────────────
  final String? idProofType;
  final String? idProofNumber;

  // ── Registration Vitals ──────────────────────────────────────────
  final String? weight;
  final String? bloodPressure;
  final String? temperature;

  // ── History ──────────────────────────────────────────────────────
  final String? allergies;
  final String? medicalHistory;
  final String? previousHistory;

  // ── Clinical snapshot ────────────────────────────────────────────
  final String? chiefComplaint;
  final String? examGeneral;
  final String? examNeurological;
  final String? clinicalDiagnosis;
  final String? imaging;
  final String? otherInvestigations;
  final String? impression;
  final String? plan;
  final String? treatment;
  final String? treatmentNotes;
  final String? advice;

  // ── Admin ────────────────────────────────────────────────────────
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String syncStatus;

  const PatientModel({
    required this.id,
    required this.prn,
    required this.firstName,
    this.lastName = '',
    this.age,
    this.dateOfBirth,
    this.sex,
    this.phone,
    this.address,
    this.altPhone,
    this.email,
    this.idProofType,
    this.idProofNumber,
    this.weight,
    this.bloodPressure,
    this.temperature,
    this.allergies,
    this.medicalHistory,
    this.previousHistory,
    this.chiefComplaint,
    this.examGeneral,
    this.examNeurological,
    this.clinicalDiagnosis,
    this.imaging,
    this.otherInvestigations,
    this.impression,
    this.plan,
    this.treatment,
    this.treatmentNotes,
    this.advice,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.syncStatus = 'synced',
  });

  factory PatientModel.fromJson(Map<String, dynamic> j) => PatientModel(
        id: (j['id'] as Object).toString(),
        prn: j['prn'] as String? ?? '',
        firstName: (j['firstName'] ?? j['first_name']) as String,
        lastName: (j['lastName'] ?? j['last_name']) as String? ?? '',
        age: j['age'] as int?,
        dateOfBirth: (j['dateOfBirth'] ?? j['date_of_birth'])?.toString(),
        sex: j['sex'] as String?,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        altPhone: (j['altPhone'] ?? j['alt_phone']) as String?,
        email: j['email'] as String?,
        idProofType: (j['idProofType'] ?? j['id_proof_type']) as String?,
        idProofNumber: (j['idProofNumber'] ?? j['id_proof_number']) as String?,
        weight: j['weight'] as String?,
        bloodPressure: (j['bloodPressure'] ?? j['blood_pressure']) as String?,
        temperature: j['temperature'] as String?,
        allergies: j['allergies'] as String?,
        medicalHistory: (j['medicalHistory'] ?? j['medical_history']) as String?,
        previousHistory: (j['previousHistory'] ?? j['previous_history']) as String?,
        chiefComplaint: (j['chiefComplaint'] ?? j['chief_complaint']) as String?,
        examGeneral: (j['examGeneral'] ?? j['exam_general']) as String?,
        examNeurological: (j['examNeurological'] ?? j['exam_neurological']) as String?,
        clinicalDiagnosis: (j['clinicalDiagnosis'] ?? j['clinical_diagnosis']) as String?,
        imaging: j['imaging'] as String?,
        otherInvestigations: (j['otherInvestigations'] ?? j['other_investigations']) as String?,
        impression: j['impression'] as String?,
        plan: j['plan'] as String?,
        treatment: j['treatment'] as String?,
        treatmentNotes: (j['treatmentNotes'] ?? j['treatment_notes']) as String?,
        advice: j['advice'] as String?,
        notes: j['notes'] as String?,
        isActive: (j['isActive'] ?? j['is_active']) as bool? ?? true,
        createdAt: (j['createdAt'] ?? j['created_at']) as String,
        updatedAt: (j['updatedAt'] ?? j['updated_at']) as String,
        createdBy: (j['createdBy'] ?? j['created_by']) as String?,
        updatedBy: (j['updatedBy'] ?? j['updated_by']) as String?,
        syncStatus: (j['syncStatus'] ?? j['sync_status']) as String? ?? 'synced',
      );

  // Full camelCase JSON for SQLite cache.
  Map<String, dynamic> toFullJson() => {
        ...toApiJson(),
        'prn': prn,
        'isActive': isActive,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'syncStatus': syncStatus,
      };

  Map<String, dynamic> toApiJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'age': age,
        'dateOfBirth': dateOfBirth,
        'sex': sex,
        'phone': phone,
        'altPhone': altPhone,
        'email': email,
        'address': address,
        'idProofType': idProofType,
        'idProofNumber': idProofNumber,
        'weight': weight,
        'bloodPressure': bloodPressure,
        'temperature': temperature,
        'allergies': allergies,
        'medicalHistory': medicalHistory,
        'previousHistory': previousHistory,
        'chiefComplaint': chiefComplaint,
        'examGeneral': examGeneral,
        'examNeurological': examNeurological,
        'clinicalDiagnosis': clinicalDiagnosis,
        'imaging': imaging,
        'otherInvestigations': otherInvestigations,
        'impression': impression,
        'plan': plan,
        'treatment': treatment,
        'treatmentNotes': treatmentNotes,
        'advice': advice,
        'notes': notes,
      };

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'prn': prn,
        'first_name': firstName,
        'last_name': lastName,
        'age': age,
        'date_of_birth': dateOfBirth,
        'sex': sex,
        'phone': phone,
        'address': address,
        'alt_phone': altPhone,
        'email': email,
        'id_proof_type': idProofType,
        'id_proof_number': idProofNumber,
        'weight': weight,
        'blood_pressure': bloodPressure,
        'temperature': temperature,
        'allergies': allergies,
        'medical_history': medicalHistory,
        'previous_history': previousHistory,
        'chief_complaint': chiefComplaint,
        'exam_general': examGeneral,
        'exam_neurological': examNeurological,
        'clinical_diagnosis': clinicalDiagnosis,
        'imaging': imaging,
        'other_investigations': otherInvestigations,
        'impression': impression,
        'plan': plan,
        'treatment': treatment,
        'treatment_notes': treatmentNotes,
        'advice': advice,
        'notes': notes,
        'is_active': isActive,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  PatientEntity toEntity() => PatientEntity(
        id: id,
        prn: prn,
        firstName: firstName,
        lastName: lastName,
        age: age,
        dateOfBirth:
            dateOfBirth != null ? DateTime.tryParse(dateOfBirth!) : null,
        sex: sex,
        phone: phone,
        address: address,
        altPhone: altPhone,
        email: email,
        idProofType: idProofType,
        idProofNumber: idProofNumber,
        weight: weight,
        bloodPressure: bloodPressure,
        temperature: temperature,
        allergies: allergies,
        medicalHistory: medicalHistory,
        previousHistory: previousHistory,
        chiefComplaint: chiefComplaint,
        examGeneral: examGeneral,
        examNeurological: examNeurological,
        clinicalDiagnosis: clinicalDiagnosis,
        imaging: imaging,
        otherInvestigations: otherInvestigations,
        impression: impression,
        plan: plan,
        treatment: treatment,
        treatmentNotes: treatmentNotes,
        advice: advice,
        notes: notes,
        isActive: isActive,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
        createdBy: createdBy,
        updatedBy: updatedBy,
        syncStatus: syncStatus,
      );

  factory PatientModel.fromEntity(PatientEntity e) => PatientModel(
        id: e.id,
        prn: e.prn,
        firstName: e.firstName,
        lastName: e.lastName,
        age: e.age,
        dateOfBirth: e.dateOfBirth?.toIso8601String().split('T').first,
        sex: e.sex,
        phone: e.phone,
        address: e.address,
        altPhone: e.altPhone,
        email: e.email,
        idProofType: e.idProofType,
        idProofNumber: e.idProofNumber,
        weight: e.weight,
        bloodPressure: e.bloodPressure,
        temperature: e.temperature,
        allergies: e.allergies,
        medicalHistory: e.medicalHistory,
        previousHistory: e.previousHistory,
        chiefComplaint: e.chiefComplaint,
        examGeneral: e.examGeneral,
        examNeurological: e.examNeurological,
        clinicalDiagnosis: e.clinicalDiagnosis,
        imaging: e.imaging,
        otherInvestigations: e.otherInvestigations,
        impression: e.impression,
        plan: e.plan,
        treatment: e.treatment,
        treatmentNotes: e.treatmentNotes,
        advice: e.advice,
        notes: e.notes,
        isActive: e.isActive,
        createdAt: e.createdAt.toIso8601String(),
        updatedAt: e.updatedAt.toIso8601String(),
        createdBy: e.createdBy,
        updatedBy: e.updatedBy,
        syncStatus: e.syncStatus,
      );
}
