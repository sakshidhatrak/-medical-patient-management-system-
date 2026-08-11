import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../presentation/providers/print_config_provider.dart';

// ── Clinic constants ──────────────────────────────────────────────────────────

class _Clinic {
  static const name        = 'The Brain & Spine Clinic';
  static const tagline     = 'Excellence, Ethics, Efficiency';
  static const doctor      = 'Dr. Harshal S. Chaudhari';
  static const designation = 'Consultant Neurosurgeon (Brain and Spine)';
  static const degree1     = 'MBBS, MS Gen. Surg. (KEM Hospital, Mumbai)';
  static const degree2     = 'MCh Neurosurgery (GMC, Goa)';
  static const degree3     = 'Fellow in NeuroSurgical Oncology (TMH, Mumbai)';
  static const regNo       = 'MMC Reg. No: 2009031020';
  static const website     = 'www.thebrainandspineclinic.com';
  static const phone       = '+91 83900 24528';
  static const address     = 'C/0 Nashik Hematology Services- 6th Floor, S.K. Empire, Near Ved Mandir, Mico Circle, Nashik';
  static const specialisations = [
    'Neurosurgery',
    'Brain Tumour',
    'Spine Surgery',
    'Epilepsy Surgery',
    'Head Injury',
    'Cerebrovascular Surgery',
    'Spinal Cord Surgery',
    'Pediatric Neurosurgery',
  ];
}

// ── Colour palette ─────────────────────────────────────────────────────────────

const _kNavy    = PdfColor.fromInt(0xFF1A2D5A);
const _kGold    = PdfColor.fromInt(0xFFC8A951);
const _kWhite   = PdfColors.white;
const _kText    = PdfColor.fromInt(0xFF1A1A1A);
const _kSub     = PdfColor.fromInt(0xFF666666);
const _kBorder  = PdfColor.fromInt(0xFFCCCCCC);
const _kBgLight = PdfColor.fromInt(0xFFF8F6F0);
// ── Section font sizing ───────────────────────────────────────────────────────

const _kSectionLabelSize = 7.5;
const _kSectionBodySize  = 9.0;
// ── Service ───────────────────────────────────────────────────────────────────

class PdfExportService {
  PdfExportService._();

  static const _kPageFormat = PdfPageFormat.a4;

  // ── Public API ──────────────────────────────────────────────────────────────

  static Future<Uint8List> buildPdf(
    PrintConfigState config, {
    Map<String, String>? patientData,
  }) async {
    final data      = patientData ?? kMockPatientData;
    final logoBytes = await _loadLogo();

    final doc = pw.Document(
      title:  'Patient Medical Report',
      author: _Clinic.doctor,
    );

    // Use built-in fonts to avoid network download OOM on low-memory devices.
    final font     = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontItal = pw.Font.helveticaOblique();

    doc.addPage(
      pw.MultiPage(
        pageFormat: _kPageFormat,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        header: (_) => _buildHeader(data, logoBytes, font, fontBold),
        footer: (ctx) => _buildFooter(ctx, data, logoBytes, font, fontBold),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          _buildBody(config, data, font, fontBold, fontItal),
        ],
      ),
    );

