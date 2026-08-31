import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../presentation/providers/print_config_provider.dart';

// ── Clinic constants ──────────────────────────────────────────────────────────

class _Clinic {
  static const name         = 'The Brain & Spine Clinic';
  static const tagline      = 'Excellence, Ethics, Efficiency';
  static const doctor       = 'Dr. Harshal S. Chaudhari';
  static const designation  = 'Brain and Spine surgeon/ Neurosurgeon';
  static const degree1      = 'M.B.B.S., M.S. General Surgery (K.E.M. Hospital, Mumbai)';
  static const degree2      = 'M.Ch. Neurosurgery (G.M.C., Goa)';
  static const degree3      = 'Fellow in Neurosurgical Oncology (Tata Memorial Hospital)';
  static const website      = 'www.drharshalchaudhari.com';
  static const phone        = '+91 83900 24528';
  static const address      =
      'C/0 Nashik Hematology Services- 6th Floor, S.K. Empire, Near Ved Mandir, Mico Circle, Nashik';
  static const specialisations = [
    'Brain and Spine Injury',
    'Vascular Neurosurgery',
    'Brain tumors',
    'Spine tumors',
    'Pediatric Neurosurgery',
    'Degenerative spine disease',
    'Spondylosis',
    'Slip disc',
    'Cranio-Vertebral junction abnormality',
    'Root or epidural block',
    'Endoscopic skull base surgery',
    'Hydrocephalus',
    'Minimally invasive spine surgery',
  ];
}

// ── Colour palette ─────────────────────────────────────────────────────────────

const _kMaroon    = PdfColor.fromInt(0xFF8B1A1A);
const _kNavy      = PdfColor.fromInt(0xFF1A3565);
const _kBannerBg  = PdfColor.fromInt(0xFFBDD5EA);
const _kSectionBg = PdfColor.fromInt(0xFFCCE2F4);
const _kLeftBg    = PdfColor.fromInt(0xFFF0ECD8);
const _kRedBar    = PdfColor.fromInt(0xFFCC0000);
const _kWhite     = PdfColors.white;
const _kText      = PdfColor.fromInt(0xFF1A1A1A);
const _kSub       = PdfColor.fromInt(0xFF555555);
const _kBorder    = PdfColor.fromInt(0xFFCCCCCC);

const _kSectionLabelSize = 7.5;
const _kSectionBodySize  = 9.0;

Future<Uint8List> _assemblePdf(
  Set<String> enabledIds,
  Map<String, String> data,
  Uint8List? logoBytes,
) async {
  final logo     = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
  final doc      = pw.Document(title: 'Patient Medical Report', author: _Clinic.doctor);
  final font     = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();
  final fontItal = pw.Font.helveticaOblique();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
      header: (_) => _buildHeader(data, logo, font, fontBold, fontItal),
      footer: (ctx) => _buildFooter(ctx, logo, font, fontBold),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        _buildBody(enabledIds, data, font, fontBold, fontItal),
      ],
    ),
  );

  return doc.save();
}

// ── PAGE HEADER ───────────────────────────────────────────────────────────────

