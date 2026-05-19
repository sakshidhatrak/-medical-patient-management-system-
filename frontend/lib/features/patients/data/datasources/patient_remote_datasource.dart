import '../../../../core/error/exceptions.dart';
import '../models/patient_model.dart';

abstract interface class PatientRemoteDataSource {
  Future<List<PatientModel>> getPatients({
    required int page,
    required int pageSize,
    String? search,
  });

  Future<PatientModel> getPatientById(String id);

  Future<PatientModel> createPatient(PatientModel patient);

  Future<PatientModel> updatePatient(PatientModel patient);

  Future<void> deletePatient(String id);
}

// In-memory mock — no network calls
class PatientRemoteDataSourceImpl implements PatientRemoteDataSource {
  final List<PatientModel> _store = List.of(_kSeedPatients);

  @override
  Future<List<PatientModel>> getPatients({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    var list = _store.toList();
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      list = list
          .where((p) =>
              p.firstName.toLowerCase().contains(q) ||
              p.lastName.toLowerCase().contains(q) ||
              p.phone.contains(q))
          .toList();
    }
    final offset = (page - 1) * pageSize;
    return list.skip(offset).take(pageSize).toList();
  }

  @override
  Future<PatientModel> getPatientById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final patient = _store.where((p) => p.id == id).firstOrNull;
    if (patient == null) {
      throw NotFoundException('Patient not found.', code: 'NOT_FOUND');
    }
    return patient;
  }

  @override
  Future<PatientModel> createPatient(PatientModel patient) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _store.insert(0, patient);
    return patient;
  }

  @override
  Future<PatientModel> updatePatient(PatientModel patient) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _store.indexWhere((p) => p.id == patient.id);
    if (idx == -1) {
      throw NotFoundException('Patient not found.', code: 'NOT_FOUND');
    }
    _store[idx] = patient;
    return patient;
  }

  @override
  Future<void> deletePatient(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _store.removeWhere((p) => p.id == id);
  }
}

// Seed data
const _t = '2024-01-15T08:00:00.000Z';

const _kSeedPatients = [
  PatientModel(
    id: 'p-001',
    firstName: 'Sarah',
    lastName: 'Johnson',
    dateOfBirth: '1985-03-14',
    gender: 'female',
    phone: '+1 555-0101',
    email: 'sarah.johnson@email.com',
    address: '123 Oak Street, Boston, MA 02101',
    bloodType: 'A+',
    allergies: ['Penicillin', 'Latex'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-002',
    firstName: 'Michael',
    lastName: 'Chen',
    dateOfBirth: '1972-07-22',
    gender: 'male',
    phone: '+1 555-0102',
    email: 'mchen@email.com',
    address: '456 Elm Ave, Chicago, IL 60601',
    bloodType: 'B+',
    allergies: ['Sulfa drugs'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-003',
    firstName: 'Emily',
    lastName: 'Rodriguez',
    dateOfBirth: '1990-11-05',
    gender: 'female',
    phone: '+1 555-0103',
    email: 'emily.r@email.com',
    address: '789 Pine Rd, Miami, FL 33101',
    bloodType: 'O+',
    allergies: [],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-004',
    firstName: 'James',
    lastName: 'Williams',
    dateOfBirth: '1955-01-30',
    gender: 'male',
    phone: '+1 555-0104',
    email: 'jwilliams@email.com',
    address: '321 Maple Dr, Seattle, WA 98101',
    bloodType: 'AB-',
    allergies: ['Aspirin', 'Ibuprofen'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-005',
    firstName: 'Aisha',
    lastName: 'Patel',
    dateOfBirth: '1998-06-18',
    gender: 'female',
    phone: '+1 555-0105',
    email: 'aisha.patel@email.com',
    address: '654 Cedar Ln, Austin, TX 78701',
    bloodType: 'A-',
    allergies: ['Peanuts'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-006',
    firstName: 'Robert',
    lastName: 'Thompson',
    dateOfBirth: '1962-09-09',
    gender: 'male',
    phone: '+1 555-0106',
    email: 'rthompson@email.com',
    address: '987 Birch Blvd, Denver, CO 80201',
    bloodType: 'O-',
    allergies: ['Codeine'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-007',
    firstName: 'Mei',
    lastName: 'Liu',
    dateOfBirth: '2001-02-14',
    gender: 'female',
    phone: '+1 555-0107',
    email: 'mei.liu@email.com',
    address: '159 Walnut St, San Francisco, CA 94101',
    bloodType: 'B-',
    allergies: [],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-008',
    firstName: 'Carlos',
    lastName: 'Martinez',
    dateOfBirth: '1978-12-03',
    gender: 'male',
    phone: '+1 555-0108',
    email: 'cmartinez@email.com',
    address: '753 Spruce Way, Phoenix, AZ 85001',
    bloodType: 'AB+',
    allergies: ['Morphine', 'Latex'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-009',
    firstName: 'Grace',
    lastName: 'O\'Brien',
    dateOfBirth: '1945-08-27',
    gender: 'female',
    phone: '+1 555-0109',
    email: 'gobrien@email.com',
    address: '246 Ash Court, Portland, OR 97201',
    bloodType: 'A+',
    allergies: ['Penicillin'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-010',
    firstName: 'David',
    lastName: 'Kim',
    dateOfBirth: '1988-04-19',
    gender: 'male',
    phone: '+1 555-0110',
    email: 'dkim@email.com',
    address: '864 Poplar Ave, Nashville, TN 37201',
    bloodType: 'O+',
    allergies: [],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-011',
    firstName: 'Fatima',
    lastName: 'Hassan',
    dateOfBirth: '1993-10-31',
    gender: 'female',
    phone: '+1 555-0111',
    email: 'fhassan@email.com',
    address: '531 Willow Pl, Minneapolis, MN 55401',
    bloodType: 'B+',
    allergies: ['Shellfish'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientModel(
    id: 'p-012',
    firstName: 'Thomas',
    lastName: 'Anderson',
    dateOfBirth: '1968-05-07',
    gender: 'male',
    phone: '+1 555-0112',
    email: 'tanderson@email.com',
    address: '975 Magnolia St, Atlanta, GA 30301',
    bloodType: 'A+',
    allergies: ['Aspirin'],
    createdAt: _t,
    updatedAt: _t,
  ),
];
