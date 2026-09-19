import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/sync/sync_engine.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class AuditEntry {
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  final DateTime changedAt;
  final String? changedByName;

  const AuditEntry({
    required this.fieldName,
    this.oldValue,
    this.newValue,
    required this.changedAt,
    this.changedByName,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        fieldName: json['fieldName'] as String,
        oldValue: json['oldValue'] as String?,
        newValue: json['newValue'] as String?,
        changedAt: DateTime.parse(json['changedAt'] as String),
        changedByName: json['changedByName'] as String?,
      );

  factory AuditEntry.fromSqlite(Map<String, dynamic> row) => AuditEntry(
        fieldName: row['field_name'] as String,
        oldValue: row['old_value'] as String?,
        newValue: row['new_value'] as String?,
        changedAt: DateTime.parse(row['changed_at'] as String),
        changedByName: row['changed_by'] as String?,
      );

  static const _labels = {
    'visitType':          'Visit Type',
    'complaints':         'Chief Complaint',
    'notes':              'Notes',
    'bp':                 'Blood Pressure',
    'pulse':              'Pulse',
    'temperature':        'Temperature',
    'spo2':               'SpO2',
    'weight':             'Weight',
    'height':             'Height',
    'examPhysical':       'Physical Examination',
    'examSystemic':       'Systemic Examination',
    'examRadiology':      'Radiology',
    'clinicalImpression': 'Clinical Impression',
    'plan':               'Treatment Plan',
    'doctorAssigned':     'Doctor Assigned',
    'medications':        'Medications',
    'examination':        'Examination',
    'status':             'Status',
    // Patient fields
    'firstName':          'First Name',
    'lastName':           'Last Name',
    'phone':              'Phone',
    'allergies':          'Known Allergies',
    'weight_p':           'Weight',
    'bloodPressure':      'Blood Pressure',
    'temperature_p':      'Temperature',
    'medicalHistory':     'Medical History',
    'previousHistory':    'Previous History',
    'notes_p':            'Notes',
  };

  String get displayLabel => _labels[fieldName] ?? fieldName;
}

// ── Bulk sync: fetch all audit logs from API → SQLite ────────────────────────

/// Called fire-and-forget at login / session restore.
/// Replaces the entire local audit cache with fresh server data.
Future<void> syncAuditLogsFromApi(Ref ref) async {
  if (kIsWeb) return;
  try {
    final api = ref.read(apiClientProvider);
    final raw = await api.get<dynamic>('/audit/all');
    final data = (raw as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
    final entries = data.cast<Map<String, dynamic>>().toList();
    await ref.read(localAuditCacheProvider).replaceAll(entries);
    debugPrint('[AuditSync] cached ${entries.length} audit entries');
  } catch (e) {
    debugPrint('[AuditSync] skipped (server unavailable): $e');
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// ({entityType: "visit", entityId: "42"})
/// Always fetches fresh data from network so new edits appear immediately.
/// When offline: shows local SQLite cache (may include offline-written entries).
/// If cache is also empty offline, returns [] so History shows "no data" gracefully.
final auditLogProvider = FutureProvider.family<List<AuditEntry>, ({String entityType, String entityId})>(
  (ref, args) async {
    // 1. Network-first: always get latest entries from server.
    try {
      final api = ref.read(apiClientProvider);
      final raw = await api.get<dynamic>('/audit/${args.entityType}/${args.entityId}');
      final data = (raw as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
      return data
          .cast<Map<String, dynamic>>()
          .map(AuditEntry.fromJson)
          .toList();
    } catch (e) {
      // 2. Network failed — serve from local SQLite cache.
      if (!kIsWeb) {
        final rows = await ref
            .read(localAuditCacheProvider)
            .getForEntity(args.entityType, args.entityId);
        // Return cache (may be empty list — UI shows "no cached history" gracefully)
        return rows.map(AuditEntry.fromSqlite).toList();
      }
      rethrow;
    }
  },
);
