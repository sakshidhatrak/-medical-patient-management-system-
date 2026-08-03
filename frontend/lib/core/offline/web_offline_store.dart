import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Web-compatible offline store backed by SharedPreferences (localStorage).
/// Provides a sync queue and entity cache for use when kIsWeb == true.
class WebOfflineStore {
  static const _queueKey = '_wsq_';
  static const _ns = '_wc_';

  final SharedPreferences _p;
  WebOfflineStore(this._p);

  // ── Sync queue ────────────────────────────────────────────────────

  List<Map<String, dynamic>> _queue() {
    final raw = _p.getString(_queueKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> q) =>
      _p.setString(_queueKey, jsonEncode(q));

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final q = _queue();
    q.add({
      'id': const Uuid().v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'queued_at': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    await _saveQueue(q);
  }

  /// Returns items with fewer than 5 attempts, oldest first.
  List<Map<String, dynamic>> pending() {
    final items = _queue().where((i) => (i['attempts'] as int) < 5).toList();
    items.sort(
        (a, b) => (a['queued_at'] as String).compareTo(b['queued_at'] as String));
    return items;
  }

  Future<void> markDone(String id) async {
    final q = _queue()..removeWhere((i) => i['id'] == id);
    await _saveQueue(q);
  }

  Future<void> incrementAttempt(String id, String error) async {
    final q = _queue().map((i) {
      if (i['id'] == id) {
        return {...i, 'attempts': (i['attempts'] as int) + 1, 'last_error': error};
      }
      return i;
    }).toList();
    await _saveQueue(q);
  }

  // ── Internal cache helpers ────────────────────────────────────────

  List<Map<String, dynamic>> _getList(String key) {
    final raw = _p.getString(_ns + key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _setList(String key, List<Map<String, dynamic>> items) =>
      _p.setString(_ns + key, jsonEncode(items));

  Map<String, dynamic>? _getItem(String key) {
    final raw = _p.getString(_ns + key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _setItem(String key, Map<String, dynamic> item) =>
      _p.setString(_ns + key, jsonEncode(item));

  Future<void> _removeItem(String key) => _p.remove(_ns + key);

  // ── Patients ──────────────────────────────────────────────────────

  Future<void> upsertPatient(Map<String, dynamic> apiJson) async {
    final id = apiJson['id'].toString();
    final now = DateTime.now().toIso8601String();
    final row = {
      'id': id,
      'prn': apiJson['prn'] ?? '',
      'first_name': apiJson['firstName'] ?? apiJson['first_name'] ?? '',
      'last_name': apiJson['lastName'] ?? apiJson['last_name'] ?? '',
      'age': apiJson['age'],
      'date_of_birth': apiJson['dateOfBirth'] ?? apiJson['date_of_birth'],
      'sex': apiJson['sex'],
      'phone': apiJson['phone'],
      'address': apiJson['address'],
      'notes': apiJson['notes'],
      'data_json': jsonEncode(apiJson),
      'sync_status': 'synced',
      'is_active': (apiJson['isActive'] == false) ? 0 : 1,
      'created_at': apiJson['createdAt'] ?? apiJson['created_at'] ?? now,
      'updated_at': apiJson['updatedAt'] ?? apiJson['updated_at'] ?? now,
    };
    // Update indexed list
    final list = _getList('patients');
    final idx = list.indexWhere((p) => p['id'] == id);
    if (idx >= 0) {
      list[idx] = row;
    } else {
      list.add(row);
    }
    await _setList('patients', list);
    await _setItem('patient_$id', row);
  }

  List<Map<String, dynamic>> getAllPatients({String? search}) {
    var list = _getList('patients').where((p) => p['is_active'] != 0).toList();
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      list = list
          .where((p) =>
              (p['first_name'] as String? ?? '').toLowerCase().contains(q) ||
              (p['last_name'] as String? ?? '').toLowerCase().contains(q) ||
              (p['prn'] as String? ?? '').toLowerCase().contains(q) ||
              (p['phone'] as String? ?? '').contains(q))
          .toList();
    }
    list.sort((a, b) =>
        (b['updated_at'] as String).compareTo(a['updated_at'] as String));
    return list.take(100).toList();
  }

  Map<String, dynamic>? getPatient(String id) => _getItem('patient_$id');

  Future<void> deletePatient(String id) async {
    final row = _getItem('patient_$id');
    if (row == null) return;
    final updated = {...row, 'is_active': 0, 'sync_status': 'pending'};
    await _setItem('patient_$id', updated);
    final list = _getList('patients')
        .map((p) => p['id'] == id ? updated : p)
        .toList();
    await _setList('patients', list);
  }

  // ── Visits ────────────────────────────────────────────────────────

  Future<void> upsertVisit(Map<String, dynamic> apiJson) async {
    final id = apiJson['id'].toString();
    final patientId =
        (apiJson['patientId'] ?? apiJson['patient_id']).toString();
    final now = DateTime.now().toIso8601String();
    final row = {
      'id': id,
      'patient_id': patientId,
      'visit_date': apiJson['visitDate'] ?? apiJson['visit_date'] ?? now,
      'visit_type': apiJson['visitType'] ?? apiJson['visit_type'] ?? 'opd',
      'complaints': apiJson['complaints'],
      'examination': apiJson['examination'],
      'clinical_impression':
          apiJson['clinicalImpression'] ?? apiJson['clinical_impression'],
      'plan': apiJson['plan'],
      'notes': apiJson['notes'],
      'status': apiJson['status'] ?? 'draft',
      'data_json': jsonEncode(apiJson),
      'sync_status': 'synced',
      'created_at': apiJson['createdAt'] ?? apiJson['created_at'] ?? now,
      'updated_at': apiJson['updatedAt'] ?? apiJson['updated_at'] ?? now,
    };
    final listKey = 'visits_$patientId';
    final list = _getList(listKey);
    final idx = list.indexWhere((v) => v['id'] == id);
    if (idx >= 0) {
      list[idx] = row;
    } else {
      list.add(row);
    }
    await _setList(listKey, list);
    await _setItem('visit_$id', row);
  }

  List<Map<String, dynamic>> getVisitsForPatient(String patientId) {
    final list = _getList('visits_$patientId');
    list.sort((a, b) =>
        (b['visit_date'] as String).compareTo(a['visit_date'] as String));
    return list;
  }

  Map<String, dynamic>? getVisit(String id) => _getItem('visit_$id');

  Future<void> deleteVisit(String id) async {
    final row = _getItem('visit_$id');
    if (row == null) return;
    final patientId = row['patient_id'] as String;
    await _removeItem('visit_$id');
    final list = _getList('visits_$patientId')
      ..removeWhere((v) => v['id'] == id);
    await _setList('visits_$patientId', list);
  }

  // ── Surgeries ─────────────────────────────────────────────────────

  Future<void> upsertSurgery(Map<String, dynamic> apiJson) async {
    final id = apiJson['id'].toString();
    final patientId =
        (apiJson['patientId'] ?? apiJson['patient_id']).toString();
    final now = DateTime.now().toIso8601String();
    final row = {
      'id': id,
      'patient_id': patientId,
      'surgery_date':
          apiJson['surgeryDate'] ?? apiJson['surgery_date'] ?? now,
      'your_role': apiJson['yourRole'] ?? apiJson['your_role'],
      'pre_op_diagnosis':
          apiJson['preOpDiagnosis'] ?? apiJson['pre_op_diagnosis'],
      'procedure': apiJson['procedure'],
      'primary_surgeon':
          apiJson['primarySurgeon'] ?? apiJson['primary_surgeon'],
      'assistant_surgeons':
          apiJson['assistantSurgeons'] ?? apiJson['assistant_surgeons'],
      'anesthesia_type':
          apiJson['anesthesiaType'] ?? apiJson['anesthesia_type'],
      'anesthesiologist': apiJson['anesthesiologist'],
      'implants': apiJson['implants'],
      'intraop_findings':
          apiJson['intraopFindings'] ?? apiJson['intraop_findings'],
      'ot_notes': apiJson['otNotes'] ?? apiJson['ot_notes'],
      'complications': apiJson['complications'],
      'post_op_plan': apiJson['postOpPlan'] ?? apiJson['post_op_plan'],
      'status': apiJson['status'] ?? 'draft',
      'data_json': jsonEncode(apiJson),
      'sync_status': 'synced',
      'created_at': apiJson['createdAt'] ?? apiJson['created_at'] ?? now,
      'updated_at': apiJson['updatedAt'] ?? apiJson['updated_at'] ?? now,
    };
    final listKey = 'surgeries_$patientId';
    final list = _getList(listKey);
    final idx = list.indexWhere((s) => s['id'] == id);
    if (idx >= 0) {
      list[idx] = row;
    } else {
      list.add(row);
    }
    await _setList(listKey, list);
    await _setItem('surgery_$id', row);
  }

  List<Map<String, dynamic>> getSurgeriesForPatient(String patientId) {
    final list = _getList('surgeries_$patientId');
    list.sort((a, b) => (b['surgery_date'] as String)
        .compareTo(a['surgery_date'] as String));
    return list;
  }

  Map<String, dynamic>? getSurgery(String id) => _getItem('surgery_$id');

  Future<void> deleteSurgery(String id) async {
    final row = _getItem('surgery_$id');
    if (row == null) return;
    final patientId = row['patient_id'] as String;
    await _removeItem('surgery_$id');
    final list = _getList('surgeries_$patientId')
      ..removeWhere((s) => s['id'] == id);
    await _setList('surgeries_$patientId', list);
  }

  // ── Examinations ──────────────────────────────────────────────────

  Future<void> upsertExamination(
          String visitId, String patientId, Map<String, dynamic> data) =>
      _setItem('exam_$visitId', data);

  Map<String, dynamic>? getExamination(String visitId) =>
      _getItem('exam_$visitId');

  // ── Prescriptions ─────────────────────────────────────────────────

  Future<void> upsertPrescription(
          String visitId, String patientId, Map<String, dynamic> data) =>
      _setItem('rx_$visitId', data);

  Map<String, dynamic>? getPrescription(String visitId) =>
      _getItem('rx_$visitId');
}
