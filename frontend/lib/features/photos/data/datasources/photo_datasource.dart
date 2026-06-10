import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/photo_entity.dart';

abstract interface class PhotoDataSource {
  Future<PhotoEntity> uploadPhoto({
    required String patientId,
    required Uint8List bytes,
    required String filename,
    required PhotoCategory category,
    String? visitId,
    String? surgeryId,
    String? caption,
  });

  Future<List<PhotoEntity>> getPhotos({
    required String patientId,
    String? visitId,
    String? surgeryId,
  });

  Future<void> deletePhoto(String photoId, String storagePath);
}

class PhotoSupabaseDataSource implements PhotoDataSource {
  final sb.SupabaseClient _client;
  static const _bucket = 'patient-photos';

  const PhotoSupabaseDataSource(this._client);

  @override
  Future<PhotoEntity> uploadPhoto({
    required String patientId,
    required Uint8List bytes,
    required String filename,
    required PhotoCategory category,
    String? visitId,
    String? surgeryId,
    String? caption,
  }) async {
    try {
      // ── Compress (WhatsApp-style ~500 KB max) ─────────────────
      final compressed = kIsWeb
          ? bytes   // flutter_image_compress doesn't work on web
          : await _compress(bytes);

      // ── Upload to Supabase Storage ────────────────────────────
      final ext  = _ext(filename);
      final id   = const Uuid().v4();
      final path = '$patientId/${category.value}/$id.$ext';

      await _client.storage.from(_bucket).uploadBinary(
            path,
            compressed,
            fileOptions: sb.FileOptions(
              contentType: 'image/$ext',
              upsert: false,
            ),
          );

      final url = _client.storage.from(_bucket).getPublicUrl(path);

      // ── Save metadata ─────────────────────────────────────────
      final now = DateTime.now().toIso8601String();
      final data = await _client.from('photos').insert({
        'id':           id,
        'patient_id':   patientId,
        'visit_id':     visitId,
        'surgery_id':   surgeryId,
        'storage_path': path,
        'url':          url,
        'category':     category.value,
        'caption':      caption,
        'file_size':    compressed.length,
        'mime_type':    'image/$ext',
        'is_uploaded':  true,
        'created_at':   now,
      }).select().single();

      return _fromJson(data as Map<String, dynamic>);
    } on sb.StorageException catch (e) {
      throw ServerException('Photo upload failed: ${e.message}',
          code: 'UPLOAD_ERROR');
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'DB_ERROR');
    }
  }

  @override
  Future<List<PhotoEntity>> getPhotos({
    required String patientId,
    String? visitId,
    String? surgeryId,
  }) async {
    try {
      var query = _client
          .from('photos')
          .select()
          .eq('patient_id', patientId);

      if (visitId != null) query = query.eq('visit_id', visitId);
      if (surgeryId != null) query = query.eq('surgery_id', surgeryId);

      final data = await query.order('created_at', ascending: false);
      return (data as List)
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'FETCH_ERROR');
    }
  }

  @override
  Future<void> deletePhoto(String photoId, String storagePath) async {
    await _client.storage.from(_bucket).remove([storagePath]);
    await _client.from('photos').delete().eq('id', photoId);
  }

  // ── Compression ──────────────────────────────────────────────

  Future<Uint8List> _compress(Uint8List bytes) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 75,
      minWidth: 1080,
      minHeight: 1080,
    );
    // Only use compressed if it's actually smaller
    return result.length < bytes.length ? Uint8List.fromList(result) : bytes;
  }

  String _ext(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpeg';
    return 'jpeg';
  }

  PhotoEntity _fromJson(Map<String, dynamic> j) => PhotoEntity(
        id:          j['id'] as String,
        patientId:   j['patient_id'] as String,
        visitId:     j['visit_id'] as String?,
        surgeryId:   j['surgery_id'] as String?,
        storagePath: j['storage_path'] as String,
        url:         j['url'] as String?,
        category:    PhotoCategoryX.fromValue(j['category'] as String),
        caption:     j['caption'] as String?,
        isUploaded:  j['is_uploaded'] as bool? ?? false,
        createdAt:   DateTime.parse(j['created_at'] as String),
      );
}
