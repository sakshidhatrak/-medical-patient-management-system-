import 'package:flutter/material.dart';

/// Small chip that indicates whether a record has been synced to the server.
/// Green cloud = synced, orange cloud = pending upload.
class SyncStatusBadge extends StatelessWidget {
  final String syncStatus; // 'synced' | 'pending'
  final bool compact; // if true, show icon only (no label)

  const SyncStatusBadge({
    super.key,
    required this.syncStatus,
    this.compact = false,
  });

  bool get _isSynced => syncStatus == 'synced';

  @override
  Widget build(BuildContext context) {
    if (_isSynced) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFE8F5E9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.cloud_done_rounded, size: 13, color: Color(0xFF2E7D32)),
      );
    }
    // Pending: simple grey dot — no distracting orange icon
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Color(0xFFBDBDBD),
        shape: BoxShape.circle,
      ),
    );
  }
}
