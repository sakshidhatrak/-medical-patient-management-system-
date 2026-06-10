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
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

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
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PatientModel.fromJson(Map<String, dynamic> j) => PatientModel(
        id: j['id'] as String,
        prn: j['prn'] as String? ?? '',
        firstName: j['first_name'] as String,
        lastName: j['last_name'] as String? ?? '',
        age: j['age'] as int?,
        dateOfBirth: j['date_of_birth'] as String?,
        sex: j['sex'] as String?,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        notes: j['notes'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        createdAt: j['created_at'] as String,
        updatedAt: j['updated_at'] as String,
      );

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
        notes: notes,
        isActive: isActive,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
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
        notes: e.notes,
        isActive: e.isActive,
        createdAt: e.createdAt.toIso8601String(),
        updatedAt: e.updatedAt.toIso8601String(),
      );
}
