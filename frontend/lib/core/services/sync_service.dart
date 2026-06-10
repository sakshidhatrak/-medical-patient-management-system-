// Sync service — stub for web. Full offline sync implemented for mobile.
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncService {
  Future<void> syncAll(dynamic localDataSource) async {
    // No-op on web — all data is live via Supabase.
  }
}

final syncServiceProvider = Provider<SyncService>((_) => SyncService());
