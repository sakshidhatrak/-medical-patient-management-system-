import 'dart:convert';

import '../../domain/entities/patient_entity.dart';

class PatientModel {
  final String id;
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String gender;
  final String phone;
  final String? email;
  final String? address;
  final String? bloodType;
  final List<String> allergies;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const PatientModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.phone,
    this.email,
    this.address,
    this.bloodType,
    this.allergies = const [],
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) => PatientModel(
        id: json['id'] as String,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        dateOfBirth: json['date_of_birth'] as String,
        gender: json['gender'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        address: json['address'] as String?,
        bloodType: json['blood_type'] as String?,
        allergies: (json['allergies'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
        syncStatus: json['sync_status'] as String? ?? 'pending',
      );

  factory PatientModel.fromSqlite(Map<String, dynamic> row) => PatientModel(
        id: row['id'] as String,
        firstName: row['first_name'] as String,
        lastName: row['last_name'] as String,
        dateOfBirth: row['date_of_birth'] as String,
        gender: row['gender'] as String,
        phone: row['phone'] as String,
        email: row['email'] as String?,
        address: row['address'] as String?,
        bloodType: row['blood_type'] as String?,
        allergies: row['allergies'] != null
            ? (jsonDecode(row['allergies'] as String) as List<dynamic>)
                .map((e) => e as String)
                .toList()
            : [],
        createdAt: row['created_at'] as String,
        updatedAt: row['updated_at'] as String,
        syncStatus: row['sync_status'] as String? ?? 'pending',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'phone': phone,
        'email': email,
        'address': address,
        'blood_type': bloodType,
        'allergies': allergies,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'sync_status': syncStatus,
      };

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'phone': phone,
        'email': email,
        'address': address,
        'blood_type': bloodType,
        'allergies': jsonEncode(allergies),
        'created_at': createdAt,
        'updated_at': updatedAt,
        'sync_status': syncStatus,
      };

  PatientEntity toEntity() => PatientEntity(
        id: id,
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: DateTime.parse(dateOfBirth),
        gender: _parseGender(gender),
        phone: phone,
        email: email,
        address: address,
        bloodType: bloodType,
        allergies: allergies,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
      );

  factory PatientModel.fromEntity(PatientEntity e) => PatientModel(
        id: e.id,
        firstName: e.firstName,
        lastName: e.lastName,
        dateOfBirth: e.dateOfBirth.toIso8601String().split('T').first,
        gender: e.gender.name,
        phone: e.phone,
        email: e.email,
        address: e.address,
        bloodType: e.bloodType,
        allergies: e.allergies,
        createdAt: e.createdAt.toIso8601String(),
        updatedAt: e.updatedAt.toIso8601String(),
      );

  static Gender _parseGender(String value) => switch (value) {
        'male' => Gender.male,
        'female' => Gender.female,
        'other' => Gender.other,
        _ => Gender.preferNotToSay,
      };
}
