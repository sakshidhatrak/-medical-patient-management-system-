import 'package:equatable/equatable.dart';

class PatientEntity extends Equatable {
  final String id;
  final String prn;
  final String firstName;
  final String lastName;
  final int? age;
  final DateTime? dateOfBirth;
  final String? sex;           // male/female/other
  final String? phone;
  final String? address;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

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
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
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
    String? notes,
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
        notes: notes ?? this.notes,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props =>
      [id, prn, firstName, lastName, age, dateOfBirth, sex, phone];
}

/// Generates PRN: ddmmyyHHmmss
String generatePrn() {
  final n = DateTime.now();
  return '${_p(n.day)}${_p(n.month)}${_p(n.year % 100)}'
      '${_p(n.hour)}${_p(n.minute)}${_p(n.second)}';
}

String _p(int v) => v.toString().padLeft(2, '0');