    return doc.save();
  }

  static Future<void> exportPdf(
    PrintConfigState config, {
    Map<String, String>? patientData,
  }) async {
    await Printing.layoutPdf(
      name:     'Patient Report',
      format:   _kPageFormat,
      onLayout: (_) => buildPdf(config, patientData: patientData),
    );
  }

  // Alias used by ReportActionBar._print
  static Future<void> printReport(
    PrintConfigState config, {
    Map<String, String>? patientData,
  }) => exportPdf(config, patientData: patientData);

  // ── Logo loader — resizes to 80px to prevent OOM on low-memory devices ─────

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data  = await rootBundle.load('assets/images/app_logo.png');
      final bytes = data.buffer.asUint8List();
      // Decode and resize to max 80x80 — the full 1.3 MB PNG decoded raw
      // can exceed 4 MB and crash PDF generation on low-memory Android devices.
      final codec = await ui.instantiateImageCodec(
          bytes, targetWidth: 80, targetHeight: 80);
      final frame     = await codec.getNextFrame();
      final byteData  = await frame.image.toByteData(
          format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (byteData == null) return null;
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  // ── PAGE HEADER ─────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(
    Map<String, String> data,
    pw.MemoryImage? logo,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Top clinic banner ───────────────────────────────────────────────
        pw.Container(
          color: _kNavy,
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo
              if (logo != null)
                pw.Container(
                  width: 52,
                  height: 62,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              if (logo != null) pw.SizedBox(width: 10),
              // Clinic name + tagline
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _Clinic.name,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: _kWhite,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _Clinic.tagline,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: _kGold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Vertical gold divider
              pw.Container(
                width: 1,
                height: 54,
                color: _kGold,
                margin: const pw.EdgeInsets.symmetric(horizontal: 14),
              ),
              // Doctor credentials
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    _Clinic.doctor,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 11,
                      color: _kWhite,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _Clinic.designation,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 7.5,
                      color: _kGold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _Clinic.degree1,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 7,
                      color: PdfColor(1, 1, 1, 0.75),
                    ),
                  ),
                  pw.Text(
                    _Clinic.degree2,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 7,
                      color: PdfColor(1, 1, 1, 0.75),
                    ),
                  ),
                  pw.Text(
                    _Clinic.degree3,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 6.5,
                      color: PdfColor(1, 1, 1, 0.65),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _Clinic.website,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 7,
                      color: _kGold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── Gold accent line ────────────────────────────────────────────────
        pw.Container(height: 3, color: _kGold),
        pw.SizedBox(height: 6),
        // ── Patient info bar ────────────────────────────────────────────────
        _buildPatientBar(data, font, fontBold),
        pw.SizedBox(height: 6),
        // ── Section sub-heading ─────────────────────────────────────────────
        pw.Container(
          color: _kBgLight,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: pw.Row(
            children: [
              pw.Container(
                width: 3,
                height: 12,
                color: _kNavy,
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                'OUTPATIENT CONSULTATION REPORT',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 8.5,
                  color: _kNavy,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Patient info bar ────────────────────────────────────────────────────────

  static pw.Widget _buildPatientBar(
    Map<String, String> data,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final fn   = data['firstName'] ?? '';
    final ln   = data['lastName'] ?? '';
    final name = [fn, ln].where((s) => s.isNotEmpty && s != '—').join(' ');
    final age  = data['age'] ?? '';
    final sex  = data['gender'] ?? '';
    final ageSex = [age, sex].where((s) => s.isNotEmpty && s != '—').join(' / ');
    final uhid = data['uhid'] ?? data['prn'] ?? data['idProofNumber'] ?? '—';
    final now  = DateFormat('dd MMM yyyy').format(DateTime.now());

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _kNavy, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          _patientCell('Patient Name', name.isEmpty ? '—' : name,
              font, fontBold, flex: 3),
          _cellDivider(),
          _patientCell('Age / Sex', ageSex.isEmpty ? '—' : ageSex,
              font, fontBold, flex: 2),
          _cellDivider(),
          _patientCell('UHID / Reg. No.', uhid, font, fontBold, flex: 2),
          _cellDivider(),
          _patientCell('Date', now, font, fontBold, flex: 2),
        ],
      ),
    );
  }

  static pw.Widget _cellDivider() =>
      pw.Container(width: 1, height: 34, color: _kNavy);

  static pw.Widget _patientCell(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold, {
    int flex = 1,
  }) =>
      pw.Expanded(
        flex: flex,
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(font: font, fontSize: 6.5, color: _kSub),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                value,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9.5,
                  color: _kNavy,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      );

  // ── BODY (two-column) ───────────────────────────────────────────────────────

  static pw.Widget _buildBody(
    PrintConfigState config,
    Map<String, String> data,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItal,
  ) {
    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(130),
        1: pw.FlexColumnWidth(1),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
      border: pw.TableBorder.all(color: _kNavy, width: 0.8),
      children: [
        pw.TableRow(
          children: [
            // Left — specialisation
            _buildSpecialisationColumn(font, fontBold),
            // Right — clinical sections
            _buildClinicalColumn(config, data, font, fontBold, fontItal),
          ],
        ),
      ],
    );
  }

  // ── Specialisation column ───────────────────────────────────────────────────

  static pw.Widget _buildSpecialisationColumn(pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Navy header
        pw.Container(
          color: _kNavy,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(
            'OUR\nSPECIALISATION',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 8.5,
              color: _kGold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        // Specialisation items
        ..._Clinic.specialisations.asMap().entries.map(
          (e) => pw.Container(
            decoration: pw.BoxDecoration(
              color: e.key % 2 == 0 ? _kBgLight : _kWhite,
              border: pw.Border(
                bottom: pw.BorderSide(color: _kBorder, width: 0.4),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '◆',
                  style: pw.TextStyle(
                      font: font, fontSize: 5.5, color: _kGold),
                ),
                pw.SizedBox(width: 5),
                pw.Expanded(
                  child: pw.Text(
                    e.value,
                    style: pw.TextStyle(font: font, fontSize: 8, color: _kText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Clinical column ─────────────────────────────────────────────────────────

  static pw.Widget _buildClinicalColumn(
    PrintConfigState config,
    Map<String, String> data,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItal,
  ) {
    final enabled = config.enabledFieldIds;

    // Patient contact & ID
    final contactId = _labeledJoin(data, enabled, [
      ('Phone', 'phone'),
      ('Alt Phone', 'altPhone'),
      ('Email', 'email'),
      ('Address', 'address'),
      ('ID Type', 'idProofType'),
      ('ID No.', 'idProofNumber'),
    ]);

    // Vitals — labeled so each reading is identifiable
    final vitals = _labeledJoin(data, enabled, [
      ('Weight', 'weight'),
      ('Blood Pressure', 'bloodPressure'),
      ('Temperature', 'temperature'),
    ]);

    // Known allergies
    final allergies =
        enabled.contains('allergies') ? (data['allergies'] ?? '') : '';

    // Past medical history
    final medHistory =
        enabled.contains('medicalHistory') ? (data['medicalHistory'] ?? '') : '';

    // Chief complaint + previous history — each labeled so it's clear which is which
    final complaints = _labeledJoin(data, enabled, [
      ('Chief Complaint', 'chiefComplaint'),
      ('Previous History', 'previousHistory'),
    ]);

    // Examination findings — labeled by type (General / Neurological)
    final examination = _labeledJoin(data, enabled, [
      ('General', 'examGeneral'),
      ('Neurological', 'examNeurological'),
    ]);

    // Advice
    final advice = enabled.contains('advice') ? (data['advice'] ?? '') : '';

    // Treatment / medicines
    final medicines =
        enabled.contains('medications') ? (data['medications'] ?? '') : '';

    // Investigations — includes clinical diagnosis, imaging, other investigation,
    // impression and plan all in one labeled section (Reports section removed).
    final investigations = _labeledJoin(data, enabled, [
      ('Clinical Diagnosis', 'clinicalDiagnosis'),
      ('Imaging', 'imaging'),
      ('Other Investigation', 'otherInvestigation'),
      ('Impression', 'diagnosis'),
      ('Plan', 'treatmentPlan'),
    ]);

    // Cross reference / notes
    final crossRef = enabled.contains('notes') ? (data['notes'] ?? '') : '';

    // Build blocks — skip any section whose content is empty so no blank headers appear.
    final blocks = <List<pw.Widget>>[
      _buildBlock([
        (title: 'PATIENT CONTACT & ID', content: contactId, bodyFont: null),
        (title: 'VITALS',               content: vitals,    bodyFont: null),
        (title: 'KNOWN ALLERGIES',      content: allergies, bodyFont: null),
        (title: 'PAST MEDICAL HISTORY', content: medHistory, bodyFont: null),
      ], font, fontBold),
      _buildBlock([
        (title: 'PRESENTING COMPLAINTS', content: complaints,  bodyFont: null),
        (title: 'EXAMINATION FINDINGS',  content: examination, bodyFont: null),
      ], font, fontBold),
      _buildBlock([
        (title: 'ADVICE',               content: advice,    bodyFont: null),
        (title: 'TREATMENT (MEDICINES)', content: medicines, bodyFont: fontItal),
      ], font, fontBold),
      _buildBlock([
        (title: 'INVESTIGATIONS', content: investigations, bodyFont: null),
        (title: 'CROSS REFERENCE (OTHER DOCTOR CONSULTATION)', content: crossRef, bodyFont: null),
      ], font, fontBold),
    ].where((b) => b.isNotEmpty).toList();

    final result = <pw.Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      result.addAll(blocks[i]);
      if (i < blocks.length - 1) {
        result.add(pw.Container(height: 2, color: _kNavy));
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: result,
    );
  }

  // Builds a list of section widgets for one "block", separated by thin dividers.
  // Returns empty list if all sections are empty (so the thick navy separator
  // between blocks is also suppressed when there's nothing to show).
  static List<pw.Widget> _buildBlock(
    List<({String title, String content, pw.Font? bodyFont})> entries,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final sections = <pw.Widget>[];
    for (final e in entries) {
      if (e.content.trim().isEmpty) continue;
      if (sections.isNotEmpty) sections.add(_sectionDivider());
      sections.add(_clinicalSection(
        e.title, e.content, font, fontBold,
        topBorder: false,
        bodyItalic: e.bodyFont,
      ));
    }
    return sections;
  }

  static pw.Widget _sectionDivider() =>
      pw.Divider(color: _kBorder, thickness: 0.5, height: 0);

  static pw.Widget _clinicalSection(
    String title,
    String content,
    pw.Font font,
    pw.Font fontBold, {
    bool topBorder = true,
    pw.Font? bodyItalic,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: topBorder
              ? pw.BorderSide(color: _kBorder, width: 0.3)
              : pw.BorderSide.none,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Section label bar
          pw.Container(
            color: _kBgLight,
            padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: _kSectionLabelSize,
                color: _kNavy,
                letterSpacing: 0.4,
              ),
            ),
          ),
          // Content
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: pw.Text(
              content.trim().isEmpty ? '' : content.trim(),
              style: pw.TextStyle(
                font: bodyItalic ?? font,
                fontSize: _kSectionBodySize,
                color: _kText,
                lineSpacing: 2.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PAGE FOOTER ─────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(
    pw.Context ctx,
    Map<String, String> data,
    pw.MemoryImage? logo,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 4),
        // ── Signature + stamp + follow-up row ─────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Doctor signature (left)
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 18),
                  pw.Container(height: 0.7, width: 110, color: _kNavy),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _Clinic.doctor,
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 9, color: _kNavy),
                  ),
                  pw.Text(
                    _Clinic.designation,
                    style: pw.TextStyle(font: font, fontSize: 7, color: _kSub),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _Clinic.degree1,
                    style: pw.TextStyle(
                        font: font, fontSize: 6.5, color: _kSub),
                  ),
                  pw.Text(
                    _Clinic.degree2,
                    style: pw.TextStyle(
                        font: font, fontSize: 6.5, color: _kSub),
                  ),
                  pw.Text(
                    _Clinic.regNo,
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 7, color: _kNavy),
                  ),
                ],
              ),
            ),
            // Logo stamp (center)
            pw.Expanded(
              flex: 2,
              child: pw.Center(
                child: pw.Container(
                  width: 58,
                  height: 58,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: _kNavy, width: 1.5),
                  ),
                  child: pw.Center(
                    child: logo != null
                        ? pw.ClipOval(
                            child: pw.Image(logo,
                                width: 52, height: 52, fit: pw.BoxFit.cover))
                        : pw.Text(
                            'BSC',
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 9,
                                color: _kNavy),
                          ),
                  ),
                ),
              ),
            ),
            // Follow-up (right)
            pw.Expanded(
              flex: 3,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _kNavy, width: 0.8),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FOLLOW UP / REVIEW',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        color: _kNavy,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(children: [
                      pw.Text('Date: ',
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 7.5, color: _kSub)),
                      pw.Container(
                          width: 70, height: 0.5, color: _kBorder),
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
        // ── Bottom address bar ─────────────────────────────────────────────
        pw.Container(
          color: _kNavy,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _Clinic.address,
                style:
                    pw.TextStyle(font: font, fontSize: 7.5, color: _kGold),
              ),
              pw.Text(
                'Phone: ${_Clinic.phone}   |   ${_Clinic.website}',
                style:
                    pw.TextStyle(font: font, fontSize: 7.5, color: _kWhite),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                style:
                    pw.TextStyle(font: font, fontSize: 7, color: _kGold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _joinFields(List<String?> parts) {
    return parts
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .join('\n\n');
  }

  static String _labeledJoin(
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
}

