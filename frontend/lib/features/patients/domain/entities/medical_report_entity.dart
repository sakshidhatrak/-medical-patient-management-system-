import 'dart:typed_data';

import 'package:equatable/equatable.dart';

enum ReportType { medicalReport, prescription, labReport, scan }

extension ReportTypeLabel on ReportType {
  String get label => switch (this) {
        ReportType.medicalReport => 'Medical Report',
        ReportType.prescription => 'Prescription',
        ReportType.labReport => 'Lab Report',
        ReportType.scan => 'X-Ray / MRI / CT',
      };

  String get shortLabel => switch (this) {
        ReportType.medicalReport => 'Report',
        ReportType.prescription => 'Rx',
        ReportType.labReport => 'Lab',
        ReportType.scan => 'Scan',
      };
}

class MedicalReportEntity extends Equatable {
  final String id;
  final String patientId;
  final String fileName;
  final String extension; // pdf, jpg, png
  final ReportType reportType;
  final int fileSizeBytes;
  final Uint8List bytes;
  final DateTime uploadedAt;

  const MedicalReportEntity({
    required this.id,
    required this.patientId,
    required this.fileName,
    required this.extension,
    required this.reportType,
    required this.fileSizeBytes,
    required this.bytes,
    required this.uploadedAt,
  });

  String get sizeLabel {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isImage =>
      extension.toLowerCase() == 'jpg' ||
      extension.toLowerCase() == 'jpeg' ||
      extension.toLowerCase() == 'png';

  @override
  List<Object?> get props =>
      [id, patientId, fileName, reportType, fileSizeBytes, uploadedAt];
}
