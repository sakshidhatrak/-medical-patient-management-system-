import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/models/print_field.dart';
import '../domain/models/report_section.dart';
import '../presentation/providers/print_config_provider.dart';

// ── PDF colour palette ────────────────────────────────────────────────────────

const _kPrimary = PdfColor.fromInt(0xFF6C63FF);
const _kTextPrimary = PdfColor.fromInt(0xFF1A1D2E);
const _kTextSecondary = PdfColor.fromInt(0xFF8A8EAD);
const _kBorder = PdfColor.fromInt(0xFFE8E9F0);
const _kSurface = PdfColor.fromInt(0xFFF8F9FE);

// ── Service ───────────────────────────────────────────────────────────────────

class PdfExportService {
  PdfExportService._();

  // ── Public API ────────────────────────────────────────────────────────────

  static Future<Uint8List> buildPdf(PrintConfigState config) async {
    final doc = pw.Document(
      title: 'Patient Medical Report',
      author: 'MediManage EMR',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        header: (_) => _buildHeader(),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => _buildBody(config),
      ),
    );

    return doc.save();
  }

  static Future<void> printReport(PrintConfigState config) async {
    await Printing.layoutPdf(
      name: 'Patient Medical Report',
      onLayout: (_) => buildPdf(config),
    );
  }

  static Future<void> exportPdf(PrintConfigState config) async {
    final bytes = await buildPdf(config);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'patient_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MEDIMANAGE MEDICAL CENTER',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _kPrimary,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'General Hospital & Healthcare Services',
                  style: const pw.TextStyle(fontSize: 9, color: _kTextSecondary),
                ),
                pw.Text(
                  '123 Medical Drive, Healthcare City, HC 10001',
                  style: const pw.TextStyle(fontSize: 9, color: _kTextSecondary),
                ),
                pw.Text(
                  'Tel: +1 (555) 000-1234  |  info@medimanage.com',
                  style: const pw.TextStyle(fontSize: 9, color: _kTextSecondary),
                ),
              ],
            ),
            // QR code placeholder
            pw.Container(
              width: 56,
              height: 56,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kBorder),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                color: _kSurface,
              ),
              child: pw.Center(
                child: pw.Text(
                  'QR',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: _kTextSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _kBorder, thickness: 1),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'PATIENT MEDICAL REPORT',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _kTextPrimary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'Generated: ${_formatDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: _kTextSecondary),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _kBorder, thickness: 1),
        pw.SizedBox(height: 8),
        // Patient summary bar
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _kSurface,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: _kBorder),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _labelValue('Patient', '${kMockPatientData['firstName']} ${kMockPatientData['lastName']}'),
              _labelValue('DOB', kMockPatientData['dob'] ?? '—'),
              _labelValue('Gender', kMockPatientData['gender'] ?? '—'),
              _labelValue('Blood Type', kMockPatientData['bloodType'] ?? '—'),
              _labelValue(
                'Report ID',
                'RPT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Divider(color: _kBorder, thickness: 0.5),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Doctor Signature: _______________________',
                    style: const pw.TextStyle(fontSize: 9, color: _kTextSecondary)),
                pw.SizedBox(height: 2),
                pw.Text('Date: _______________',
                    style: const pw.TextStyle(fontSize: 9, color: _kTextSecondary)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Report generated by MediManage EMR System v1.0',
                    style: const pw.TextStyle(fontSize: 8, color: _kTextSecondary)),
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: _kTextSecondary)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Body sections ─────────────────────────────────────────────────────────

  static List<pw.Widget> _buildBody(PrintConfigState config) {
    final widgets = <pw.Widget>[];
    for (final sectionId in config.sectionOrder) {
      final section = sectionById(sectionId);
      if (section == null) continue;
      final fields = section.enabledFields(config.enabledFieldIds);
      if (fields.isEmpty) continue;
      widgets.add(_buildSection(section.title, fields));
      widgets.add(pw.SizedBox(height: 12));
    }
    return widgets;
  }

  static pw.Widget _buildSection(String title, List<PrintField> fields) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Section header
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFEEECFF),
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 3,
                height: 14,
                decoration: const pw.BoxDecoration(
                  color: _kPrimary,
                  borderRadius:
                      pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                title.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _kPrimary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        // Field rows
        pw.Table(
          border: pw.TableBorder.all(color: _kBorder, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(2),
          },
          children: fields.map((f) => _buildTableRow(f)).toList(),
        ),
      ],
    );
  }

  static pw.TableRow _buildTableRow(PrintField field) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.white),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: pw.Text(
            field.label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _kTextSecondary,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: pw.Text(
            kMockPatientData[field.id] ?? '—',
            style: const pw.TextStyle(fontSize: 9, color: _kTextPrimary),
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static pw.Widget _labelValue(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 7, color: _kTextSecondary)),
        pw.SizedBox(height: 1),
        pw.Text(value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _kTextPrimary,
            )),
      ],
    );
  }

  static String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m';
  }
}
