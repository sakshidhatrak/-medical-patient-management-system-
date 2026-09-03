import 'dart:io';
import 'dart:typed_data';

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
  static const degree1      = 'M.B.B.S., M.S. General Surgery';
  static const degree1b     = '(K.E.M. Hospital, Mumbai)';
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

// Exact values from approved letterhead colour analysis document
const _kClinicPurple = PdfColor.fromInt(0xFF994E89); // clinic name  #994E89
const _kNavy         = PdfColor.fromInt(0xFF333980); // doctor name  #333980
const _kTagline      = PdfColor.fromInt(0xFF40427A); // tagline      #40427A
const _kSidebarText  = PdfColor.fromInt(0xFF4B4C77); // sidebar list #4B4C77
const _kLabel        = PdfColor.fromInt(0xFF373737); // patient labels #373737
const _kText         = PdfColor.fromInt(0xFF494949); // credentials  #494949
const _kBannerBg     = PdfColor.fromInt(0xFFD1EBFB); // header bg    #D1EBFB
const _kSectionBg    = PdfColor.fromInt(0xFFD1EBFB); // section bars #D1EBFB
const _kLeftBg       = PdfColor.fromInt(0xFFFEF0DD); // cream panel  #FEF0DD
const _kRedBar       = PdfColor.fromInt(0xFFE42024); // red accent   #E42024
const _kWhite        = PdfColors.white;
const _kSub          = PdfColor.fromInt(0xFF494949);
const _kBorder       = PdfColor.fromInt(0xFFCCCCCC);
const _kMaroon       = PdfColor.fromInt(0xFF994E89); // kept for compat
const _kPageBorder   = PdfColor.fromInt(0xFFD4AAAA); // light red page border

