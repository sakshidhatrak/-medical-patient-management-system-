import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../patients/domain/entities/patient_entity.dart';
import '../../prescriptions/domain/entities/prescription_entity.dart';
import '../../surgeries/domain/entities/surgery_entity.dart';
import '../../visits/domain/entities/visit_entity.dart';

// ── Doctor / clinic constants ─────────────────────────────────────
class _DoctorInfo {
  static const name       = 'Dr. Harshal S. Chaudhari';
  static const title      = 'Consultant Neurosurgeon (Brain and Spine)';
  static const degrees    = 'MBBS, MS Gen. Surg. (KEM Hospital, Mumbai)\n'
      'MCh Neurosurgery (GMC, Goa)\n'
      'Fellow in NeuroSurgical Oncology (Tata Memorial Hospital, Mumbai)';
  static const regNo      = 'MMC Reg. No: 2009031020';
  static var clinicAddress = 'Clinic Address: (update in settings)';
}

// ── Colour palette ────────────────────────────────────────────────
class _C {
  static const primary = PdfColor.fromInt(0xFF1E3A5F);
  static const accent  = PdfColor.fromInt(0xFF2D7DD2);
  static const light   = PdfColor.fromInt(0xFFEFF4FB);
  static const border  = PdfColor.fromInt(0xFFCCCCCC);
  static const grey    = PdfColor.fromInt(0xFF666666);
  static const red     = PdfColor.fromInt(0xFFD32F2F);
}

