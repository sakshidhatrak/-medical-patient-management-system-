import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/storage/storage_provider.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../data/datasources/photo_datasource.dart';
import '../../domain/entities/photo_entity.dart';

// DataSource provider — token is read lazily per-operation in _buildDs()
final photoDataSourceProvider = Provider<PhotoDataSource>(
    (_) => PhotoSpringDataSource(null));

// ── State ─────────────────────────────────────────────────────────

class PhotoState {
  final List<PhotoEntity> photos;
  final bool isLoading;
  final bool isUploading;
  final String? error;

  const PhotoState({
    this.photos = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.error,
  });

  PhotoState copyWith({
    List<PhotoEntity>? photos,
    bool? isLoading,
    bool? isUploading,
    String? error,
    bool clearError = false,
  }) =>
      PhotoState(
        photos: photos ?? this.photos,
        isLoading: isLoading ?? this.isLoading,
        isUploading: isUploading ?? this.isUploading,
        error: clearError ? null : error ?? this.error,
      );
}

// ── Notifier (keyed by patientId) ─────────────────────────────────

class PhotoNotifier extends FamilyNotifier<PhotoState, String> {
  LocalPhotoStore get _store => ref.read(localPhotoStoreProvider);

  /// Builds a datasource with the current JWT token from storage.
  Future<PhotoSpringDataSource> _buildDs() async {
    final storage = ref.read(storageServiceProvider);
    final token = await storage.read(key: AppConfig.tokenKey);
    return PhotoSpringDataSource(token);
  }

  @override
  PhotoState build(String patientId) {
    // Auto-sync pending uploads when connectivity restores (mobile only)
    if (!kIsWeb) {
      ref.listen<bool?>(isOnlineProvider, (prev, online) {
        if (online == true && prev == false) {
          _syncPendingUploads(patientId);
        }
      });
    }
    Future.microtask(() => _load(patientId));
    return const PhotoState(isLoading: true);
  }

