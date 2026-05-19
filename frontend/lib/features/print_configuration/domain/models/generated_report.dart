import 'dart:typed_data';

// ── Enum ──────────────────────────────────────────────────────────────────────

enum ReportStatus { generating, ready, error }

extension ReportStatusLabel on ReportStatus {
  String get label => switch (this) {
        ReportStatus.generating => 'Generating…',
        ReportStatus.ready => 'Ready',
        ReportStatus.error => 'Error',
      };
}

// ── Model ─────────────────────────────────────────────────────────────────────

class GeneratedReport {
  final String id;
  final String patientName;
  final String templateName;
  final Set<String> includedFieldIds;
  final DateTime generatedAt;
  final Uint8List? pdfBytes;
  final ReportStatus status;
  final String? errorMessage;

  const GeneratedReport({
    required this.id,
    required this.patientName,
    required this.templateName,
    required this.includedFieldIds,
    required this.generatedAt,
    this.pdfBytes,
    this.status = ReportStatus.generating,
    this.errorMessage,
  });

  GeneratedReport copyWith({
    Uint8List? pdfBytes,
    ReportStatus? status,
    String? errorMessage,
  }) =>
      GeneratedReport(
        id: id,
        patientName: patientName,
        templateName: templateName,
        includedFieldIds: includedFieldIds,
        generatedAt: generatedAt,
        pdfBytes: pdfBytes ?? this.pdfBytes,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  bool get isReady => status == ReportStatus.ready && pdfBytes != null;

  @override
  bool operator ==(Object other) =>
      other is GeneratedReport && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
