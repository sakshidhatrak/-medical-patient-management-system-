import '../../domain/entities/user_entity.dart';

class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? avatarUrl;
  final String createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: (json['id'] as Object).toString(),
        email: json['email'] as String,
        firstName: (json['firstName'] ?? json['first_name']) as String,
        lastName: (json['lastName'] ?? json['last_name']) as String,
        role: (json['role'] as Object).toString(),
        avatarUrl: (json['avatarUrl'] ?? json['avatar_url']) as String?,
        createdAt: (json['createdAt'] ?? json['created_at']) as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt,
      };

  UserEntity toEntity() => UserEntity(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: _parseRole(role),
        avatarUrl: avatarUrl,
        createdAt: DateTime.parse(createdAt),
      );

  static UserRole _parseRole(String role) => switch (role) {
        'doctor' => UserRole.doctor,
        'nurse' => UserRole.nurse,
        'admin' => UserRole.admin,
        'receptionist' => UserRole.receptionist,
        'assistant' => UserRole.assistant,
        _ => UserRole.assistant,
      };
}