pw.Widget _buildHeader(
  Map<String, String> data,
  pw.MemoryImage? logo,
  pw.Font font,
  pw.Font fontBold,
  pw.Font fontItal,
) {
  final fn   = data['firstName'] ?? '';
  final ln   = data['lastName'] ?? '';
  final name = [fn, ln].where((s) => s.isNotEmpty && s != '—').join(' ');
  final date = data['date'] ?? DateFormat('dd-MM-yyyy').format(DateTime.now());

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // Row 1: white bg — clinic name (maroon) + doctor (navy)
      pw.Container(
        color: _kWhite,
        padding: const pw.EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              _Clinic.name,
              style: pw.TextStyle(font: fontBold, fontSize: 20, color: _kMaroon),
            ),
            pw.Text(
              _Clinic.doctor,
              style: pw.TextStyle(font: fontBold, fontSize: 17, color: _kNavy),
            ),
          ],
        ),
      ),
      // Row 2: light-blue banner — logo + tagline left, credentials right
      pw.Container(
        color: _kBannerBg,
        padding: const pw.EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.Container(
                width: 48, height: 52,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 10),
            ],
            pw.Text(
              _Clinic.tagline,
              style: pw.TextStyle(font: fontItal, fontSize: 10, color: _kMaroon),
            ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(_Clinic.designation,
                    style: pw.TextStyle(font: font, fontSize: 8, color: _kNavy)),
                pw.Text(_Clinic.degree1,
                    style: pw.TextStyle(font: font, fontSize: 7.5, color: _kNavy)),
                pw.Text(_Clinic.degree2,
                    style: pw.TextStyle(font: font, fontSize: 7.5, color: _kNavy)),
                pw.Text(_Clinic.degree3,
                    style: pw.TextStyle(font: font, fontSize: 7, color: _kNavy)),
                pw.SizedBox(height: 2),
                pw.Text('${_Clinic.website}',
                    style: pw.TextStyle(font: font, fontSize: 7.5, color: _kNavy)),
              ],
            ),
          ],
        ),
      ),
      pw.Container(height: 1.5, color: _kNavy),
      pw.SizedBox(height: 8),
      // Patient Name + Date line
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Patient Name : ',
                style: pw.TextStyle(font: font, fontSize: 10, color: _kNavy)),
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty)
                    pw.Text(name,
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: _kText)),
                  pw.Container(height: 0.6, color: _kNavy),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Text('Date : ',
                style: pw.TextStyle(font: font, fontSize: 10, color: _kNavy)),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(date,
                      style: pw.TextStyle(font: fontBold, fontSize: 10, color: _kText)),
                  pw.Container(height: 0.6, color: _kNavy),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
    ],
  );
}

// ── BODY ──────────────────────────────────────────────────────────────────────

pw.Widget _buildBody(
  Set<String> enabledIds,
  Map<String, String> data,
  pw.Font font,
  pw.Font fontBold,
  pw.Font fontItal,
) {
  return pw.Table(
    columnWidths: const {
      0: pw.FixedColumnWidth(118),
      1: pw.FlexColumnWidth(1),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
    border: pw.TableBorder.all(color: _kNavy, width: 0.8),
    children: [
      pw.TableRow(
        children: [
          _buildSpecialisationColumn(font),
          _buildClinicalColumn(enabledIds, data, font, fontBold, fontItal),
        ],
      ),
    ],
  );
}

// ── Left: Specialisation column ───────────────────────────────────────────────

pw.Widget _buildSpecialisationColumn(pw.Font font) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Expanded(
        child: pw.Container(
          color: _kLeftBg,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: _Clinic.specialisations.map((s) => pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: _kBorder, width: 0.5)),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: pw.Text(s,
                  style: pw.TextStyle(font: font, fontSize: 8, color: _kNavy)),
            )).toList(),
          ),
        ),
      ),
      pw.Container(width: 5, color: _kRedBar),
    ],
  );
}

// ── Right: Clinical column ────────────────────────────────────────────────────

