import 'package:equatable/equatable.dart';

enum UserRole { doctor, nurse, admin, receptionist, assistant }

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
  bool get isAssistant => role == UserRole.assistant;

  /// Admin has full write access; all other roles (including assistant) are read-only.
  bool get canWrite => role == UserRole.admin;

  String get roleDisplayName => switch (role) {
        UserRole.admin => 'Admin',
        UserRole.assistant => 'Assistant',
        UserRole.doctor => 'Doctor',
        UserRole.nurse => 'Nurse',
        UserRole.receptionist => 'Receptionist',
      };

  @override
  List<Object?> get props =>
      [id, email, firstName, lastName, role, avatarUrl, createdAt];
}
