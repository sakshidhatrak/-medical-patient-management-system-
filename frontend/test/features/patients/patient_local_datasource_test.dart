import 'package:flutter_test/flutter_test.dart';
import 'package:medical_patient_management/features/patients/data/datasources/patient_local_datasource.dart';
import 'package:medical_patient_management/features/patients/data/models/patient_model.dart';
import 'package:medical_patient_management/core/error/exceptions.dart';

import '../../helpers/test_database.dart';

const _now = '2024-01-15T08:00:00.000Z';

PatientModel _patient(String id, {String first = 'John', String last = 'Doe'}) =>
    PatientModel(
      id: id,
      firstName: first,
      lastName: last,
      dateOfBirth: '1990-01-01',
      gender: 'male',
      phone: '+1 555-000$id',
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  late PatientLocalDataSourceImpl ds;

  setUpAll(initTestDatabase);

  setUp(() async {
    final db = await buildTestDb();
    ds = PatientLocalDataSourceImpl(db);
  });

  group('PatientLocalDataSource – getPatients', () {
    test('returns empty list when no patients exist', () async {
      final result = await ds.getPatients(limit: 10, offset: 0);
      expect(result, isEmpty);
    });

    test('returns inserted patients ordered by last_name, first_name', () async {
      await ds.upsertPatients([
        _patient('1', first: 'Zara', last: 'Williams'),
        _patient('2', first: 'Alice', last: 'Adams'),
      ]);

      final result = await ds.getPatients(limit: 10, offset: 0);
      expect(result.length, 2);
      expect(result.first.lastName, 'Adams');
      expect(result.last.lastName, 'Williams');
    });

    test('filters by search term on first_name', () async {
      await ds.upsertPatients([
        _patient('1', first: 'Alice', last: 'Smith'),
        _patient('2', first: 'Bob', last: 'Jones'),
      ]);

      final result = await ds.getPatients(limit: 10, offset: 0, search: 'Ali');
      expect(result.length, 1);
      expect(result.first.firstName, 'Alice');
    });

    test('filters by search term on last_name', () async {
      await ds.upsertPatients([
        _patient('1', first: 'Alice', last: 'Smith'),
        _patient('2', first: 'Bob', last: 'Jones'),
      ]);

      final result =
          await ds.getPatients(limit: 10, offset: 0, search: 'Jones');
      expect(result.length, 1);
      expect(result.first.firstName, 'Bob');
    });

    test('respects limit and offset for pagination', () async {
      await ds.upsertPatients([
        _patient('1', first: 'Alice', last: 'A'),
        _patient('2', first: 'Bob', last: 'B'),
        _patient('3', first: 'Carol', last: 'C'),
      ]);

      final page1 = await ds.getPatients(limit: 2, offset: 0);
      final page2 = await ds.getPatients(limit: 2, offset: 2);

      expect(page1.length, 2);
      expect(page2.length, 1);
    });
  });

  group('PatientLocalDataSource – getPatientById', () {
    test('returns null when patient does not exist', () async {
      final result = await ds.getPatientById('nonexistent');
      expect(result, isNull);
    });

    test('returns the correct patient by id', () async {
      await ds.upsertPatient(_patient('p-42', first: 'Jane', last: 'Doe'));

      final result = await ds.getPatientById('p-42');
      expect(result, isNotNull);
      expect(result!.firstName, 'Jane');
      expect(result.id, 'p-42');
    });
  });

  group('PatientLocalDataSource – upsertPatient', () {
    test('inserts a new patient', () async {
      await ds.upsertPatient(_patient('new-1'));

      final result = await ds.getPatientById('new-1');
      expect(result, isNotNull);
    });

    test('updates existing patient on conflict', () async {
      await ds.upsertPatient(_patient('up-1', first: 'Original'));
      await ds.upsertPatient(_patient('up-1', first: 'Updated'));

      final result = await ds.getPatientById('up-1');
      expect(result!.firstName, 'Updated');
    });

    test('stores allergies as JSON and restores correctly', () async {
      final p = PatientModel(
        id: 'allergy-1',
        firstName: 'Test',
        lastName: 'User',
        dateOfBirth: '1990-01-01',
        gender: 'female',
        phone: '+1 555-9999',
        allergies: ['Penicillin', 'Latex'],
        createdAt: _now,
        updatedAt: _now,
      );
      await ds.upsertPatient(p);

      final result = await ds.getPatientById('allergy-1');
      expect(result!.allergies, ['Penicillin', 'Latex']);
    });
  });

  group('PatientLocalDataSource – upsertPatients (batch)', () {
    test('inserts multiple patients in one call', () async {
      await ds.upsertPatients(List.generate(
          5, (i) => _patient('batch-$i', first: 'Patient$i')));

      final result = await ds.getPatients(limit: 10, offset: 0);
      expect(result.length, 5);
    });
  });

  group('PatientLocalDataSource – deletePatient', () {
    test('removes patient from database', () async {
      await ds.upsertPatient(_patient('del-1'));
      await ds.deletePatient('del-1');

      final result = await ds.getPatientById('del-1');
      expect(result, isNull);
    });

    test('delete on non-existent id does not throw', () async {
      await expectLater(ds.deletePatient('ghost-id'), completes);
    });
  });
}
