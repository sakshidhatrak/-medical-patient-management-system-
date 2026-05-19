import 'dart:typed_data';

// ── Enum ──────────────────────────────────────────────────────────────────────

enum ReportFileType { prescription, labReport, xray, mriCt }

extension ReportFileTypeLabel on ReportFileType {
  String get label => switch (this) {
        ReportFileType.prescription => 'Prescription',
        ReportFileType.labReport => 'Lab Report',
        ReportFileType.xray => 'X-Ray',
        ReportFileType.mriCt => 'MRI / CT Scan',
      };

  String get shortLabel => switch (this) {
        ReportFileType.prescription => 'Rx',
        ReportFileType.labReport => 'Lab',
        ReportFileType.xray => 'X-Ray',
        ReportFileType.mriCt => 'Scan',
      };

  // Maps to the printField id used in the config panel
  String get fieldId => switch (this) {
        ReportFileType.prescription => 'prescription',
        ReportFileType.labReport => 'labReport',
        ReportFileType.xray => 'xray',
        ReportFileType.mriCt => 'mriCt',
      };
}

// ── Model ─────────────────────────────────────────────────────────────────────

class UploadedMedicalFile {
  final String id;
  final String name;
  final String extension; // pdf | jpg | jpeg | png
  final int sizeBytes;
  final Uint8List bytes;
  final ReportFileType type;
  final DateTime uploadedAt;

  const UploadedMedicalFile({
    required this.id,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.bytes,
    required this.type,
    required this.uploadedAt,
  });

  bool get isImage =>
      extension == 'jpg' || extension == 'jpeg' || extension == 'png';

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) =>
      other is UploadedMedicalFile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