// ── Main PDF assembly ─────────────────────────────────────────────────────────

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

  // Clinic name: Oswald (condensed display — closest available to Agency FB)
  pw.Font clinicFont;
  try {
    clinicFont = await PdfGoogleFonts.oswaldRegular();
  } catch (_) {
    clinicFont = pw.Font.helveticaBold();
  }

  // Doctor name: Lora Bold (humanist serif — closest available to Cambria Bold)
  pw.Font doctorFont;
  try {
    doctorFont = await PdfGoogleFonts.loraBold();
  } catch (_) {
    doctorFont = pw.Font.timesBold();
  }

  // Tagline: Lobster Two Italic — exact font specified in approved design doc
  pw.Font taglineFont;
  try {
    taglineFont = await PdfGoogleFonts.lobsterTwoItalic();
  } catch (_) {
    taglineFont = pw.Font.helveticaOblique();
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(18),
      build: (ctx) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _kPageBorder, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Two-column letterhead header ───────────────────────────────
            _buildHeader(font, fontBold, fontItal, logo, clinicFont, doctorFont, taglineFont),
            // ── Separator — green #D5DDAE matches HTML .header-divider ───
            pw.Container(height: 1.5, color: _kGreenDiv),
            // ── Body: sidebar LEFT, patient row + sections RIGHT ──────────
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(font),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Patient name starts after the green sidebar border
                        _buildPatientRow(data, font, fontBold),
                        pw.Container(height: 0.8, color: _kGreenDiv),
                        pw.Expanded(
                          child: _buildSections(enabledIds, data, font, fontBold, fontItal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return doc.save();
}

// HTML reference: 1142×1600px → PDF 559pt usable, scale ≈ 0.489
// 3-column alignment: logo(90pt) | clinic/tagline(flex) | doctor/credentials(300pt)
// Colors and fonts from approved colour-analysis document.

const _kGreenDiv   = PdfColor.fromInt(0xFFD5DDAE); // header & sidebar dividers
const _kSidebarBrd = PdfColor.fromInt(0xFFB1BE76); // sidebar right border

pw.Widget _buildHeader(
  pw.Font font,
  pw.Font fontBold,
  pw.Font fontItal,
  pw.MemoryImage? logo,
  pw.Font clinicFont,
  pw.Font doctorFont,
  pw.Font taglineFont,
) {
  // ── Row 1 (blue strip, ~44pt) ─────────────────────────────────────────────
  // Col 0: spacer aligns with logo below  Col 1: clinic name  Col 2: doctor name
  final row1 = pw.Table(
    columnWidths: const {
      0: pw.FixedColumnWidth(90),    // aligns with logo column below
      1: pw.FlexColumnWidth(),        // clinic name
      2: pw.FixedColumnWidth(300),   // doctor name (right-aligned)
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _kBannerBg),
        children: [
          pw.SizedBox(),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(8, 11, 8, 9),
            child: pw.Text(_Clinic.name,
                style: pw.TextStyle(font: clinicFont, fontSize: 16, color: _kClinicPurple)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(8, 11, 14, 9),
            child: pw.Text(_Clinic.doctor,
                style: pw.TextStyle(font: doctorFont, fontSize: 19, color: _kNavy),
                textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    ],
  );

  // ── Row 2 (logo + content, ~100pt) ────────────────────────────────────────
  // Col 0: logo (122pt = sidebar width)  Col 1: tagline  Col 2: credentials (right)
  final row2 = pw.Table(
    columnWidths: const {
      0: pw.FixedColumnWidth(90),    // logo
      1: pw.FlexColumnWidth(),        // tagline "Excellence, Ethics, Efficiency"
      2: pw.FixedColumnWidth(300),   // credentials, right-aligned
    },
    children: [
      pw.TableRow(
        children: [
          logo != null
              ? pw.Image(logo, height: 90, fit: pw.BoxFit.contain)
              : pw.SizedBox(height: 90),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 18, 8, 8),
            child: pw.Text(_Clinic.tagline,
                style: pw.TextStyle(font: taglineFont, fontSize: 11, color: _kTagline)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(8, 8, 14, 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(_Clinic.designation,
                    style: pw.TextStyle(font: font, fontSize: 9.5, color: _kText),
                    textAlign: pw.TextAlign.right),
                pw.Text(_Clinic.degree1,
                    style: pw.TextStyle(font: font, fontSize: 9.5, color: _kText),
                    textAlign: pw.TextAlign.right),
                pw.Text(_Clinic.degree1b,
                    style: pw.TextStyle(font: font, fontSize: 9.5, color: _kText),
                    textAlign: pw.TextAlign.right),
                pw.Text(_Clinic.degree2,
                    style: pw.TextStyle(font: font, fontSize: 9.5, color: _kText),
                    textAlign: pw.TextAlign.right),
                pw.Text(_Clinic.degree3,
                    style: pw.TextStyle(font: font, fontSize: 9.5, color: _kText),
                    textAlign: pw.TextAlign.right),
                pw.SizedBox(height: 4),
                pw.Text('@ ${_Clinic.website}',
                    style: pw.TextStyle(font: font, fontSize: 9.5, color: _kNavy),
                    textAlign: pw.TextAlign.right),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  // Green divider matching HTML .header-divider (#D5DDAE, 2px)
  final greenDivider = pw.Container(height: 1.5, color: _kGreenDiv);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [row1, row2, greenDivider],
  );
}

// ── Left sidebar: red bar (left edge) + specialisations ──────────────────────

pw.Widget _buildSidebar(pw.Font font) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // Red vertical accent — #E42024, 10pt wide (HTML: 21px × 0.489)
      pw.Container(width: 10, color: _kRedBar),
      // Specialisations list — #4B4C77 text, #D5DDAE dividers
      pw.Container(
        width: 110,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            ..._Clinic.specialisations.map(
              (s) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(8, 10, 6, 9),
                    child: pw.Text(
                      s,
                      style: pw.TextStyle(font: font, fontSize: 8, color: _kSidebarText),
                    ),
                  ),
                  pw.Container(height: 0.8, color: _kGreenDiv),
                ],
              ),
            ),
          ],
        ),
      ),
      // Right border — #B1BE76, 2px (HTML: border-right: 2px solid #B1BE76)
      pw.Container(width: 1.5, color: _kSidebarBrd),
    ],
  );
}

// ── Patient name + date row ───────────────────────────────────────────────────

