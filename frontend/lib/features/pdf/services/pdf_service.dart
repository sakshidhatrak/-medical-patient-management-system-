import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../patients/domain/entities/patient_entity.dart';
import '../../prescriptions/domain/entities/prescription_entity.dart';
import '../../surgeries/domain/entities/surgery_entity.dart';
import '../../visits/domain/entities/visit_entity.dart';

// ── Clinic constants ──────────────────────────────────────────────────────────

class _DoctorInfo {
  static const name       = 'Dr. Harshal S. Chaudhari';
  static const title      = 'Consultant Neurosurgeon (Brain and Spine)';
  static const degree1    = 'MBBS, MS Gen. Surg. (KEM Hospital, Mumbai)';
  static const degree2    = 'MCh Neurosurgery (GMC, Goa)';
  static const degree3    = 'Fellow in NeuroSurgical Oncology (TMH, Mumbai)';
  static const regNo      = 'MMC Reg. No: 2009031020';
  static const website    = 'www.thebrainandspineclinic.com';
  static const phone      = '+91 98765 43210';
  static const clinicName = 'The Brain & Spine Clinic';
  static const tagline    = 'Excellence, Ethics, Efficiency';
  static var   address    = 'Clinic Address: (update in settings)';
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

class _C {
  static const navy    = PdfColor.fromInt(0xFF1A2D5A);
  static const gold    = PdfColor.fromInt(0xFFC8A951);
  static const white   = PdfColors.white;
  static const text    = PdfColor.fromInt(0xFF1A1A1A);
  static const sub     = PdfColor.fromInt(0xFF666666);
  static const border  = PdfColor.fromInt(0xFFCCCCCC);
  static const bgLight = PdfColor.fromInt(0xFFF8F6F0);
  static const red     = PdfColor.fromInt(0xFFB71C1C);
}

/// Generates Visit and Surgery PDFs using the Brain & Spine Clinic letterhead.
class PdfService {
  // ── VISIT PDF ──────────────────────────────────────────────────────────────

