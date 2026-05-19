import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/patients/data/datasources/patient_local_datasource.dart';
import '../../features/patients/data/datasources/sync_queue_datasource.dart';

/// Processes the sync queue and marks patients as synced.
/// The mock implementation simulates a 300 ms network call that always succeeds.
/// Replace `_mockSyncToServer` with real API calls when the backend is ready.
class SyncService {
  final SyncQueueLocalDataSource _queue;

  SyncService(this._queue);

  /// Sync all pending items.
  /// Accepts [localDataSource] so it can mark each patient as synced after
  /// the mock network call succeeds.
  Future<void> syncAll(PatientLocalDataSource localDataSource) async {
    final items = await _queue.getAll();
    if (items.isEmpty) return;

    final completedIds = <String>[];

    for (final item in items) {
      try {
        await _mockSyncToServer(item.entityId, item.operation, item.payload);

        // For non-delete operations, mark the patient as synced in SQLite.
        if (item.operation != 'delete') {
          await localDataSource.markAsSynced(item.entityId);
        }

        completedIds.add(item.id);
      } catch (_) {
        // On failure, just increment attempts — will retry next time.
        await _queue.incrementAttempts(item.id);
      }
    }

    if (completedIds.isNotEmpty) {
      await _queue.clearCompleted(completedIds);
    }
  }

  /// Sync a single item immediately (fire-and-forget helper).
  Future<void> syncPatient(
    String patientId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    await _mockSyncToServer(patientId, operation, payload);
  }

  /// Mock network call — simulates 300 ms latency and always succeeds.
  /// Replace with a real HTTP/gRPC call to the backend.
  Future<void> _mockSyncToServer(
    String entityId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // TODO: replace with: await _apiClient.post('/patients', data: payload);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(syncQueueLocalDataSourceProvider));
});