  Future<void> _load(String patientId) async {
    // 1. Load from local SQLite first (mobile only).
    // While loading, build a visitId/surgeryId map keyed by photo id so we
    // can restore these associations when the server response omits them.
    final localVisitIdMap   = <String, String?>{};
    final localSurgeryIdMap = <String, String?>{};
    if (!kIsWeb) {
      try {
        final rows = await _store.getForPatient(patientId);
        if (rows.isNotEmpty) {
          for (final r in rows) {
            final pid = r['id'] as String;
            localVisitIdMap[pid]   = r['visit_id']   as String?;
            localSurgeryIdMap[pid] = r['surgery_id'] as String?;
          }
          state = state.copyWith(
            photos: rows.map(_rowToEntity).toList(),
            isLoading: false,
          );
        }
      } catch (_) {}
    }

    // 2. Sync from Spring Boot if online
    if (ref.read(isOnlineProvider)) {
      try {
        final ds = await _buildDs();
        // Resolve UUID → server numeric ID in case this session registered
        // the patient and the backend assigned a different (numeric) ID.
        final resolvedId =
            await ref.read(patientIdMapProvider).resolve(patientId);
        final photos = await ds.getPhotos(patientId: resolvedId);
        if (!kIsWeb) {
          final pending = state.photos.where((p) => !p.isUploaded).toList();
          final serverIds = photos.map((p) => p.id).toSet();
          for (final p in pending) {
            if (serverIds.contains(p.id)) {
              await _store.markUploaded(p.id, p.url ?? '', p.storagePath);
            }
          }
          // Write server photos to SQLite, preserving local visitId/surgeryId
          // when the backend omits them (it may not echo back these foreign keys).
          for (final p in photos) {
            final row = _entityToRow(p);
            if (p.visitId == null && localVisitIdMap.containsKey(p.id)) {
              row['visit_id'] = localVisitIdMap[p.id];
            }
            if (p.surgeryId == null && localSurgeryIdMap.containsKey(p.id)) {
              row['surgery_id'] = localSurgeryIdMap[p.id];
            }
            await _store.insert(row);
          }
          final pendingStillLocal =
              pending.where((p) => !serverIds.contains(p.id)).toList();

          // Also include local SQLite photos that have a visit/surgery linkage
          // but are NOT represented in the server response.  This covers photos
          // that were uploaded when the visit still had a UUID id — the backend
          // stored them with visitId = null (different server id), but locally
          // they have the correct numeric visit_id after remapVisitId ran.
          final allLocalRows = await _store.getForPatient(patientId);
          final linkedLocal = allLocalRows
              .where((r) {
                final id  = r['id'] as String;
                final vid = r['visit_id'] as String?;
                final sid = r['surgery_id'] as String?;
                final uploaded = (r['is_uploaded'] as int? ?? 0) == 1;
                return !serverIds.contains(id) &&
                    uploaded &&
                    (vid != null || sid != null);
              })
              .map(_rowToEntity)
              .toList();

          // Build merged server photo list: if server didn't return visitId /
          // surgeryId but local SQLite has one, restore it so patient-detail
          // visit filters can match the photo to the right visit card.
          final mergedServerPhotos = photos.map((p) {
            final effectiveVisitId   = p.visitId   ?? localVisitIdMap[p.id];
            final effectiveSurgeryId = p.surgeryId ?? localSurgeryIdMap[p.id];
            if (effectiveVisitId == p.visitId && effectiveSurgeryId == p.surgeryId) {
              return p;
            }
            return PhotoEntity(
              id:          p.id,
              patientId:   p.patientId,
              visitId:     effectiveVisitId,
              surgeryId:   effectiveSurgeryId,
              storagePath: p.storagePath,
              url:         p.url,
              category:    p.category,
              caption:     p.caption,
              isUploaded:  p.isUploaded,
              localPath:   p.localPath,
              fileSize:    p.fileSize,
              createdAt:   p.createdAt,
            );
          }).toList();

          state = state.copyWith(
            photos: [...linkedLocal, ...pendingStillLocal, ...mergedServerPhotos],
            isLoading: false,
          );
        } else {
          state = state.copyWith(photos: photos, isLoading: false);
        }
      } catch (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<PhotoEntity?> upload({
    required Uint8List bytes,
    required String filename,
    required PhotoCategory category,
    String? visitId,
    String? surgeryId,
    String? caption,
  }) async {
    state = state.copyWith(isUploading: true, clearError: true);
    try {
      final online = ref.read(isOnlineProvider);

      // Resolve UUID → server numeric ID.
      // If the patient sync is still in-flight (Render cold-start can take
      // ~50 s), the map won't have an entry yet and resolvedId == arg.
      final isNumeric = RegExp(r'^\d+$').hasMatch(arg);
      final resolvedPatientId = (online && !kIsWeb && !isNumeric)
          ? await ref.read(patientIdMapProvider).resolve(arg)
          : arg;
      // Only upload immediately if we have the server numeric ID.
      final patientSynced = isNumeric || resolvedPatientId != arg;

      // If visitId / surgeryId is a UUID (non-numeric), uploading now would
      // cause the backend to store the photo with visitId = null (it ignores
      // non-numeric IDs). Save locally instead; the upload is triggered
      // automatically by visit_provider once the visit gets its numeric server ID.
      final visitIdReady  = visitId  == null || RegExp(r'^\d+$').hasMatch(visitId);
      final surgIdReady   = surgeryId == null || RegExp(r'^\d+$').hasMatch(surgeryId);

      if (online && patientSynced && visitIdReady && surgIdReady) {
        final ds = await _buildDs();
        final photo = await ds.uploadPhoto(
          patientId: resolvedPatientId,
          bytes: bytes,
          filename: filename,
          category: category,
          visitId: visitId,
          surgeryId: surgeryId,
          caption: caption,
        );
        if (!kIsWeb) await _store.insert(_entityToRow(photo));
        state = state.copyWith(
          photos: [photo, ...state.photos],
          isUploading: false,
        );
        return photo;
      }

      // Web can't save without network, and has no local store.
      if (kIsWeb) {
        state = state.copyWith(
            isUploading: false,
            error: online
                ? 'Patient is still syncing — please retry in a moment.'
                : 'Photo upload requires internet connection.');
        return null;
      }

      // Patient not yet synced (or offline): fall through to local save.
      // syncPending() will be called by patient_provider once the server ID
      // is known, completing the upload automatically.

      // Offline on mobile: save locally and mark pending
      final ext = _ext(filename);
      final isImage = ext == 'jpeg' || ext == 'png';
      final compressed = isImage ? await _compress(bytes) : bytes;
      final id = const Uuid().v4();
      final localPath = await _saveToLocal(id, compressed, ext);
      final now = DateTime.now();
      final storagePath = '$arg/${category.value}/$id.$ext';

      final pendingEntity = PhotoEntity(
        id: id,
        patientId: arg,
        visitId: visitId,
        surgeryId: surgeryId,
        storagePath: storagePath,
        url: null,
        category: category,
        caption: caption,
        isUploaded: false,
        localPath: localPath,
        createdAt: now,
      );

      await _store.insert({
        'id': id,
        'patient_id': arg,
        'visit_id': visitId,
        'surgery_id': surgeryId,
        'storage_path': storagePath,
        'url': null,
        'category': category.value,
        'caption': caption,
        'local_path': localPath,
        'file_size': compressed.length,
        'mime_type': 'image/$ext',
        'is_uploaded': 0,
        'created_at': now.toIso8601String(),
      });

      state = state.copyWith(
        photos: [pendingEntity, ...state.photos],
        isUploading: false,
      );
      return pendingEntity;
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      return null;
    }
  }

  /// Called by patient_provider after the patient's server ID is confirmed.
  /// Uploads any locally-saved pending photos that were queued while the
  /// patient sync was still in-flight.
  Future<void> syncPending() => _syncPendingUploads(arg);

  Future<void> delete(PhotoEntity photo) async {
    state = state.copyWith(
        photos: state.photos.where((p) => p.id != photo.id).toList());

    if (!kIsWeb && photo.localPath != null) {
      try {
        final f = File(photo.localPath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    if (!kIsWeb) await _store.delete(photo.id);

    if (photo.isUploaded) {
      try {
        final ds = await _buildDs();
        await ds.deletePhoto(photo.id, photo.storagePath);
      } catch (_) {}
    }
  }

  // ── Pending photo sync (mobile offline → Spring Boot) ─────────────

  Future<void> _syncPendingUploads(String patientId) async {
    if (kIsWeb) return;
    final pending = await _store.getPendingForPatient(patientId);
    if (pending.isEmpty) return;
    final ds = await _buildDs();

    for (final row in pending) {
      final localPath = row['local_path'] as String?;
      if (localPath == null) continue;
      final file = File(localPath);
      if (!await file.exists()) {
        await _store.delete(row['id'] as String);
        state = state.copyWith(
            photos: state.photos.where((p) => p.id != row['id']).toList());
        continue;
      }
      try {
        final bytes = await file.readAsBytes();
        final storedPid = row['patient_id'] as String;
        final resolvedPid =
            await ref.read(patientIdMapProvider).resolve(storedPid);
        final photo = await ds.uploadPhoto(
          patientId: resolvedPid,
          bytes: bytes,
          filename: '${row['id']}.jpg',
          category: PhotoCategoryX.fromValue(row['category'] as String),
          visitId: row['visit_id'] as String?,
          surgeryId: row['surgery_id'] as String?,
          caption: row['caption'] as String?,
          clientId: row['id'] as String,
        );
        // Use the local client id (row['id']) — not the server-returned numeric
        // id (photo.id) — so the correct local SQLite row is marked as uploaded.
        final localId = row['id'] as String;
        await _store.markUploaded(localId, photo.url ?? '', photo.storagePath);
        try { await file.delete(); } catch (_) {}
        // Update state using localId so the pending photo is replaced correctly.
        state = state.copyWith(
          photos: state.photos.map((p) {
            if (p.id != localId) return p;
            return PhotoEntity(
              id:          p.id,
              patientId:   p.patientId,
              visitId:     p.visitId,
              surgeryId:   p.surgeryId,
              storagePath: photo.storagePath,
              url:         photo.url,
              category:    p.category,
              caption:     p.caption,
              isUploaded:  true,
              localPath:   null,
              fileSize:    photo.fileSize ?? p.fileSize,
              createdAt:   p.createdAt,
            );
          }).toList(),
        );
      } catch (_) {}
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────

  PhotoEntity _rowToEntity(Map<String, dynamic> r) => PhotoEntity(
        id: r['id'] as String,
        patientId: r['patient_id'] as String,
        visitId: r['visit_id'] as String?,
        surgeryId: r['surgery_id'] as String?,
        storagePath: r['storage_path'] as String,
        url: r['url'] as String?,
        category: PhotoCategoryX.fromValue(r['category'] as String),
        caption: r['caption'] as String?,
        isUploaded: (r['is_uploaded'] as int? ?? 0) == 1,
        localPath: r['local_path'] as String?,
        fileSize: r['file_size'] as int?,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  Map<String, dynamic> _entityToRow(PhotoEntity p) => {
        'id': p.id,
        'patient_id': p.patientId,
        'visit_id': p.visitId,
        'surgery_id': p.surgeryId,
        'storage_path': p.storagePath,
        'url': p.url,
        'category': p.category.value,
        'caption': p.caption,
        'local_path': p.localPath,
        'file_size': p.fileSize,
        'is_uploaded': p.isUploaded ? 1 : 0,
        'created_at': p.createdAt.toIso8601String(),
      };

  Future<String> _saveToLocal(String id, Uint8List bytes, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/offline_photos');
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File('${folder.path}/$id.$ext');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<Uint8List> _compress(Uint8List bytes) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 75,
      minWidth: 1080,
      minHeight: 1080,
    );
    return result.length < bytes.length ? Uint8List.fromList(result) : bytes;
  }

  String _ext(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png'))  return 'png';
    if (lower.endsWith('.pdf'))  return 'pdf';
    if (lower.endsWith('.docx')) return 'docx';
    if (lower.endsWith('.doc'))  return 'doc';
    if (lower.endsWith('.xlsx')) return 'xlsx';
    if (lower.endsWith('.xls'))  return 'xls';
    return 'jpeg';
  }

  List<PhotoEntity> forVisit(String visitId) =>
      state.photos.where((p) => p.visitId == visitId).toList();

  List<PhotoEntity> forSurgery(String surgeryId) =>
      state.photos.where((p) => p.surgeryId == surgeryId).toList();
}

final photoProvider =
    NotifierProviderFamily<PhotoNotifier, PhotoState, String>(
        PhotoNotifier.new);