pw.Widget _buildPatientRow(
  Map<String, String> data,
  pw.Font font,
  pw.Font fontBold,
) {
  final fn   = data['firstName'] ?? '';
  final ln   = data['lastName'] ?? '';
  final name = [fn, ln].where((s) => s.isNotEmpty && s != '—').join(' ');
  final date = data['date'] ?? DateFormat('dd-MM-yyyy').format(DateTime.now());

  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(10, 5, 10, 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('Patient Name : ',
            style: pw.TextStyle(font: font, fontSize: 10, color: _kLabel)),
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty)
                pw.Text(name,
                    style: pw.TextStyle(font: fontBold, fontSize: 10, color: _kText)),
              pw.Container(height: 0.7, color: _kNavy),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Text('Date : ',
            style: pw.TextStyle(font: font, fontSize: 10, color: _kLabel)),
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(date,
                  style: pw.TextStyle(font: fontBold, fontSize: 10, color: _kText)),
              pw.Container(height: 0.7, color: _kNavy),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── All clinical sections ─────────────────────────────────────────────────────

pw.Widget _buildSections(
  Set<String> enabled,
  Map<String, String> data,
  pw.Font font,
  pw.Font fontBold,
  pw.Font fontItal,
) {
  String d(String k) => enabled.contains(k) ? (data[k]?.trim() ?? '') : '';

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // PATIENT CONTACT & ID
      _section('PATIENT CONTACT & ID', fontBold, [
        _fieldRow('Phone', d('phone'), font, fontBold),
        _gap(),
        _fieldRow('Address', d('address'), font, fontBold),
      ]),

      // VITALS
      _section('VITALS', fontBold, [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _vitalLabel('Weight', font, fontBold),
            pw.Expanded(flex: 2, child: _valueUnderline(d('weight'), font)),
            pw.SizedBox(width: 10),
            _vitalLabel('Blood Pressure', font, fontBold),
            pw.Expanded(flex: 2, child: _valueUnderline(d('bloodPressure'), font)),
            pw.SizedBox(width: 10),
            _vitalLabel('Temperature', font, fontBold),
            pw.Expanded(flex: 2, child: _valueUnderline(d('temperature'), font)),
          ],
        ),
      ]),

      // PRESENTING COMPLAINTS
      _section('PRESENTING COMPLAINTS', fontBold, [
        _fieldRow('Chief Complaint', d('chiefComplaint'), font, fontBold),
        _gap(),
        _fieldRow('Previous History', d('previousHistory'), font, fontBold),
        _gap(),
        _blankLine(),
      ]),

      // EXAMINATION FINDINGS
      _section('EXAMINATION FINDINGS', fontBold, [
        _fieldRow('General', d('examGeneral'), font, fontBold),
      ]),

      // ADVICE
      _section('ADVICE', fontBold, [
        if (d('advice').isNotEmpty) ...[
          pw.Text(d('advice'),
              style: pw.TextStyle(font: font, fontSize: 9, color: _kText)),
          _gap(2),
        ],
        _blankLine(),
        _gap(),
        _blankLine(),
      ]),

      // TREATMENT (MEDICINES)
      _section('TREATMENT (MEDICINES)', fontBold, [
        if (d('medications').isNotEmpty) ...[
          pw.Text(d('medications'),
              style: pw.TextStyle(font: fontItal, fontSize: 9, color: _kText)),
          _gap(2),
        ],
        _blankLine(),
        _gap(),
        _blankLine(),
      ]),

      // INVESTIGATIONS
      _section('INVESTIGATIONS', fontBold, [
        _fieldRow('Clinical Diagnosis', d('clinicalDiagnosis'), font, fontBold),
        _gap(),
        _fieldRow('Imaging', d('imaging'), font, fontBold),
        _gap(),
        _fieldRow('Other Investigation', d('otherInvestigation'), font, fontBold),
        _gap(),
        _fieldRow('Impression', d('diagnosis'), font, fontBold),
      ]),

      // CROSS REFERENCE
      _section('CROSS REFERENCE (OTHER DOCTOR CONSULTATION)', fontBold, [
        _fieldRow(
          'Additional Clinical diagnosis',
          d('crossConsultation').isNotEmpty ? d('crossConsultation') : d('notes'),
          font,
          fontBold,
        ),
        _gap(),
        _blankLine(),
      ]),
    ],
  );
}

