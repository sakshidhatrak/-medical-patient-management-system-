import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:medical_patient_management/features/patients/domain/entities/patient_entity.dart';
import 'package:medical_patient_management/features/prescriptions/domain/entities/prescription_entity.dart';
import 'package:medical_patient_management/features/surgeries/domain/entities/surgery_entity.dart';
import 'package:medical_patient_management/features/visits/domain/entities/visit_entity.dart';


// ============================================================================
// CLINIC CONSTANTS
// ============================================================================

class _DI {
  static const clinic  = 'The Brain & Spine Clinic';
  static const name    = 'Dr. Harshal S. Chaudhari';
  static const title   = 'Brain and Spine surgeon/ Neurosurgeon';
  static const deg1    = 'M.B.B.S., M.S. General Surgery';
  static const deg2    = '(K.E.M. Hospital, Mumbai)';
  static const deg3    = 'M.Ch. Neurosurgery (G.M.C., Goa)';
  static const deg4    = 'Fellow in Neurosurgical Oncology (Tata Memorial Hospital)';
  static const web     = 'www.drharshalchaudhari.com';
  static const tagline = 'Excellence, Ethics, Efficiency';

  // Specialisations — index 0 has NO red bar; indices 1-7 have red bar
  static const specs = [
    'Brain and Spine Injury',           // 0
    'Vascular Neurosurgery',            // 1 — red bar starts
    'Brain tumors',                     // 2
    'Spine tumors',                     // 3
    'Pediatric Neurosurgery',           // 4
    'Degenerative spine disease',       // 5
    'Spondylosis',                      // 6
    'Slip disc',                        // 7 — red bar ends
    'Cranio-Vertebral junction abnormality',
    'Root or epidural block',
    'Endoscopic skull base surgery',
    'Hydrocephalus',
    'Minimally invasive spine surgery',
  ];
}


// ============================================================================
// COLOURS
// ============================================================================

class _C {
  static const blue    = PdfColor.fromInt(0xFFD1EBFB); // header bg
  static const purple  = PdfColor.fromInt(0xFF994E89); // clinic name
  static const navy    = PdfColor.fromInt(0xFF333980); // doctor name / headings
  static const tline   = PdfColor.fromInt(0xFF40427A); // tagline
  static const txt     = PdfColor.fromInt(0xFF494949); // body text
  static const dark    = PdfColor.fromInt(0xFF373737); // labels
  static const sbar    = PdfColor.fromInt(0xFF4B4C77); // sidebar text
  static const cream   = PdfColor.fromInt(0xFFFEF0DD); // logo panel
  static const green   = PdfColor.fromInt(0xFFD5DDAE); // section dividers
  static const sgrn    = PdfColor.fromInt(0xFFB1BE76); // sidebar right border
  static const red     = PdfColor.fromInt(0xFFE42024); // speciality bar
  static const grey    = PdfColor.fromInt(0xFF9B9B9B); // underlines
  static const dot     = PdfColor.fromInt(0xFFCFCFCF); // dot pattern
  static const brd     = PdfColor.fromInt(0xFFD8B8BB); // outer page border
}


// ============================================================================
// FONT BUNDLE
// ============================================================================

class _Fonts {
  final pw.Font body, bold, ital, clinic, doctor, tagline;
  const _Fonts({
    required this.body,
    required this.bold,
    required this.ital,
    required this.clinic,
    required this.doctor,
    required this.tagline,
  });
}


// ============================================================================
// PDF SERVICE
// ============================================================================

class PdfService {

  // ==========================================================================
  // PUBLIC — VISIT PDF
  // ==========================================================================

