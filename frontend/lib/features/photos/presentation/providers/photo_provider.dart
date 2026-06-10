import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../data/datasources/photo_datasource.dart';
import '../../domain/entities/photo_entity.dart';

final _supabaseProvider = Provider((_) => sb.Supabase.instance.client);

final photoDataSourceProvider = Provider<PhotoDataSource>((ref) =>
    PhotoSupabaseDataSource(ref.watch(_supabaseProvider)));

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
        photos:      photos      ?? this.photos,
        isLoading:   isLoading   ?? this.isLoading,
        isUploading: isUploading ?? this.isUploading,
        error:       clearError  ? null : error ?? this.error,
      );
}

// ── Notifier (keyed by patientId) ─────────────────────────────────

class PhotoNotifier extends FamilyNotifier<PhotoState, String> {
  PhotoDataSource get _ds => ref.read(photoDataSourceProvider);

  @override
  PhotoState build(String patientId) {
    _load(patientId);
    return const PhotoState(isLoading: true);
  }

  Future<void> _load(String patientId,
      {String? visitId, String? surgeryId}) async {
    try {
      final photos = await _ds.getPhotos(
        patientId: patientId,
        visitId:   visitId,
        surgeryId: surgeryId,
      );
      state = state.copyWith(photos: photos, isLoading: false);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: e.toString());
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
      final photo = await _ds.uploadPhoto(
        patientId: arg,
        bytes:     bytes,
        filename:  filename,
        category:  category,
        visitId:   visitId,
        surgeryId: surgeryId,
        caption:   caption,
      );
      state = state.copyWith(
        photos:      [photo, ...state.photos],
        isUploading: false,
      );
      return photo;
    } catch (e) {
      state = state.copyWith(
          isUploading: false, error: e.toString());
      return null;
    }
  }

  Future<void> delete(PhotoEntity photo) async {
    await _ds.deletePhoto(photo.id, photo.storagePath);
    state = state.copyWith(
        photos: state.photos.where((p) => p.id != photo.id).toList());
  }

  List<PhotoEntity> forVisit(String visitId) =>
      state.photos.where((p) => p.visitId == visitId).toList();

  List<PhotoEntity> forSurgery(String surgeryId) =>
      state.photos.where((p) => p.surgeryId == surgeryId).toList();
}

final photoProvider =
    NotifierProviderFamily<PhotoNotifier, PhotoState, String>(
        PhotoNotifier.new);
