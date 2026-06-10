import 'package:flutter_test/flutter_test.dart';
import 'package:medical_patient_management/features/patients/data/models/patient_model.dart';
import 'package:medical_patient_management/features/patients/domain/entities/patient_entity.dart';

void main() {
  group('PatientModel', () {
    const json = {
      'id': 'test-id',
      'prn': '190526103000',
      'first_name': 'John',
      'last_name': 'Doe',
      'age': 35,
      'sex': 'male',
      'phone': '9876543210',
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    };

    test('fromJson parses correctly', () {
      final model = PatientModel.fromJson(json);
      expect(model.firstName, 'John');
      expect(model.prn, '190526103000');
      expect(model.age, 35);
    });

    test('toEntity maps correctly', () {
      final entity = PatientModel.fromJson(json).toEntity();
      expect(entity, isA<PatientEntity>());
      expect(entity.fullName, 'John Doe');
    });

    test('fromEntity round-trips', () {
      final entity = PatientModel.fromJson(json).toEntity();
      final model = PatientModel.fromEntity(entity);
      expect(model.prn, entity.prn);
      expect(model.firstName, entity.firstName);
    });

    test('generatePrn returns 12-char string', () {
      final prn = generatePrn();
      expect(prn.length, 12);
    });
  });
}
