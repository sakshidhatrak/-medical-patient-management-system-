import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/env_config.dart';
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
    String? clientId,
  });

  Future<List<PhotoEntity>> getPhotos({
    required String patientId,
    String? visitId,
    String? surgeryId,
  });

  Future<void> deletePhoto(String photoId, String storagePath);
}

/// Stores photos on the local Spring Boot server.
/// Files saved to ./uploads/{patientId}/{category}/{uuid}.ext on the server.
/// Metadata saved to local PostgreSQL photos table.
class PhotoSpringDataSource implements PhotoDataSource {
  late final Dio _dio;

  PhotoSpringDataSource(String? token) {
    _dio = Dio(BaseOptions(
      baseUrl: EnvConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  void updateToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  @override
  Future<PhotoEntity> uploadPhoto({
    required String patientId,
    required Uint8List bytes,
    required String filename,
    required PhotoCategory category,
    String? visitId,
    String? surgeryId,
    String? caption,
    String? clientId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename.isEmpty ? 'photo.jpeg' : filename,
          contentType: DioMediaType.parse(_mimeFromFilename(filename)),
        ),
        'category': category.value,
        if (caption != null) 'caption': caption,
        if (visitId != null) 'visitId': visitId,
        if (surgeryId != null) 'surgeryId': surgeryId,
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/patients/$patientId/photos/upload',
        data: formData,
      );
      final data = response.data?['data'] as Map<String, dynamic>;
      return _fromJson(data);
    } on DioException catch (e) {
      throw ServerException(
        'Photo upload failed: ${e.response?.data ?? e.message}',
        code: 'UPLOAD_ERROR',
      );
    }
  }

  @override
  Future<List<PhotoEntity>> getPhotos({
    required String patientId,
    String? visitId,
    String? surgeryId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/patients/$patientId/photos',
      );
      final list = response.data?['data'] as List<dynamic>? ?? [];
      var photos = list
          .cast<Map<String, dynamic>>()
          .map(_fromJson)
          .toList();
      if (visitId != null) {
        photos = photos.where((p) => p.visitId == visitId).toList();
      }
      if (surgeryId != null) {
        photos = photos.where((p) => p.surgeryId == surgeryId).toList();
      }
      return photos;
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?.toString() ?? e.message ?? 'Fetch failed',
        code: 'FETCH_ERROR',
      );
    }
  }

  @override
  Future<void> deletePhoto(String photoId, String storagePath) async {
    try {
      await _dio.delete<void>('/photos/$photoId');
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data?.toString() ?? e.message ?? 'Delete failed',
        code: 'DELETE_ERROR',
      );
    }
  }

  PhotoEntity _fromJson(Map<String, dynamic> j) {
    // viewUrl from backend: /api/photos/file/{storagePath}
    // Prefix with server origin for full URL usable in Image.network()
    final viewUrl = j['viewUrl'] as String?;
    final displayUrl = viewUrl != null && viewUrl.startsWith('/api/')
        ? '${EnvConfig.baseUrl.replaceAll('/api', '')}$viewUrl'
        : viewUrl;

    return PhotoEntity(
      id: (j['id'] as Object).toString(),
      patientId: (j['patientId'] as Object).toString(),
      visitId: j['visitId'] != null ? j['visitId'].toString() : null,
      surgeryId: j['surgeryId'] != null ? j['surgeryId'].toString() : null,
      storagePath: j['storagePath'] as String,
      url: displayUrl,
      category: PhotoCategoryX.fromValue(j['category'] as String? ?? 'visit'),
      caption: j['caption'] as String?,
      isUploaded: j['isUploaded'] as bool? ?? true,
      fileSize: j['fileSize'] as int?,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }

  String _mimeFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png'))  return 'image/png';
    if (lower.endsWith('.pdf'))  return 'application/pdf';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.doc'))  return 'application/msword';
    if (lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (lower.endsWith('.xls'))  return 'application/vnd.ms-excel';
    return 'image/jpeg';
  }
}
