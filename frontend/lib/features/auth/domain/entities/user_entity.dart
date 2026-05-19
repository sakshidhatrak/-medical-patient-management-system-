import 'package:equatable/equatable.dart';

enum UserRole { doctor, nurse, admin, receptionist }

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

  @override
  List<Object?> get props =>
      [id, email, firstName, lastName, role, avatarUrl, createdAt];
}
