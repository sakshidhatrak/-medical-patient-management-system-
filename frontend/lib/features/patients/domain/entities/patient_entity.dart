import 'package:equatable/equatable.dart';

enum Gender { male, female, other, preferNotToSay }

class PatientEntity extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final Gender gender;
  final String phone;
  final String? email;
  final String? address;
  final String? bloodType;
  final List<String> allergies;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PatientEntity({
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
  });

  String get fullName => '$firstName $lastName';

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        dateOfBirth,
        gender,
        phone,
        email,
        address,
        bloodType,
        allergies,
        createdAt,
        updatedAt,
      ];
}
