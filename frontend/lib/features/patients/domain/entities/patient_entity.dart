import 'package:equatable/equatable.dart';

class PatientEntity extends Equatable {
  final String id;
  final String prn;
  final String firstName;
  final String lastName;
  final int? age;
  final DateTime? dateOfBirth;
  final String? sex;
  final String? phone;
  final String? address;

  // ── Contact ─────────────────────────────────────────────────────
  final String? altPhone;
  final String? email;

  // ── ID Proof ─────────────────────────────────────────────────────
  final String? idProofType;
  final String? idProofNumber;

  // ── Registration Vitals (baseline at registration) ───────────────
  final String? weight;
  final String? bloodPressure;
  final String? temperature;

  // ── History (static, non-changing) ──────────────────────────────
  final String? allergies;
  final String? medicalHistory;
  final String? previousHistory;

  // ── Admin ────────────────────────────────────────────────────────
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String syncStatus; // 'synced' | 'pending'

  const PatientEntity({
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

  String get fullName =>
      lastName.isEmpty ? firstName : '$firstName $lastName';

  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  int get computedAge {
    if (age != null) return age!;
    if (dateOfBirth != null) {
      final now = DateTime.now();
      int a = now.year - dateOfBirth!.year;
      if (now.month < dateOfBirth!.month ||
          (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
        a--;
      }
      return a;
    }
    return 0;
  }

  String get displayAge => computedAge > 0 ? '${computedAge}y' : '';

  String get ageSex {
    final a = displayAge;
    final s = sex?.isNotEmpty == true ? sex![0].toUpperCase() : '';
    if (a.isEmpty && s.isEmpty) return '';
    if (a.isEmpty) return s;
    if (s.isEmpty) return a;
    return '$a / $s';
  }

  PatientEntity copyWith({
    String? firstName,
    String? lastName,
    int? age,
    DateTime? dateOfBirth,
    String? sex,
    String? phone,
    String? address,
    String? altPhone,
    String? email,
    String? idProofType,
    String? idProofNumber,
    String? weight,
    String? bloodPressure,
    String? temperature,
    String? allergies,
    String? medicalHistory,
    String? previousHistory,
    String? notes,
    String? syncStatus,
  }) =>
      PatientEntity(
        id: id,
        prn: prn,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        age: age ?? this.age,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        sex: sex ?? this.sex,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        altPhone: altPhone ?? this.altPhone,
        email: email ?? this.email,
        idProofType: idProofType ?? this.idProofType,
        idProofNumber: idProofNumber ?? this.idProofNumber,
        weight: weight ?? this.weight,
        bloodPressure: bloodPressure ?? this.bloodPressure,
        temperature: temperature ?? this.temperature,
        allergies: allergies ?? this.allergies,
        medicalHistory: medicalHistory ?? this.medicalHistory,
        previousHistory: previousHistory ?? this.previousHistory,
        notes: notes ?? this.notes,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        createdBy: createdBy,
        updatedBy: updatedBy,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  @override
  List<Object?> get props =>
      [id, prn, firstName, lastName, age, dateOfBirth, sex, phone];
}

/// Generates offline PRN: DD-MM-YYYY-NNN (first 3 letters of firstName).
/// Uniqueness is guaranteed by the server; offline PRN is temporary.
String generatePrn(String firstName) {
  final n = DateTime.now();
  final initials = firstName.length >= 3
      ? firstName.substring(0, 3).toUpperCase()
      : firstName.toUpperCase();
  return '${_p(n.day)}-${_p(n.month)}-${n.year}-$initials';
}

String _p(int v) => v.toString().padLeft(2, '0');