  static Future<Uint8List> buildVisitPdf({
    required PatientEntity patient,
    required VisitEntity visit,
    PrescriptionEntity? prescription,
    String? examinationText,
    String? radiologyText,
    String? clinicAddress,
  }) async {
    if (clinicAddress != null) _DoctorInfo.address = 'Clinic: $clinicAddress';

    final pdf  = pw.Document();
    final logo = await _loadLogo();

    pw.Font font;
    pw.Font fontBold;
    pw.Font fontItal;
    try {
      font     = await PdfGoogleFonts.nunitoRegular();
      fontBold = await PdfGoogleFonts.nunitoBold();
      fontItal = await PdfGoogleFonts.nunitoItalic();
    } catch (_) {
      font     = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
      fontItal = pw.Font.helveticaOblique();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        header: (_) => _letterheadHeader(
            patient, visit.visitDate, logo, font, fontBold),
        footer: (ctx) => _letterheadFooter(ctx, logo, font, fontBold),
        build: (_) => [
          pw.SizedBox(height: 10),
          _buildVisitBody(
            visit:        visit,
            prescription: prescription,
            examination:  examinationText,
            radiology:    radiologyText,
            font:         font,
            fontBold:     fontBold,
            fontItal:     fontItal,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ── SURGERY PDF ────────────────────────────────────────────────────────────

  static Future<Uint8List> buildSurgeryPdf({
    required PatientEntity patient,
    required SurgeryEntity surgery,
    String? clinicAddress,
  }) async {
    if (clinicAddress != null) _DoctorInfo.address = 'Clinic: $clinicAddress';

    final pdf  = pw.Document();
    final logo = await _loadLogo();

    pw.Font font;
    pw.Font fontBold;
    try {
      font     = await PdfGoogleFonts.nunitoRegular();
      fontBold = await PdfGoogleFonts.nunitoBold();
    } catch (_) {
      font     = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        header: (_) => _letterheadHeader(
            patient, surgery.surgeryDate, logo, font, fontBold,
            isSurgery: true),
        footer: (ctx) => _letterheadFooter(ctx, logo, font, fontBold),
        build: (_) => [
          pw.SizedBox(height: 10),
          _buildSurgeryBody(
              surgery: surgery, font: font, fontBold: fontBold),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Print / Share ──────────────────────────────────────────────────────────

  static Future<void> printPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> sharePdf(Uint8List bytes, String filename) async {
    await Printing.layoutPdf(
      name: filename,
      onLayout: (_) async => bytes,
    );
  }

  // ── SHARED HEADER ──────────────────────────────────────────────────────────

  static pw.Widget _letterheadHeader(
    PatientEntity patient,
    DateTime date,
    pw.MemoryImage? logo,
    pw.Font font,
    pw.Font fontBold, {
    bool isSurgery = false,
  }) {
    final bannerColor = isSurgery ? _C.red : _C.navy;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Clinic banner
        pw.Container(
          color: bannerColor,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.SizedBox(
                  width: 52,
                  height: 62,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 10),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _DoctorInfo.clinicName,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: _C.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _DoctorInfo.tagline,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: _C.gold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                width: 1,
                height: 54,
                color: _C.gold,
                margin: const pw.EdgeInsets.symmetric(horizontal: 14),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    _DoctorInfo.name,
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 11, color: _C.white),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _DoctorInfo.title,
                    style: pw.TextStyle(
                        font: font, fontSize: 7.5, color: _C.gold),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _DoctorInfo.degree1,
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 7,
                        color: const PdfColor(1, 1, 1, 0.75)),
                  ),
                  pw.Text(
                    _DoctorInfo.degree2,
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 7,
                        color: const PdfColor(1, 1, 1, 0.75)),
                  ),
                  pw.Text(
                    _DoctorInfo.degree3,
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 6.5,
                        color: const PdfColor(1, 1, 1, 0.65)),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _DoctorInfo.website,
                    style: pw.TextStyle(
                        font: font, fontSize: 7, color: _C.gold),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Gold accent line
        pw.Container(height: 3, color: _C.gold),
        pw.SizedBox(height: 6),
        // Patient info bar
        _patientInfoBar(patient, date, font, fontBold),
        pw.SizedBox(height: 6),
        // Report sub-heading
        pw.Container(
          color: _C.bgLight,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: pw.Row(children: [
            pw.Container(width: 3, height: 12, color: bannerColor),
            pw.SizedBox(width: 6),
            pw.Text(
              isSurgery
                  ? 'SURGICAL OPERATION NOTE'
                  : 'OUTPATIENT CONSULTATION REPORT',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 8.5,
                color: bannerColor,
                letterSpacing: 1.0,
              ),
            ),
          ]),
        ),
      ],
    );
  }

  static pw.Widget _patientInfoBar(
    PatientEntity patient,
    DateTime date,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _C.navy, width: 1),
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          _infoCell('Patient Name', patient.fullName, font, fontBold,
              flex: 3),
          _divBar(),
          _infoCell(
              'Age / Sex', patient.ageSex, font, fontBold, flex: 2),
          _divBar(),
          _infoCell('PRN / UHID', patient.prn, font, fontBold, flex: 2),
          _divBar(),
          _infoCell(
            'Date',
            DateFormat('dd MMM yyyy').format(date),
            font,
            fontBold,
            flex: 2,
          ),
        ],
      ),
    );
  }

  static pw.Widget _divBar() =>
      pw.Container(width: 1, height: 34, color: _C.navy);

  static pw.Widget _infoCell(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold, {
    int flex = 1,
  }) =>
      pw.Expanded(
        flex: flex,
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: font, fontSize: 6.5, color: _C.sub)),
              pw.SizedBox(height: 2),
              pw.Text(
                value.isEmpty ? '—' : value,
                style: pw.TextStyle(
                    font: fontBold, fontSize: 9.5, color: _C.navy),
                maxLines: 1,
              ),
            ],
          ),
        ),
      );

  // ── SHARED FOOTER ──────────────────────────────────────────────────────────

  static pw.Widget _letterheadFooter(
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
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 18),
                  pw.Container(
                      height: 0.7, width: 110, color: _C.navy),
                  pw.SizedBox(height: 3),
                  pw.Text(_DoctorInfo.name,
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 9, color: _C.navy)),
                  pw.Text(_DoctorInfo.title,
                      style: pw.TextStyle(
                          font: font, fontSize: 7, color: _C.sub)),
                  pw.SizedBox(height: 2),
                  pw.Text(_DoctorInfo.degree1,
                      style: pw.TextStyle(
                          font: font, fontSize: 6.5, color: _C.sub)),
                  pw.Text(_DoctorInfo.degree2,
                      style: pw.TextStyle(
                          font: font, fontSize: 6.5, color: _C.sub)),
                  pw.Text(_DoctorInfo.regNo,
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 7, color: _C.navy)),
                ],
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Center(
                child: pw.Container(
                  width: 58,
                  height: 58,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border:
                        pw.Border.all(color: _C.navy, width: 1.5),
                  ),
                  child: pw.Center(
                    child: logo != null
                        ? pw.Image(logo,
                            width: 44,
                            height: 44,
                            fit: pw.BoxFit.contain)
                        : pw.Text('BSC',
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 9,
                                color: _C.navy)),
                  ),
                ),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border:
                      pw.Border.all(color: _C.navy, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FOLLOW UP / REVIEW',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        color: _C.navy,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(children: [
                      pw.Text('Date: ',
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 7.5,
                              color: _C.sub)),
                      pw.Container(
                          width: 70, height: 0.5, color: _C.border),
                    ]),
                    pw.SizedBox(height: 8),
                    pw.Text('Notes:',
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 7.5,
                            color: _C.sub)),
                    pw.SizedBox(height: 4),
                    pw.Container(height: 0.5, color: _C.border),
                    pw.SizedBox(height: 10),
                    pw.Container(height: 0.5, color: _C.border),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          color: _C.navy,
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 12, vertical: 5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _DoctorInfo.address,
                style: pw.TextStyle(
                    font: font, fontSize: 7.5, color: _C.gold),
              ),
              pw.Text(
                'Phone: ${_DoctorInfo.phone}   |   ${_DoctorInfo.website}',
                style: pw.TextStyle(
                    font: font, fontSize: 7.5, color: _C.white),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(
                    font: font, fontSize: 7, color: _C.gold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── VISIT BODY ─────────────────────────────────────────────────────────────

  static pw.Widget _buildVisitBody({
    required VisitEntity visit,
    PrescriptionEntity? prescription,
    String? examination,
    String? radiology,
    required pw.Font font,
    required pw.Font fontBold,
    required pw.Font fontItal,
  }) {
    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(130),
        1: pw.FlexColumnWidth(1),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
      border: pw.TableBorder.all(color: _C.navy, width: 0.8),
      children: [
        pw.TableRow(children: [
          _specColumn(font, fontBold),
          _visitClinicalColumn(
            visit:        visit,
            prescription: prescription,
            examination:  examination,
            radiology:    radiology,
            font:         font,
            fontBold:     fontBold,
            fontItal:     fontItal,
          ),
        ]),
      ],
    );
  }

  static pw.Widget _visitClinicalColumn({
    required VisitEntity visit,
    PrescriptionEntity? prescription,
    String? examination,
    String? radiology,
    required pw.Font font,
    required pw.Font fontBold,
    required pw.Font fontItal,
  }) {
    final examText = examination ?? visit.examination ?? '';
    final rxText   = _prescriptionText(prescription);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _section('PRESENTING COMPLAINTS & CLINICAL HISTORY',
            visit.complaints ?? '', font, fontBold, top: false),
        _sectionDiv(),
        _section('EXAMINATION FINDINGS', examText, font, fontBold),
        _sectionDiv(),
        _section('REPORTS', radiology ?? '', font, fontBold),
        pw.Container(height: 2, color: _C.navy),
        _section('ADVICE', visit.plan ?? '', font, fontBold, top: false),
        _sectionDiv(),
        _section('TREATMENT (MEDICINES)', rxText, font, fontBold,
            bodyFont: fontItal),
        pw.Container(height: 2, color: _C.navy),
        _section('INVESTIGATIONS', visit.clinicalImpression ?? '',
            font, fontBold, top: false),
        _sectionDiv(),
        _section('CROSS REFERENCE (OTHER DOCTOR CONSULTATION)',
            visit.notes ?? '', font, fontBold),
      ],
    );
  }

  static String _prescriptionText(PrescriptionEntity? rx) {
    if (rx == null) return '';
    final parts = <String>[];
    if (rx.text != null && rx.text!.isNotEmpty) parts.add(rx.text!.trim());
    for (var i = 0; i < rx.drugs.length; i++) {
      final d = rx.drugs[i];
      var line = '${i + 1}. ${d.displayName}';
      if (d.displayDosage.isNotEmpty) line += '  –  ${d.displayDosage}';
      parts.add(line);
    }
    return parts.join('\n');
  }

  // ── SURGERY BODY ───────────────────────────────────────────────────────────

  static pw.Widget _buildSurgeryBody({
    required SurgeryEntity surgery,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    final team = [
      if (_has(surgery.primarySurgeon))
        'Primary: ${surgery.primarySurgeon}',
      if (_has(surgery.assistantSurgeons))
        'Assistants: ${surgery.assistantSurgeons}',
      if (_has(surgery.anesthesiaType))
        'Anaesthesia: ${surgery.anesthesiaType}',
      if (_has(surgery.anesthesiologist))
        'Anaesthesiologist: ${surgery.anesthesiologist}',
    ].join('\n');

    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(130),
        1: pw.FlexColumnWidth(1),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
      border: pw.TableBorder.all(color: _C.red, width: 0.8),
      children: [
        pw.TableRow(children: [
          _specColumn(font, fontBold, color: _C.red),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _section('PRE-OPERATIVE DIAGNOSIS',
                  surgery.preOpDiagnosis ?? '', font, fontBold,
                  top: false),
              _sectionDiv(),
              _section('PROCEDURE', surgery.procedure ?? '', font,
                  fontBold),
              pw.Container(height: 2, color: _C.red),
              _section('SURGICAL TEAM', team, font, fontBold,
                  top: false),
              _sectionDiv(),
              _section('INTRAOPERATIVE FINDINGS',
                  surgery.intraopFindings ?? '', font, fontBold),
              _sectionDiv(),
              _section('IMPLANTS / INSTRUMENTATION',
                  surgery.implants ?? '', font, fontBold),
              pw.Container(height: 2, color: _C.red),
              _section('OPERATIVE NOTES', surgery.otNotes ?? '', font,
                  fontBold, top: false),
              _sectionDiv(),
              _section('COMPLICATIONS', surgery.complications ?? '',
                  font, fontBold),
              _sectionDiv(),
              _section('POST-OPERATIVE PLAN',
                  surgery.postOpPlan ?? '', font, fontBold),
            ],
          ),
        ]),
      ],
    );
  }

  // ── Shared column widgets ──────────────────────────────────────────────────

  static pw.Widget _specColumn(
    pw.Font font,
    pw.Font fontBold, {
    PdfColor color = _C.navy,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: color,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(
            'OUR\nSPECIALISATION',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 8.5,
              color: _C.gold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ..._DoctorInfo.specialisations.asMap().entries.map(
          (e) => pw.Container(
            decoration: pw.BoxDecoration(
              color: e.key % 2 == 0 ? _C.bgLight : _C.white,
              border: pw.Border(
                bottom:
                    pw.BorderSide(color: _C.border, width: 0.4),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('◆',
                    style: pw.TextStyle(
                        font: font, fontSize: 5.5, color: _C.gold)),
                pw.SizedBox(width: 5),
                pw.Expanded(
                  child: pw.Text(
                    e.value,
                    style: pw.TextStyle(
                        font: font, fontSize: 8, color: _C.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _sectionDiv() =>
      pw.Divider(color: _C.border, thickness: 0.5, height: 0);

  static pw.Widget _section(
    String title,
    String content,
    pw.Font font,
    pw.Font fontBold, {
    bool top = true,
    pw.Font? bodyFont,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: top
              ? pw.BorderSide(color: _C.border, width: 0.3)
              : pw.BorderSide.none,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: _C.bgLight,
            padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 7.5,
                color: _C.navy,
                letterSpacing: 0.4,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: pw.Text(
              content.trim(),
              style: pw.TextStyle(
                font: bodyFont ?? font,
                fontSize: 9,
                color: _C.text,
                lineSpacing: 2.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static bool _has(String? s) => s != null && s.trim().isNotEmpty;

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/app_logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