  static Future<Uint8List> buildVisitPdf({
    required PatientEntity patient,
    required VisitEntity visit,
    PrescriptionEntity? prescription,
    String? examinationText,
    String? radiologyText,
    String? clinicAddress,
  }) async {
    final pdf   = pw.Document();
    final logo  = await _logo();
    final fonts = await _loadFonts();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        header: (_) => _header(patient: patient, date: visit.visitDate, logo: logo, fonts: fonts),
        footer: (_) => pw.SizedBox(),
        build:  (_) => [
          pw.SizedBox(height: 6),
          _visitBody(
            visit: visit, prescription: prescription,
            examText: examinationText, radioText: radiologyText,
            fonts: fonts,
          ),
        ],
      ),
    );
    return pdf.save();
  }


  // ==========================================================================
  // PUBLIC — SURGERY PDF
  // ==========================================================================

  static Future<Uint8List> buildSurgeryPdf({
    required PatientEntity patient,
    required SurgeryEntity surgery,
    String? clinicAddress,
  }) async {
    final pdf   = pw.Document();
    final logo  = await _logo();
    final fonts = await _loadFonts();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        header: (_) => _header(patient: patient, date: surgery.surgeryDate, logo: logo, fonts: fonts),
        footer: (_) => pw.SizedBox(),
        build:  (_) => [
          pw.SizedBox(height: 6),
          _surgeryBody(surgery: surgery, fonts: fonts),
        ],
      ),
    );
    return pdf.save();
  }


  // ==========================================================================
  // PUBLIC — PRINT / SHARE
  // ==========================================================================

  static Future<void> printPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> sharePdf(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }


  // ==========================================================================
  // PAGE THEME
  // ==========================================================================

  static pw.PageTheme _theme() {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(18, 18, 18, 18),
      buildBackground: (_) => pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _C.brd, width: 0.8),
          ),
        ),
      ),
    );
  }


  // ==========================================================================
  // FONT LOADING
  // ==========================================================================

  static Future<_Fonts> _loadFonts() async {
    final body = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final ital = pw.Font.helveticaOblique();

    pw.Font clinic, doctor, tagline;
    try   { clinic  = await PdfGoogleFonts.oswaldRegular(); }
    catch (_) { clinic = bold; }
    try   { doctor  = await PdfGoogleFonts.loraBold(); }
    catch (_) { doctor = bold; }
    try   { tagline = await PdfGoogleFonts.lobsterTwoItalic(); }
    catch (_) { tagline = ital; }

    return _Fonts(body: body, bold: bold, ital: ital,
        clinic: clinic, doctor: doctor, tagline: tagline);
  }


  // ==========================================================================
  // LETTERHEAD HEADER
  //
  // Layout (top → bottom):
  //   1. Full-width blue container (155pt)
  //      TOP ROW (0–52pt) — pure blue, no cream panel:
  //        • Clinic name — Oswald large purple, left side
  //        • Doctor name — Lora Bold large navy, right side
  //      LOWER SECTION (52–155pt) — cream panel + tagline + credentials:
  //        • Cream logo panel — starts at top:52, left edge, 118pt wide
  //        • Tagline — Lobster Two Italic, below clinic name, left
  //        • Credentials — small right-aligned
  //        • Dot pattern — lower-centre/right only
  //   2. Cream pointed triangle (shield bottom, 118×18pt)
  //   3. Thin olive-green divider
  //   4. Patient Name / Date row (indented by logo panel width)
  // ==========================================================================

  static const double _logoW = 118.0; // cream panel width
  // The name row above the cream panel
  static const double _nameRowH = 52.0;

  static pw.Widget _header({
    required PatientEntity patient,
    required DateTime date,
    required pw.MemoryImage? logo,
    required _Fonts fonts,
  }) {
    const double blueH  = 155.0; // total blue strip height
    const double triH   = 18.0;
    const double credW  = 246.0; // credentials / doctor-name column

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [

        // ── BLUE HEADER STRIP ────────────────────────────────────────────────
        pw.Container(
          height: blueH,
          color: _C.blue,
          child: pw.Stack(
            children: [

              // Grey dot pattern — lower section only (below the name row)
              pw.Positioned(
                top: _nameRowH + 12, left: 200, right: 0, bottom: 0,
                child: _dots(),
              ),

              // ── CREAM LOGO PANEL ─────────────────────────────────────────────
              // Starts BELOW the name row — top-left of blue header is pure blue
              pw.Positioned(
                top: _nameRowH, left: 0, bottom: 0,
                child: pw.Container(
                  width: _logoW,
                  color: _C.cream,
                  padding: const pw.EdgeInsets.all(10),
                  child: logo != null
                      ? pw.Image(logo, fit: pw.BoxFit.contain)
                      : pw.Center(
                          child: pw.Text(
                            'BSC',
                            style: pw.TextStyle(
                              font: fonts.bold, fontSize: 20, color: _C.navy,
                            ),
                          ),
                        ),
                ),
              ),

              // ── CLINIC NAME (Oswald, purple) — TOP ROW ──────────────────────
              // No cream panel in this row, so positioned freely from left
              pw.Positioned(
                top: 14,
                left: 130,
                child: pw.Text(
                  _DI.clinic,
                  style: pw.TextStyle(
                    font: fonts.clinic,
                    fontSize: 24,
                    color: _C.purple,
                    letterSpacing: 0.4,
                  ),
                ),
              ),

              // ── TAGLINE (script) — LOWER SECTION, after cream panel ──────────
              pw.Positioned(
                top: _nameRowH + 14,
                left: _logoW + 16,
                child: pw.Text(
                  _DI.tagline,
                  style: pw.TextStyle(
                    font: fonts.tagline,
                    fontSize: 11.5,
                    color: _C.tline,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              // ── DOCTOR NAME (Lora Bold, navy) — TOP ROW, right-aligned ───────
              pw.Positioned(
                top: 12,
                right: 0,
                child: pw.SizedBox(
                  width: credW,
                  child: pw.Text(
                    _DI.name,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      font: fonts.doctor,
                      fontSize: 23,
                      color: _C.navy,
                    ),
                  ),
                ),
              ),

              // ── CREDENTIALS — right-aligned, in lower section ────────────────
              pw.Positioned(
                top: _nameRowH + 2,
                right: 0,
                child: pw.SizedBox(
                  width: credW,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _cred(_DI.title, fonts.body, 8.5),
                      _cred(_DI.deg1,  fonts.body, 8.0),
                      _cred(_DI.deg2,  fonts.body, 8.0),
                      _cred(_DI.deg3,  fonts.body, 8.0),
                      _cred(_DI.deg4,  fonts.body, 7.5),
                      pw.SizedBox(height: 2),
                      _credWeb(_DI.web, fonts.body),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── CREAM POINTED TRIANGLE (shield bottom of logo panel) ─────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.CustomPaint(
              size: const PdfPoint(_logoW, triH),
              painter: (PdfGraphics g, PdfPoint sz) {
                // PDF y-axis: 0 = bottom, sz.y = top of widget
                // → draws downward-pointing triangle (flat at top, point at bottom)
                g
                  ..setFillColor(_C.cream)
                  ..moveTo(0, sz.y)       // top-left
                  ..lineTo(sz.x, sz.y)    // top-right
                  ..lineTo(sz.x / 2, 0)   // bottom-centre (point)
                  ..closePath()
                  ..fillPath();
              },
            ),
            pw.Expanded(child: pw.SizedBox()),
          ],
        ),

        // ── GREEN HORIZONTAL DIVIDER ─────────────────────────────────────────
        pw.SizedBox(height: 4),
        pw.Container(height: 1.2, color: _C.green),
        pw.SizedBox(height: 8),

        // ── PATIENT NAME / DATE ──────────────────────────────────────────────
        // Indented by logo panel width so it aligns with text content above
        _patientRow(patient: patient, date: date, fonts: fonts),
        pw.SizedBox(height: 8),
      ],
    );
  }


  // Credential text — right-aligned
  static pw.Widget _cred(String text, pw.Font font, double size) {
    return pw.Text(
      text,
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(font: font, fontSize: size, color: _C.txt),
    );
  }

  // Website with globe character
  static pw.Widget _credWeb(String url, pw.Font font) {
    return pw.Text(
      '⊗  $url',  // ⊗ circle-cross as globe substitute
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(font: font, fontSize: 7.5, color: _C.txt),
    );
  }


  // ==========================================================================
  // DOT PATTERN  (circles, not diamonds)
  // ==========================================================================

  static pw.Widget _dots() {
    final children = <pw.Widget>[];
    const sp   = 10.0;
    const cols = 32;
    const rows = 9;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        children.add(
          pw.Positioned(
            left: c * sp.toDouble(),
            top:  r * sp.toDouble(),
            child: pw.Container(
              width:  1.4,
              height: 1.4,
              decoration: const pw.BoxDecoration(
                color: _C.dot,
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
        );
      }
    }
    return pw.Stack(children: children);
  }


  // ==========================================================================
  // PATIENT NAME / DATE ROW
  // ==========================================================================

  static pw.Widget _patientRow({
    required PatientEntity patient,
    required DateTime date,
    required _Fonts fonts,
  }) {
    const underline = pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: _C.grey, width: 0.7),
      ),
    );
    final lbl = pw.TextStyle(font: fonts.bold, fontSize: 10, color: _C.dark);
    final val = pw.TextStyle(font: fonts.body, fontSize: 10, color: _C.dark);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Gap matching the logo panel so labels align with header content
        pw.SizedBox(width: _logoW + 12),

        // "Patient Name :"  — label is NOT underlined
        pw.Text('Patient Name :', style: lbl),
        pw.SizedBox(width: 8),

        // Value area — underlined
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 2),
            decoration: underline,
            child: pw.Text(patient.fullName, style: val),
          ),
        ),

        pw.SizedBox(width: 30),

        // "Date :" — label is NOT underlined
        pw.Text('Date :', style: lbl),
        pw.SizedBox(width: 8),

        // Value area — underlined
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 2),
            decoration: underline,
            child: pw.Text(
              DateFormat('dd-MM-yyyy').format(date),
              style: val,
            ),
          ),
        ),
      ],
    );
  }


  // ==========================================================================
  // VISIT BODY
  // ==========================================================================

  static pw.Widget _visitBody({
    required VisitEntity visit,
    PrescriptionEntity? prescription,
    String? examText,
    String? radioText,
    required _Fonts fonts,
  }) {
    final rx = _rxText(prescription);

    final content = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [

        // ── PATIENT CONTACT & ID ────────────────────────────────────────────
        _sec('PATIENT CONTACT & ID', fonts.bold),
        _fld('Phone',   '',          fonts),
        pw.SizedBox(height: 4),
        _fld('Address', '',          fonts),
        _div(),

        // ── VITALS ──────────────────────────────────────────────────────────
        // "VITALS" heading on its own line, then fields row below
        _sec('VITALS', fonts.bold),
        _vitalsRow(fonts),
        _div(),

        // ── PRESENTING COMPLAINTS ───────────────────────────────────────────
        _sec('PRESENTING COMPLAINTS', fonts.bold),
        _fld('Chief Complaint',  visit.complaints ?? '', fonts),
        pw.SizedBox(height: 4),
        _fld('Previous History', '',                    fonts),
        _div(),

        // ── EXAMINATION FINDINGS ────────────────────────────────────────────
        _sec('EXAMINATION FINDINGS', fonts.bold),
        _fld('General', examText ?? visit.examination ?? '', fonts),
        _div(),

        // ── ADVICE ──────────────────────────────────────────────────────────
        _sec('ADVICE', fonts.bold),
        _fld('', visit.plan ?? '', fonts),
        _blankLine(),
        _div(),

        // ── TREATMENT (MEDICINES) ───────────────────────────────────────────
        _sec('TREATMENT (MEDICINES)', fonts.bold),
        rx.isNotEmpty
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  rx,
                  style: pw.TextStyle(
                    font: fonts.ital, fontSize: 9.5, color: _C.txt, lineSpacing: 1.5,
                  ),
                ),
              )
            : pw.Column(children: [_blankLine(), _blankLine()]),
        _div(),

        // ── INVESTIGATIONS ──────────────────────────────────────────────────
        _sec('INVESTIGATIONS', fonts.bold),
        _fld('Clinical Diagnosis',   visit.clinicalImpression ?? '', fonts),
        pw.SizedBox(height: 4),
        _fld('Imaging',              radioText ?? '',                fonts),
        pw.SizedBox(height: 4),
        _fld('Other Investigation',  '',                             fonts),
        pw.SizedBox(height: 4),
        _fld('Impression',           '',                             fonts),
        _div(),

        // ── CROSS REFERENCE ─────────────────────────────────────────────────
        _sec('CROSS REFERENCE (OTHER DOCTOR CONSULTATION)', fonts.bold),
        _fld('Additional Clinical diagnosis', visit.notes ?? '', fonts),
      ],
    );

    return _withSidebar(content: content, fonts: fonts);
  }


  // ==========================================================================
  // SURGERY BODY
  // ==========================================================================

  static pw.Widget _surgeryBody({
    required SurgeryEntity surgery,
    required _Fonts fonts,
  }) {
    final team = <String>[];
    if (_has(surgery.primarySurgeon))    team.add('Primary: ${surgery.primarySurgeon}');
    if (_has(surgery.assistantSurgeons)) team.add('Assistants: ${surgery.assistantSurgeons}');
    if (_has(surgery.anesthesiaType))    team.add('Anaesthesia: ${surgery.anesthesiaType}');
    if (_has(surgery.anesthesiologist))  team.add('Anaesthesiologist: ${surgery.anesthesiologist}');

    final content = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [

        _sec('PRE-OPERATIVE DIAGNOSIS', fonts.bold),
        _fld('Diagnosis', surgery.preOpDiagnosis ?? '', fonts),
        _div(),

        _sec('PROCEDURE', fonts.bold),
        _fld('Procedure', surgery.procedure ?? '', fonts),
        _div(),

        _sec('SURGICAL TEAM', fonts.bold),
        team.isNotEmpty
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  team.join('\n'),
                  style: pw.TextStyle(font: fonts.body, fontSize: 9.5, color: _C.txt, lineSpacing: 1.5),
                ),
              )
            : _blankLine(),
        _div(),

        _sec('INTRAOPERATIVE FINDINGS', fonts.bold),
        _fld('Findings', surgery.intraopFindings ?? '', fonts),
        _div(),

        _sec('IMPLANTS / INSTRUMENTATION', fonts.bold),
        _fld('Implants', surgery.implants ?? '', fonts),
        _div(),

        _sec('OPERATIVE NOTES', fonts.bold),
        _fld('Notes', surgery.otNotes ?? '', fonts),
        _div(),

        _sec('COMPLICATIONS', fonts.bold),
        _fld('Complications', surgery.complications ?? '', fonts),
        _div(),

        _sec('POST-OPERATIVE PLAN', fonts.bold),
        _fld('Plan', surgery.postOpPlan ?? '', fonts),
      ],
    );

    return _withSidebar(content: content, fonts: fonts);
  }


  // ==========================================================================
  // TWO-COLUMN LAYOUT — left specialisation sidebar + right content
  //
  // Per-item height:
  //   symmetric(vertical:8) padding = 16pt + text ≈9pt + divider 0.5pt ≈ 25.5pt
  //   Initial SizedBox(height: 5)
  //   Item 0 ends at: 5 + 25.5 = 30.5pt
  //   Red bar top (item 1 start): ≈ 31pt
  //   Items 1–7 = 7 × 25.5 = 178.5pt  → height ≈ 179pt
  // ==========================================================================

  static pw.Widget _withSidebar({
    required pw.Widget content,
    required _Fonts fonts,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [

        // ── LEFT SIDEBAR ───────────────────────────────────────────────────
        pw.Container(
          width: 145,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              right: pw.BorderSide(color: _C.sgrn, width: 1.0),
            ),
          ),
          child: pw.Stack(
            children: [

              // Red vertical bar — Vascular Neurosurgery (item 1) → Slip disc (item 7)
              pw.Positioned(
                left: 5,
                top: 31,
                child: pw.Container(
                  width: 3,
                  height: 179,
                  color: _C.red,
                ),
              ),

              // Specialisation list
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 16, right: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 5),
                    ..._DI.specs.map(
                      (item) => pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: _C.green, width: 0.5),
                          ),
                        ),
                        child: pw.Text(
                          item,
                          style: pw.TextStyle(
                            font: fonts.body,
                            fontSize: 8.0,
                            color: _C.sbar,
                            lineSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 14),

        // ── MAIN CONTENT ───────────────────────────────────────────────────
        pw.Expanded(child: content),
      ],
    );
  }


  // ==========================================================================
  // SECTION HEADING  — bold navy, no background fill
  // ==========================================================================

  static pw.Widget _sec(String title, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 5),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 9.5,
          color: _C.navy,
          letterSpacing: 0.3,
        ),
      ),
    );
  }


  // ==========================================================================
  // FIELD ROW
  //   [Label in fixed-width box]  [colon]  [underlined value area]
  // ==========================================================================

  static pw.Widget _fld(String label, String value, _Fonts fonts) {
    const underline = pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: _C.grey, width: 0.7),
      ),
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (label.isNotEmpty) ...[
            pw.SizedBox(
              width: 115,
              child: pw.Text(
                label,
                style: pw.TextStyle(font: fonts.bold, fontSize: 9.5, color: _C.dark),
              ),
            ),
            pw.Text(
              '  :',
              style: pw.TextStyle(font: fonts.body, fontSize: 9.5, color: _C.dark),
            ),
            pw.SizedBox(width: 4),
          ],
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 1),
              decoration: underline,
              child: pw.Text(
                value,
                style: pw.TextStyle(font: fonts.body, fontSize: 9.5, color: _C.txt),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ==========================================================================
  // VITALS ROW  (appears BELOW the "VITALS" section heading)
  //   Weight :  [blank]   Blood Pressure :  [blank]   Temperature :  [blank]
  //   All on ONE horizontal line, no "Vitals :" prefix here
  // ==========================================================================

  static pw.Widget _vitalsRow(_Fonts fonts) {
    const underline = pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: _C.grey, width: 0.7),
      ),
    );

    pw.Widget box(double w) => pw.SizedBox(
      width: w,
      child: pw.Container(height: 14, decoration: underline),
    );

    final b = pw.TextStyle(font: fonts.bold, fontSize: 9.5, color: _C.dark);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('Weight  :', style: b),
          pw.SizedBox(width: 4),
          box(68),
          pw.SizedBox(width: 22),
          pw.Text('Blood Pressure  :', style: b),
          pw.SizedBox(width: 4),
          box(68),
          pw.SizedBox(width: 22),
          pw.Text('Temperature  :', style: b),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Container(height: 14, decoration: underline),
          ),
        ],
      ),
    );
  }


  // ==========================================================================
  // SECTION DIVIDER  (thin olive-green line)
  // ==========================================================================

  static pw.Widget _div() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
      child: pw.Container(height: 0.7, color: _C.green),
    );
  }


  // ==========================================================================
  // BLANK UNDERLINED LINE  (for empty write-in areas)
  // ==========================================================================

  static pw.Widget _blankLine() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Container(
        height: 16,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: _C.grey, width: 0.7),
          ),
        ),
      ),
    );
  }


  // ==========================================================================
  // PRESCRIPTION → plain text
  // ==========================================================================

  static String _rxText(PrescriptionEntity? rx) {
    if (rx == null) return '';
    final lines = <String>[];
    if (rx.text?.trim().isNotEmpty == true) lines.add(rx.text!.trim());
    for (var i = 0; i < rx.drugs.length; i++) {
      final d = rx.drugs[i];
      var l = '${i + 1}. ${d.displayName}';
      if (d.displayDosage.trim().isNotEmpty) l += '  –  ${d.displayDosage}';
      lines.add(l);
    }
    return lines.join('\n');
  }

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;


  // ==========================================================================
  // LOGO LOADING  (png → jpeg fallback)
  // ==========================================================================

  static Future<pw.MemoryImage?> _logo() async {
    try {
      try {
        final d = await rootBundle.load('assets/images/app_logo.png');
        return pw.MemoryImage(d.buffer.asUint8List());
      } catch (_) {}
      final d = await rootBundle.load('assets/images/app_logo.jpeg');
      return pw.MemoryImage(d.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
