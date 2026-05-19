import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_patient_management/features/patients/data/models/patient_model.dart';
import 'package:medical_patient_management/features/patients/domain/entities/patient_entity.dart';

void main() {
  const _now = '2024-01-15T08:00:00.000Z';

  final fullModel = PatientModel(
    id: 'p-001',
    firstName: 'Sarah',
    lastName: 'Johnson',
    dateOfBirth: '1985-03-14',
    gender: 'female',
    phone: '+1 555-0101',
    email: 'sarah@example.com',
    address: '123 Oak St',
    bloodType: 'A+',
    allergies: const ['Penicillin', 'Latex'],
    createdAt: _now,
    updatedAt: _now,
  );

  group('PatientModel – fromJson / toJson round-trip', () {
    test('toJson produces correct keys', () {
      final json = fullModel.toJson();
      expect(json['id'], 'p-001');
      expect(json['first_name'], 'Sarah');
      expect(json['last_name'], 'Johnson');
      expect(json['blood_type'], 'A+');
      expect(json['allergies'], ['Penicillin', 'Latex']);
    });

    test('fromJson restores all fields', () {
      final json = fullModel.toJson();
      final restored = PatientModel.fromJson(json);

      expect(restored.id, fullModel.id);
      expect(restored.firstName, fullModel.firstName);
      expect(restored.email, fullModel.email);
      expect(restored.allergies, fullModel.allergies);
    });
  });

  group('PatientModel – SQLite round-trip', () {
    test('toSqlite encodes allergies as JSON string', () {
      final row = fullModel.toSqlite();
      expect(row['allergies'], isA<String>());
      final decoded = jsonDecode(row['allergies'] as String) as List;
      expect(decoded, ['Penicillin', 'Latex']);
    });

    test('fromSqlite restores allergies from JSON string', () {
      final row = fullModel.toSqlite();
      final restored = PatientModel.fromSqlite(row);
      expect(restored.allergies, ['Penicillin', 'Latex']);
    });

    test('fromSqlite handles null allergies gracefully', () {
      final row = fullModel.toSqlite();
      row['allergies'] = null;
      final restored = PatientModel.fromSqlite(row);
      expect(restored.allergies, isEmpty);
    });
  });

  group('PatientModel – toEntity', () {
    test('converts to PatientEntity with correct values', () {
      final entity = fullModel.toEntity();
      expect(entity.id, 'p-001');
      expect(entity.firstName, 'Sarah');
      expect(entity.gender, Gender.female);
      expect(entity.dateOfBirth, DateTime(1985, 3, 14));
      expect(entity.allergies, ['Penicillin', 'Latex']);
    });

    test('maps gender strings to enum correctly', () {
      final male =
          PatientModel(id: '1', firstName: 'J', lastName: 'D',
              dateOfBirth: '1990-01-01', gender: 'male', phone: '123',
              createdAt: _now, updatedAt: _now).toEntity();
      expect(male.gender, Gender.male);

      final other =
          PatientModel(id: '2', firstName: 'J', lastName: 'D',
              dateOfBirth: '1990-01-01', gender: 'other', phone: '123',
              createdAt: _now, updatedAt: _now).toEntity();
      expect(other.gender, Gender.other);
    });
  });

  group('PatientModel – fromEntity', () {
    test('round-trips through entity without data loss', () {
      final entity = fullModel.toEntity();
      final restored = PatientModel.fromEntity(entity);

      expect(restored.id, fullModel.id);
      expect(restored.firstName, fullModel.firstName);
      expect(restored.gender, fullModel.gender);
      expect(restored.allergies, fullModel.allergies);
      expect(restored.bloodType, fullModel.bloodType);
    });
  });
}
