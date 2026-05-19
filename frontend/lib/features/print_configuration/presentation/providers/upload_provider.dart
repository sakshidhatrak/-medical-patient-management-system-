import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/uploaded_medical_file.dart';

// ── Upload state ──────────────────────────────────────────────────────────────

class UploadState {
  final List<UploadedMedicalFile> files;
  final bool isPicking;
  final String? errorMessage;

  const UploadState({
    this.files = const [],
    this.isPicking = false,
    this.errorMessage,
  });

  UploadState copyWith({
    List<UploadedMedicalFile>? files,
    bool? isPicking,
    String? errorMessage,
    bool clearError = false,
  }) =>
      UploadState(
        files: files ?? this.files,
        isPicking: isPicking ?? this.isPicking,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );

  List<UploadedMedicalFile> filesOfType(ReportFileType type) =>
      files.where((f) => f.type == type).toList();
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class UploadNotifier extends Notifier<UploadState> {
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  @override
  UploadState build() => const UploadState();

  Future<void> pickFiles(ReportFileType type) async {
    if (state.isPicking) return;
    state = state.copyWith(isPicking: true, clearError: true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null) {
        state = state.copyWith(isPicking: false);
        return;
      }

      final oversized = <String>[];
      final added = <UploadedMedicalFile>[];

      for (final f in result.files) {
        if (f.bytes == null) continue;
        if (f.size > _maxFileSizeBytes) {
          oversized.add(f.name);
          continue;
        }
        // Skip duplicates within the same type
        final duplicate = state.files.any(
          (x) => x.name == f.name && x.type == type,
        );
        if (duplicate) continue;

        added.add(UploadedMedicalFile(
          id: const Uuid().v4(),
          name: f.name,
          extension: (f.extension ?? 'bin').toLowerCase(),
          sizeBytes: f.size,
          bytes: f.bytes!,
          type: type,
          uploadedAt: DateTime.now(),
        ));
      }

      state = state.copyWith(
        files: [...state.files, ...added],
        isPicking: false,
        errorMessage: oversized.isEmpty
            ? null
            : '${oversized.join(', ')} exceeded the 10 MB limit.',
      );
    } catch (e) {
      state = state.copyWith(
        isPicking: false,
        errorMessage: 'Could not pick files: $e',
      );
    }
  }

  void removeFile(String fileId) {
    state = state.copyWith(
      files: state.files.where((f) => f.id != fileId).toList(),
      clearError: true,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void addFileBytes({
    required String name,
    required String extension,
    required int sizeBytes,
    required Uint8List bytes,
    required ReportFileType type,
  }) {
    if (sizeBytes > _maxFileSizeBytes) {
      state = state.copyWith(
          errorMessage: '$name exceeds the 10 MB limit.');
      return;
    }
    state = state.copyWith(
      files: [
        ...state.files,
        UploadedMedicalFile(
          id: const Uuid().v4(),
          name: name,
          extension: extension.toLowerCase(),
          sizeBytes: sizeBytes,
          bytes: bytes,
          type: type,
          uploadedAt: DateTime.now(),
        ),
      ],
      clearError: true,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final uploadProvider =
    NotifierProvider<UploadNotifier, UploadState>(UploadNotifier.new);