/// Main entry point — generates a complete Visit PDF.
class PdfService {
  // ── VISIT PDF ─────────────────────────────────────────────────
  static Future<Uint8List> buildVisitPdf({
    required PatientEntity patient,
    required VisitEntity visit,
    PrescriptionEntity? prescription,
    String? examinationText,
    String? radiologyText,
    String? clinicAddress,
  }) async {
    if (clinicAddress != null) {
      _DoctorInfo.clinicAddress = 'Clinic: $clinicAddress';
    }

    final pdf = pw.Document();
    final font      = await PdfGoogleFonts.nunitoRegular();
    final fontBold  = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _header(patient, visit, fontBold, font),
        footer: (ctx) => _footer(ctx, font, fontBold),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          if (_has(visit.complaints))
            _section('Chief Complaints', visit.complaints!, font, fontBold),
          if (_has(examinationText ?? visit.examination))
            _section('Examination',
                examinationText ?? visit.examination!, font, fontBold),
          if (_has(radiologyText))
            _section('Investigations / Radiology', radiologyText!, font,
                fontBold),
          if (_has(visit.clinicalImpression))
            _section('Clinical Impression / Diagnosis',
                visit.clinicalImpression!, font, fontBold,
                accent: true),
          if (_has(visit.plan))
            _section('Management Plan', visit.plan!, font, fontBold),
          if (prescription != null && _hasPrescription(prescription))
            _prescriptionSection(prescription, font, fontBold),
          if (_has(visit.notes))
            _section('Notes', visit.notes!, font, fontBold,
                textStyle: pw.TextStyle(
                    font: fontItalic, fontSize: 10, color: _C.grey)),
        ],
      ),
    );

    return pdf.save();
  }

  // ── SURGERY PDF ───────────────────────────────────────────────
  static Future<Uint8List> buildSurgeryPdf({
    required PatientEntity patient,
    required SurgeryEntity surgery,
    String? clinicAddress,
  }) async {
    if (clinicAddress != null) {
      _DoctorInfo.clinicAddress = 'Clinic: $clinicAddress';
    }

    final pdf = pw.Document();
    final font      = await PdfGoogleFonts.nunitoRegular();
    final fontBold  = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _surgeryHeader(patient, surgery, fontBold, font),
        footer: (ctx) => _footer(ctx, font, fontBold),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          if (_has(surgery.preOpDiagnosis))
            _section('Pre-operative Diagnosis', surgery.preOpDiagnosis!,
                font, fontBold, accent: true),
          if (_has(surgery.procedure))
            _section('Procedure', surgery.procedure!, font, fontBold,
                accent: true),
          _surgeryTeamSection(surgery, font, fontBold),
          if (_has(surgery.implants))
            _section('Implants / Instrumentation', surgery.implants!, font,
                fontBold),
          if (_has(surgery.intraopFindings))
            _section('Intraoperative Findings', surgery.intraopFindings!,
                font, fontBold),
          if (_has(surgery.otNotes))
            _section('Operative Notes', surgery.otNotes!, font, fontBold),
          if (_has(surgery.complications))
            _section('Complications', surgery.complications!, font, fontBold,
                accentColor: _C.red),
          if (_has(surgery.postOpPlan))
            _section('Post-operative Plan', surgery.postOpPlan!, font,
                fontBold),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Print ─────────────────────────────────────────────────────
  static Future<void> printPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  // ── Share as PDF ──────────────────────────────────────────────
  static Future<void> sharePdf(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  // ── Helpers ───────────────────────────────────────────────────

  static bool _has(String? s) => s != null && s.trim().isNotEmpty;

  static bool _hasPrescription(PrescriptionEntity p) =>
      _has(p.text) || p.drugs.isNotEmpty;

  static pw.Widget _header(
    PatientEntity patient,
    VisitEntity visit,
    pw.Font fontBold,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Clinic header
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(color: _C.primary),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_DoctorInfo.name,
                      style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 14,
                          color: PdfColors.white)),
                  pw.Text(_DoctorInfo.title,
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: PdfColor(1, 1, 1, 0.7))),
                ],
              ),
              pw.Text(
                DateFormat('dd MMM yyyy').format(visit.visitDate),
                style: pw.TextStyle(
                    font: fontBold, fontSize: 11, color: PdfColors.white),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        // Patient info bar
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _C.light,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: _C.border, width: 0.5),
          ),
          child: pw.Row(
            children: [
              _patientInfoCell(
                  'Patient', patient.fullName, fontBold, font,
                  large: true),
              _patientInfoCell('PRN', patient.prn, fontBold, font),
              if (patient.ageSex.isNotEmpty)
                _patientInfoCell('Age / Sex', patient.ageSex, fontBold, font),
              if (_has(patient.phone))
                _patientInfoCell('Phone', patient.phone!, fontBold, font),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text('OUTPATIENT VISIT SUMMARY',
            style: pw.TextStyle(
                font: fontBold, fontSize: 10, color: _C.accent,
                letterSpacing: 1.5)),
        pw.Divider(color: _C.accent, thickness: 1),
      ],
    );
  }

  static pw.Widget _surgeryHeader(
    PatientEntity patient,
    SurgeryEntity surgery,
    pw.Font fontBold,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: _C.red),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_DoctorInfo.name,
                      style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 14,
                          color: PdfColors.white)),
                  pw.Text(_DoctorInfo.title,
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: PdfColor(1, 1, 1, 0.7))),
                ],
              ),
              pw.Text(
                DateFormat('dd MMM yyyy').format(surgery.surgeryDate),
                style: pw.TextStyle(
                    font: fontBold, fontSize: 11, color: PdfColors.white),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _C.light,
            border: pw.Border.all(color: _C.border, width: 0.5),
          ),
          child: pw.Row(
            children: [
              _patientInfoCell(
                  'Patient', patient.fullName, fontBold, font,
                  large: true),
              _patientInfoCell('PRN', patient.prn, fontBold, font),
              if (patient.ageSex.isNotEmpty)
                _patientInfoCell(
                    'Age / Sex', patient.ageSex, fontBold, font),
              if (_has(surgery.yourRole))
                _patientInfoCell(
                    'Role', surgery.yourRole!, fontBold, font),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text('SURGICAL NOTE',
            style: pw.TextStyle(
                font: fontBold, fontSize: 10, color: _C.red,
                letterSpacing: 1.5)),
        pw.Divider(color: _C.red, thickness: 1),
      ],
    );
  }

  static pw.Widget _patientInfoCell(
    String label,
    String value,
    pw.Font fontBold,
    pw.Font font, {
    bool large = false,
  }) =>
      pw.Expanded(
        flex: large ? 3 : 2,
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(right: 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: font, fontSize: 8, color: _C.grey)),
              pw.Text(value,
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: large ? 12 : 10,
                      color: _C.primary)),
            ],
          ),
        ),
      );

  static pw.Widget _section(
    String title,
    String content,
    pw.Font font,
    pw.Font fontBold, {
    bool accent = false,
    PdfColor? accentColor,
    pw.TextStyle? textStyle,
  }) {
    final color = accentColor ?? (accent ? _C.accent : _C.primary);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: accent || accentColor != null
                ? color.shade(0.9)
                : PdfColors.grey200,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(title.toUpperCase(),
              style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: color,
                  letterSpacing: 0.8)),
        ),
        pw.SizedBox(height: 4),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, bottom: 10),
          child: pw.Text(
            content.trim(),
            style: textStyle ??
                pw.TextStyle(font: font, fontSize: 11, lineSpacing: 3),
          ),
        ),
      ],
    );
  }

  static pw.Widget _prescriptionSection(
    PrescriptionEntity rx,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const pw.BoxDecoration(color: PdfColors.green100),
          child: pw.Text('PRESCRIPTION / TREATMENT',
              style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: PdfColors.green900,
                  letterSpacing: 0.8)),
        ),
        pw.SizedBox(height: 4),
        if (_has(rx.text))
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 6),
            child: pw.Text(rx.text!.trim(),
                style: pw.TextStyle(font: font, fontSize: 11)),
          ),
        if (rx.drugs.isNotEmpty) ...[
          ...rx.drugs.asMap().entries.map(
                (e) => pw.Padding(
                  padding:
                      const pw.EdgeInsets.only(left: 8, bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${e.key + 1}. ',
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 11)),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(e.value.displayName,
                                style: pw.TextStyle(
                                    font: fontBold, fontSize: 11)),
                            if (e.value.composition?.isNotEmpty == true)
                              pw.Text(e.value.composition!,
                                  style: pw.TextStyle(
                                      font: font,
                                      fontSize: 9,
                                      color: _C.grey)),
                            if (e.value.displayDosage.isNotEmpty)
                              pw.Text(e.value.displayDosage,
                                  style: pw.TextStyle(
                                      font: font, fontSize: 10)),
                            if (e.value.taperingSteps.isNotEmpty)
                              ...e.value.taperingSteps.map(
                                (s) => pw.Padding(
                                  padding: const pw.EdgeInsets.only(
                                      left: 12),
                                  child: pw.Text(
                                      '→ ${s.dose}  ${s.duration}',
                                      style: pw.TextStyle(
                                          font: font,
                                          fontSize: 10,
                                          color: _C.grey)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _surgeryTeamSection(
    SurgeryEntity s,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final rows = <_Row>[];
    if (_has(s.primarySurgeon))
      rows.add(_Row('Primary Surgeon', s.primarySurgeon!));
    if (_has(s.assistantSurgeons))
      rows.add(_Row('Assistants', s.assistantSurgeons!));
    if (_has(s.anesthesiaType))
      rows.add(_Row('Anaesthesia', s.anesthesiaType!));
    if (_has(s.anesthesiologist))
      rows.add(_Row('Anaesthesiologist', s.anesthesiologist!));

    if (rows.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          child: pw.Text('SURGICAL TEAM',
              style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: _C.primary,
                  letterSpacing: 0.8)),
        ),
        pw.SizedBox(height: 4),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, bottom: 10),
          child: pw.Table(
            children: rows
                .map((r) => pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(
                            right: 12, bottom: 3),
                        child: pw.Text(r.label,
                            style: pw.TextStyle(
                                font: fontBold, fontSize: 10)),
                      ),
                      pw.Text(r.value,
                          style:
                              pw.TextStyle(font: font, fontSize: 10)),
                    ]))
                .toList(),
          ),
        ),
      ],
    );
  }

  static pw.Widget _footer(
    pw.Context ctx,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      children: [
        pw.Divider(color: _C.border, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_DoctorInfo.name,
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 9, color: _C.primary)),
                  pw.Text(_DoctorInfo.degrees,
                      style: pw.TextStyle(
                          font: font, fontSize: 7.5, color: _C.grey)),
                  pw.Text(_DoctorInfo.regNo,
                      style: pw.TextStyle(
                          font: font, fontSize: 7.5, color: _C.grey)),
                  pw.Text(_DoctorInfo.clinicAddress,
                      style: pw.TextStyle(
                          font: font, fontSize: 7.5, color: _C.grey)),
                ],
              ),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 8, color: _C.grey),
            ),
          ],
        ),
      ],
    );
  }
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}