// ── Section block: blue header + padded content ───────────────────────────────

pw.Widget _section(String title, pw.Font fontBold, List<pw.Widget> items) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        color: _kSectionBg,
        padding: const pw.EdgeInsets.fromLTRB(10, 4, 10, 4),
        child: pw.Text(
          title,
          style: pw.TextStyle(
              font: fontBold, fontSize: 8, color: _kNavy, letterSpacing: 0.4),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(10, 5, 10, 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: items,
        ),
      ),
    ],
  );
}

// ── Field row: "Label: value___" with underline ───────────────────────────────

pw.Widget _fieldRow(
  String label,
  String value,
  pw.Font font,
  pw.Font fontBold,
) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Text('$label: ',
          style: pw.TextStyle(font: fontBold, fontSize: 9, color: _kNavy)),
      pw.Expanded(child: _valueUnderline(value, font)),
    ],
  );
}

// Value text + underline (reused for fields and vitals)
pw.Widget _valueUnderline(String value, pw.Font font) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      if (value.isNotEmpty)
        pw.Text(value,
            style: pw.TextStyle(font: font, fontSize: 9, color: _kText)),
      pw.SizedBox(height: 1),
      pw.Container(height: 0.5, color: _kBorder),
    ],
  );
}

// Vital label (e.g. "Weight: ")
pw.Widget _vitalLabel(String label, pw.Font font, pw.Font fontBold) {
  return pw.Text('$label: ',
      style: pw.TextStyle(font: fontBold, fontSize: 9, color: _kNavy));
}

// A blank underline with no label
pw.Widget _blankLine() => pw.Container(height: 0.5, color: _kBorder);

// Vertical spacer
pw.Widget _gap([double h = 5]) => pw.SizedBox(height: h);

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
                pw.Text('${_Clinic.degree1} ${_Clinic.degree1b}',
                    style: pw.TextStyle(font: font, fontSize: 6.5, color: _kSub)),
                pw.Text(_Clinic.degree2,
                    style: pw.TextStyle(font: font, fontSize: 6.5, color: _kSub)),
              ],
            ),
          ),
          // Stamp circle
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
                      : pw.Text('BSC',
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 9, color: _kNavy)),
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
                          font: fontBold,
                          fontSize: 8,
                          color: _kNavy,
                          letterSpacing: 0.5)),
                  pw.SizedBox(height: 6),
                  pw.Row(children: [
                    pw.Text('Date: ',
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 7.5, color: _kSub)),
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

// ── Isolate entry point ───────────────────────────────────────────────────────

Future<Uint8List> _assemblePdfIsolate(
        (List<String>, Map<String, String>, Uint8List?) args) =>
    _assemblePdf(Set<String>.from(args.$1), args.$2, args.$3);

// ── Lightweight plain-text fallback PDF ───────────────────────────────────────

Future<Uint8List> _assembleLightPdf(
    List<String> enabledIds, Map<String, String> data) async {
  final doc   = pw.Document(compress: true);
  final bold  = pw.Font.helveticaBold();
  final plain = pw.Font.helvetica();

  bool has(String k) => enabledIds.contains(k);
  String val(String k) => (data[k] ?? '').trim();

  final fn   = data['firstName'] ?? '';
  final ln   = data['lastName'] ?? '';
  final name = [fn, ln].where((s) => s.isNotEmpty && s != '—').join(' ');
  final date = data['date'] ?? DateFormat('dd-MM-yyyy').format(DateTime.now());

  final rows = <pw.Widget>[];
  void addRow(String label, String key) {
    if (!has(key)) return;
    final v = val(key);
    if (v.isEmpty || v == '—') return;
    rows.add(pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(),
                style: pw.TextStyle(
                    font: bold,
                    fontSize: 8,
                    color: const PdfColor.fromInt(0xFF555555))),
            pw.SizedBox(height: 2),
            pw.Text(v, style: pw.TextStyle(font: plain, fontSize: 11)),
          ]),
    ));
  }

  addRow('Phone',               'phone');
  addRow('Alt Phone',           'altPhone');
  addRow('Weight',              'weight');
  addRow('Blood Pressure',      'bloodPressure');
  addRow('Temperature',         'temperature');
  addRow('Chief Complaint',     'chiefComplaint');
  addRow('Previous History',    'previousHistory');
  addRow('General Examination', 'examGeneral');
  addRow('Neurological Exam',   'examNeurological');
  addRow('Clinical Diagnosis',  'clinicalDiagnosis');
  addRow('Imaging',             'imaging');
  addRow('Other Investigation', 'otherInvestigation');
  addRow('Impression',          'diagnosis');
  addRow('Advice',              'advice');
  addRow('Medications',         'medications');
  addRow('Cross Consultation',  'crossConsultation');
  addRow('Notes',               'notes');

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    header: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('The Brain & Spine Clinic',
            style: pw.TextStyle(
                font: bold,
                fontSize: 16,
                color: const PdfColor.fromInt(0xFF8B1A1A))),
        pw.Text('Dr. Harshal S. Chaudhari — Neurosurgeon (Brain & Spine)',
            style: pw.TextStyle(font: plain, fontSize: 10)),
        pw.Divider(thickness: 0.8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (name.isNotEmpty)
              pw.Text('Patient: $name',
                  style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text('Date: $date',
                style: pw.TextStyle(font: plain, fontSize: 10)),
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    ),
    footer: (ctx) => pw.Column(children: [
      pw.Divider(thickness: 0.5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Dr. Harshal S. Chaudhari',
              style: pw.TextStyle(font: bold, fontSize: 8)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(font: plain, fontSize: 8)),
        ],
      ),
    ]),
    build: (_) => rows,
  ));

  return doc.save();
}

