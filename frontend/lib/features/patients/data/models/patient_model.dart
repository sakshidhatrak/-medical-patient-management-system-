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

  // ── Registration Vitals (baseline) ───────────────────────────────
  final String? weight;
  final String? bloodPressure;
  final String? temperature;

  // ── History (static) ─────────────────────────────────────────────
  final String? allergies;
  final String? medicalHistory;
  final String? previousHistory;

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
        notes: j['notes'] as String?,
        isActive: (j['isActive'] ?? j['is_active']) as bool? ?? true,
        createdAt: (j['createdAt'] ?? j['created_at']) as String,
        updatedAt: (j['updatedAt'] ?? j['updated_at']) as String,
        createdBy: (j['createdBy'] ?? j['created_by']) as String?,
        updatedBy: (j['updatedBy'] ?? j['updated_by']) as String?,
        syncStatus: (j['syncStatus'] ?? j['sync_status']) as String? ?? 'synced',
      );

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
        'notes': notes,
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
        notes: e.notes,
        isActive: e.isActive,
        createdAt: e.createdAt.toIso8601String(),
        updatedAt: e.updatedAt.toIso8601String(),
        createdBy: e.createdBy,
        updatedBy: e.updatedBy,
        syncStatus: e.syncStatus,
      );
}
