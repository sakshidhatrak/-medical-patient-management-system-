import 'package:equatable/equatable.dart';

enum PhotoCategory {
  visit,
  examination,
  radiology,
  treatment,
  surgeryFindings,
  surgeryOtNotes,
}

extension PhotoCategoryX on PhotoCategory {
  String get value => switch (this) {
        PhotoCategory.visit           => 'visit',
        PhotoCategory.examination     => 'examination',
        PhotoCategory.radiology       => 'radiology',
        PhotoCategory.treatment       => 'treatment',
        PhotoCategory.surgeryFindings => 'surgery_findings',
        PhotoCategory.surgeryOtNotes  => 'surgery_ot_notes',
      };

  String get label => switch (this) {
        PhotoCategory.visit           => 'Visit',
        PhotoCategory.examination     => 'Examination',
        PhotoCategory.radiology       => 'Radiology',
        PhotoCategory.treatment       => 'Treatment',
        PhotoCategory.surgeryFindings => 'Surgical Findings',
        PhotoCategory.surgeryOtNotes  => 'OT Notes',
      };

  static PhotoCategory fromValue(String v) => switch (v) {
        'examination'     => PhotoCategory.examination,
        'radiology'       => PhotoCategory.radiology,
        'treatment'       => PhotoCategory.treatment,
        'surgery_findings' => PhotoCategory.surgeryFindings,
        'surgery_ot_notes' => PhotoCategory.surgeryOtNotes,
        _                 => PhotoCategory.visit,
      };
}

class PhotoEntity extends Equatable {
  final String id;
  final String patientId;
  final String? visitId;
  final String? surgeryId;
  final String storagePath;
  final String? url;
  final PhotoCategory category;
  final String? caption;
  final bool isUploaded;
  final String? localPath;   // for offline
  final DateTime createdAt;

  const PhotoEntity({
    required this.id,
    required this.patientId,
    this.visitId,
    this.surgeryId,
    required this.storagePath,
    this.url,
    required this.category,
    this.caption,
    this.isUploaded = false,
    this.localPath,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, patientId, storagePath];
}