// ── Service ───────────────────────────────────────────────────────────────────

class PdfExportService {
  PdfExportService._();

  static const _kPageFormat = PdfPageFormat.a4;

  static Future<Uint8List> buildPdf(
    PrintConfigState config, {
    Map<String, String>? patientData,
  }) async {
    final data    = patientData ?? kMockPatientData;
    final enabled = config.enabledFieldIds.toList();
    final copy    = Map<String, String>.from(data);

    Uint8List? logoBytes;
    try {
      final bd = await rootBundle.load('assets/images/app_logo.jpeg');
      logoBytes = bd.buffer.asUint8List();
    } catch (_) {}

    try {
      return await _assemblePdf(Set<String>.from(enabled), copy, logoBytes);
    } catch (_) {}

    return _assembleLightPdf(enabled, copy);
  }

  static Future<void> exportPdf(
    PrintConfigState config, {
    Map<String, String>? patientData,
  }) async {
    final data    = patientData ?? kMockPatientData;
    final enabled = config.enabledFieldIds.toList();
    final copy    = Map<String, String>.from(data);

    Uint8List? logoBytes;
    try {
      final bd = await rootBundle.load('assets/images/app_logo.jpeg');
      logoBytes = bd.buffer.asUint8List();
    } catch (_) {}

    late final Uint8List bytes;
    try {
      bytes = await _assemblePdf(Set<String>.from(enabled), copy, logoBytes);
    } catch (_) {
      bytes = await _assembleLightPdf(enabled, copy).catchError((e) {
        throw Exception('Could not generate PDF: $e');
      });
    }

    try {
      await Printing.sharePdf(bytes: bytes, filename: 'patient_report.pdf');
      return;
    } catch (_) {}

    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/patient_report.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Patient Report',
      );
    } catch (e) {
      throw Exception('Could not share PDF: $e');
    }
  }

  static Future<void> printReport(
    PrintConfigState config, {
    Map<String, String>? patientData,
  }) async {
    await Printing.layoutPdf(
      name:     'Patient Report',
      format:   _kPageFormat,
      onLayout: (_) => buildPdf(config, patientData: patientData),
    );
  }
}
