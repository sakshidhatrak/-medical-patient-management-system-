import 'package:equatable/equatable.dart';

enum UserRole { doctor, nurse, admin, staff, receptionist, assistant }

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  bool get isDoctor => role == UserRole.doctor;
  bool get isAdmin => role == UserRole.admin;
  bool get isStaff => role == UserRole.staff;
  bool get isAssistant => role == UserRole.assistant;

  /// Admin has full write access (visits, surgeries, prescriptions, photos).
  bool get canWrite => role == UserRole.admin;

  /// Admin and Staff can create/update patient personal information.
  bool get canEditPatient => role == UserRole.admin || role == UserRole.staff;

  String get roleDisplayName => switch (role) {
        UserRole.admin => 'Admin',
        UserRole.staff => 'Staff',
        UserRole.assistant => 'Assistant',
        UserRole.doctor => 'Doctor',
        UserRole.nurse => 'Nurse',
        UserRole.receptionist => 'Receptionist',
      };

  @override
  List<Object?> get props =>
      [id, email, firstName, lastName, role, avatarUrl, createdAt];
}
