import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ── Colour palette ────────────────────────────────────────────────────────────

const _kPrimary = PdfColor.fromInt(0xFF6C63FF);
const _kText = PdfColor.fromInt(0xFF1A1D2E);
const _kSub = PdfColor.fromInt(0xFF8A8EAD);
const _kBorder = PdfColor.fromInt(0xFFE8E9F0);
const _kBg = PdfColor.fromInt(0xFFF8F9FE);

// ── Service ───────────────────────────────────────────────────────────────────

/// Generates and prints/exports a PDF from hand-picked form fields.
/// [fields] is an ordered list of (label, value) pairs.
class PatientPrintService {
  PatientPrintService._();

  // ── Public ────────────────────────────────────────────────────────────────

  static Future<void> printFields({
    required String patientName,
    required List<({String label, String value})> fields,
  }) async {
    await Printing.layoutPdf(
      name: 'Patient Report — $patientName',
      onLayout: (_) => _buildPdf(patientName: patientName, fields: fields),
    );
  }

  static Future<void> exportPdf({
    required String patientName,
    required List<({String label, String value})> fields,
  }) async {
    final bytes =
        await _buildPdf(patientName: patientName, fields: fields);
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'patient_${patientName.replaceAll(' ', '_').toLowerCase()}.pdf',
    );
  }

  // ── PDF builder ───────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf({
    required String patientName,
    required List<({String label, String value})> fields,
  }) async {
    final doc = pw.Document(
      title: 'Patient Report',
      author: 'MediManage EMR',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        header: (_) => _header(patientName),
        footer: (ctx) => _footer(ctx),
        build: (_) => [_body(fields)],
      ),
    );

    return doc.save();
  }

  // ── Page header ───────────────────────────────────────────────────────────

  static pw.Widget _header(String patientName) {
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
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _kPrimary,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'General Hospital & Healthcare Services',
                  style: const pw.TextStyle(
                      fontSize: 8, color: _kSub),
                ),
                pw.Text(
                  '123 Medical Drive, Healthcare City  ·  +1 (555) 000-1234',
                  style: const pw.TextStyle(
                      fontSize: 8, color: _kSub),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kBorder),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
                color: _kBg,
              ),
              child: pw.Text('QR',
                  style: const pw.TextStyle(
                      fontSize: 9, color: _kSub)),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _kBorder, thickness: 0.8),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'PATIENT REPORT',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _kText,
              letterSpacing: 2.0,
            ),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'Patient: $patientName  ·  Generated: ${_now()}',
            style: const pw.TextStyle(fontSize: 8, color: _kSub),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _kBorder, thickness: 0.8),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // ── Page footer ───────────────────────────────────────────────────────────

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Divider(color: _kBorder, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Doctor Signature: _______________________',
              style: const pw.TextStyle(fontSize: 8, color: _kSub),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} / ${ctx.pagesCount}  ·  MediManage EMR v1.0',
              style: const pw.TextStyle(fontSize: 8, color: _kSub),
            ),
          ],
        ),
      ],
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  static pw.Widget _body(
      List<({String label, String value})> fields) {
    return pw.Table(
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(2),
      },
      children: fields.map((f) {
        return pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              child: pw.Text(
                f.label,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _kSub,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              child: pw.Text(
                f.value.isEmpty ? '—' : f.value,
                style: const pw.TextStyle(fontSize: 9, color: _kText),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _now() {
    final dt = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m';
  }
}