pw.Widget _buildClinicalColumn(
  Set<String> enabled,
  Map<String, String> data,
  pw.Font font,
  pw.Font fontBold,
  pw.Font fontItal,
) {
  final contactId = _labeledJoin(data, enabled, [
    ('Phone',     'phone'),
    ('Alt Phone', 'altPhone'),
    ('Email',     'email'),
    ('Address',   'address'),
    ('ID Type',   'idProofType'),
    ('ID No.',    'idProofNumber'),
  ]);

  final vitalParts = <String>[];
  if (enabled.contains('weight') && (data['weight'] ?? '').isNotEmpty)
    vitalParts.add('Weight: ${data['weight']}');
  if (enabled.contains('bloodPressure') && (data['bloodPressure'] ?? '').isNotEmpty)
    vitalParts.add('Blood Pressure: ${data['bloodPressure']}');
  if (enabled.contains('temperature') && (data['temperature'] ?? '').isNotEmpty)
    vitalParts.add('Temperature: ${data['temperature']}');
  final vitals = vitalParts.join('     ');

  final complaints = _labeledJoin(data, enabled, [
    ('Chief Complaint',  'chiefComplaint'),
    ('Previous History', 'previousHistory'),
  ]);

  final examination = _labeledJoin(data, enabled, [
    ('General',      'examGeneral'),
    ('Neurological', 'examNeurological'),
  ]);

  final advice      = enabled.contains('advice')      ? (data['advice']      ?? '') : '';
  final medicines   = enabled.contains('medications') ? (data['medications'] ?? '') : '';

  final investigations = _labeledJoin(data, enabled, [
    ('Clinical Diagnosis',  'clinicalDiagnosis'),
    ('Imaging',             'imaging'),
    ('Other Investigation', 'otherInvestigation'),
    ('Impression',          'diagnosis'),
  ]);

  final crossRef = enabled.contains('crossConsultation')
      ? (data['crossConsultation'] ?? '')
      : (enabled.contains('notes') ? (data['notes'] ?? '') : '');

  final sections = <pw.Widget>[];
  void addSection(String title, String content, {pw.Font? bodyFont}) {
    if (content.trim().isEmpty) return;
    if (sections.isNotEmpty) {
      sections.add(pw.Divider(color: _kBorder, thickness: 0.5, height: 0));
    }
    sections.add(_clinicalSection(title, content, font, fontBold, bodyFont: bodyFont));
  }

  addSection('PATIENT CONTACT & ID',                       contactId);
  addSection('VITALS',                                      vitals);
  addSection('PRESENTING COMPLAINTS',                       complaints);
  addSection('EXAMINATION FINDINGS',                        examination);
  addSection('ADVICE',                                      advice);
  addSection('TREATMENT (MEDICINES)',                       medicines, bodyFont: fontItal);
  addSection('INVESTIGATIONS',                              investigations);
  addSection('CROSS REFERENCE (OTHER DOCTOR CONSULTATION)', crossRef);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: sections,
  );
}

// ── Section widget ────────────────────────────────────────────────────────────

pw.Widget _clinicalSection(
  String title,
  String content,
  pw.Font font,
  pw.Font fontBold, {
  pw.Font? bodyFont,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        color: _kSectionBg,
        padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: pw.Text(
          title,
          style: pw.TextStyle(
              font: fontBold,
              fontSize: _kSectionLabelSize,
              color: _kNavy,
              letterSpacing: 0.4),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: pw.Text(
          content.trim(),
          style: pw.TextStyle(
              font: bodyFont ?? font,
              fontSize: _kSectionBodySize,
              color: _kText,
              lineSpacing: 3),
        ),
      ),
    ],
  );
}

// ── PAGE FOOTER ───────────────────────────────────────────────────────────────

