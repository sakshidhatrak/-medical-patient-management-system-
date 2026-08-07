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
    final color = _isSynced ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    final bg = _isSynced
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);
    final icon = _isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded;
    final label = _isSynced ? 'Synced' : 'Pending';

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 13, color: color),
    );
  }
}