pw.Widget _buildFooter(
  pw.Context ctx,
  pw.MemoryImage? logo,
  pw.Font font,
  pw.Font fontBold,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: 4),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Doctor signature
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 18),
                pw.Container(height: 0.7, width: 110, color: _kNavy),
                pw.SizedBox(height: 3),
                pw.Text(_Clinic.doctor,
                    style: pw.TextStyle(font: fontBold, fontSize: 9, color: _kNavy)),
                pw.Text(_Clinic.designation,
                    style: pw.TextStyle(font: font, fontSize: 7, color: _kSub)),
                pw.SizedBox(height: 2),
                pw.Text(_Clinic.degree1,
                    style: pw.TextStyle(font: font, fontSize: 6.5, color: _kSub)),
                pw.Text(_Clinic.degree2,
                    style: pw.TextStyle(font: font, fontSize: 6.5, color: _kSub)),
              ],
            ),
          ),
          // Stamp circle with text
          pw.Expanded(
            flex: 2,
            child: pw.Center(
              child: pw.Container(
                width: 58, height: 58,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: _kNavy, width: 1.5),
                ),
                child: pw.Center(
                  child: logo != null
                      ? pw.ClipOval(child: pw.Image(logo, width: 52, height: 52, fit: pw.BoxFit.cover))
                      : pw.Text('BSC',
                          style: pw.TextStyle(font: fontBold, fontSize: 9, color: _kNavy)),
                ),
              ),
            ),
          ),
          // Follow-up box
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kNavy, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FOLLOW UP / REVIEW',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 8, color: _kNavy, letterSpacing: 0.5)),
                  pw.SizedBox(height: 6),
                  pw.Row(children: [
                    pw.Text('Date: ',
                        style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: _kSub)),
                    pw.Container(width: 70, height: 0.5, color: _kBorder),
                  ]),
                  pw.SizedBox(height: 10),
                  pw.Container(height: 0.5, color: _kBorder),
                  pw.SizedBox(height: 10),
                  pw.Container(height: 0.5, color: _kBorder),
                ],
              ),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        color: _kNavy,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_Clinic.address,
                style: pw.TextStyle(font: font, fontSize: 6.5, color: _kWhite)),
            pw.Text('Phone: ${_Clinic.phone}   |   ${_Clinic.website}',
                style: pw.TextStyle(font: font, fontSize: 7, color: _kWhite)),
            pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 7, color: _kWhite)),
          ],
        ),
      ),
    ],
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _labeledJoin(
  Map<String, String> data,
  Set<String> enabled,
  List<(String, String)> pairs,
) {
  return pairs
      .where((p) => enabled.contains(p.$2))
      .map((p) {
        final v = data[p.$2]?.trim() ?? '';
        return v.isNotEmpty ? '${p.$1}: $v' : null;
      })
      .whereType<String>()
      .join('\n');
}

// ── Service ───────────────────────────────────────────────────────────────────

class PdfExportService {
  PdfExportService._();

  static const _kPageFormat = PdfPageFormat.a4;

  static Future<Uint8List> buildPdf(
    PrintConfigState config, {
    Map<String, String>? patientData,
  }) async {
    final data = patientData ?? kMockPatientData;

    // Resize logo to 80×80 before PDF generation to keep memory usage low.
    Uint8List? logoBytes;
    try {
      final bd       = await rootBundle.load('assets/images/app_logo.png');
      final rawBytes = bd.buffer.asUint8List();
      final codec    = await ui.instantiateImageCodec(
        rawBytes, targetWidth: 80, targetHeight: 80,
      );
      final frame    = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      if (byteData != null) logoBytes = byteData.buffer.asUint8List();
    } catch (_) {}

    // Build PDF on the main isolate — using compute() spawns a second isolate
    // with its own heap, which causes OOM on low-RAM Android devices.
    return _assemblePdf(
      config.enabledFieldIds,
      Map<String, String>.from(data),
      logoBytes,
    );
  }

  static Future<void> exportPdf(
    PrintConfigState config, {
    Map<String, String>? patientData,
  }) async {
    late Uint8List bytes;
    try {
      bytes = await buildPdf(config, patientData: patientData);
    } catch (e) {
      throw Exception('Step 1 (build PDF) failed: $e');
    }

    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/patient_report.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Patient Report',
      );
    } catch (e) {
      throw Exception('Step 2 (share file) failed: $e');
    }
  }

  static Future<void> printReport(
    PrintConfigState config, {
    Map<String, String>? patientData,
  }) async {
    // Generate bytes inside the onLayout callback so Android's print
    // framework can stream them directly without a second in-memory copy.
    await Printing.layoutPdf(
      name:     'Patient Report',
      format:   _kPageFormat,
      onLayout: (_) => buildPdf(config, patientData: patientData),
    );
  }
}
