import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/models/print_field.dart';
import '../presentation/providers/print_config_provider.dart';

// ── Design tokens (black-and-white professional style) ─────────────────────────

const _kBlack = PdfColors.black;
const _kWhite = PdfColors.white;
const _kBorder = PdfColor.fromInt(0xFFCCCCCC);
const _kGrey100 = PdfColor.fromInt(0xFFF5F5F5);
const _kSub = PdfColor.fromInt(0xFF888888);
const _kText = PdfColor.fromInt(0xFF1A1A1A);

// Treatment fields shown in the Clinical Information block (not medications/notes/advice)
const _kClinicalIds = {
  'previousHistory',
  'chiefComplaint',
  'examGeneral',
  'examNeurological',
  'clinicalDiagnosis',
  'imaging',
  'otherInvestigation',
  'diagnosis',
  'treatmentPlan',
};

// ── Service ───────────────────────────────────────────────────────────────────

class PdfExportService {
  PdfExportService._();

  // ── Public API ─────────────────────────────────────────────────────────────

  // A4 portrait is the only supported format — never allow landscape or other sizes.
  static const _kPageFormat = PdfPageFormat.a4;

  static Future<Uint8List> buildPdf(PrintConfigState config,
      {Map<String, String>? patientData}) async {
    final doc = pw.Document(
      title: 'Patient Medical Report',
      author: 'MediManage EMR',
    );
    final data = patientData ?? kMockPatientData;
    doc.addPage(
      pw.MultiPage(
        pageFormat: _kPageFormat,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
        header: (_) => _buildPageHeader(data),
        footer: (ctx) => _buildPageFooter(ctx, data),
        build: (ctx) => _buildContent(config, data),
      ),
    );
    return doc.save();
  }

  static Future<void> printReport(PrintConfigState config,
      {Map<String, String>? patientData}) async {
    // Pass _kPageFormat so the print dialog defaults to A4 portrait;
    // the onLayout callback ignores the system format and always renders A4.
    await Printing.layoutPdf(
      name: 'Patient Medical Report',
      format: _kPageFormat,
      onLayout: (_) => buildPdf(config, patientData: patientData),
    );
  }

  static Future<void> exportPdf(PrintConfigState config,
      {Map<String, String>? patientData}) async {
    final bytes = await buildPdf(config, patientData: patientData);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'patient_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ── Page Header (repeated on every page) ───────────────────────────────────

  static pw.Widget _buildPageHeader(Map<String, String> data) {
    final now = DateTime.now();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Hospital logo row
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Medical cross box
            pw.Container(
              width: 46,
              height: 46,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kBlack, width: 2),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                '+',
                style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: _kBlack),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MEDIMANAGE MEDICAL CENTER',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _kBlack),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'General Hospital & Healthcare Services',
                    style: const pw.TextStyle(fontSize: 9, color: _kSub),
                  ),
                ],
              ),
            ),
            // QR code placeholder
            pw.Container(
              width: 50,
              height: 50,
              decoration:
                  pw.BoxDecoration(border: pw.Border.all(color: _kBorder)),
              alignment: pw.Alignment.center,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('QR',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: _kSub)),
                  pw.SizedBox(height: 2),
                  pw.Text('Scan to Verify',
                      style: const pw.TextStyle(fontSize: 6, color: _kSub)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _kBorder, thickness: 0.5),
        pw.SizedBox(height: 4),
        // Address bar
        pw.Row(
          children: [
            pw.Text(
              '  123 Medical Drive, Healthcare City, HC 560001',
              style: const pw.TextStyle(fontSize: 8, color: _kSub),
            ),
            pw.SizedBox(width: 14),
            pw.Text('|  +1 (555) 000-1234',
                style: const pw.TextStyle(fontSize: 8, color: _kSub)),
            pw.SizedBox(width: 14),
            pw.Text('|  info@medimanage.com',
                style: const pw.TextStyle(fontSize: 8, color: _kSub)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _kBlack, thickness: 1.5),
        pw.SizedBox(height: 10),
        // Report title
        pw.Center(
          child: pw.Text(
            'PATIENT MEDICAL REPORT',
            style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _kBlack,
                letterSpacing: 1.5),
          ),
        ),
        pw.SizedBox(height: 5),
        // Date / time / report ID
        pw.Center(
          child: pw.Text(
            'Generated: ${_fmtDate(now)}    |    ${_fmtTime(now)}    |    Report ID: ${_reportId(now)}',
            style: const pw.TextStyle(fontSize: 8, color: _kSub),
          ),
        ),
        pw.SizedBox(height: 14),
      ],
    );
  }

  // ── Page Footer ────────────────────────────────────────────────────────────

  static pw.Widget _buildPageFooter(pw.Context ctx, Map<String, String> data) {
    return pw.Column(
      children: [
        pw.Divider(color: _kBorder, thickness: 0.5),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Doctor signature (left)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 16),
                  pw.Container(height: 0.5, width: 130, color: _kBlack),
                  pw.SizedBox(height: 4),
                  pw.Text('Dr. Harshal S. Chaudhari',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Consultant Neurosurgeon (Brain and Spine)',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                      'MBBS, MS Gen. Surg. (KEM Hospital, Mumbai)',
                      style: const pw.TextStyle(fontSize: 7, color: _kSub)),
                  pw.Text('MCh Neurosurgery (GMC, Goa)',
                      style: const pw.TextStyle(fontSize: 7, color: _kSub)),
                  pw.Text(
                      'Fellow in NeuroSurgical Oncology (Tata Memorial Hospital, Mumbai)',
                      style: const pw.TextStyle(fontSize: 7, color: _kSub)),
                  pw.SizedBox(height: 3),
                  pw.Text('MMC Reg. No: 2009031020',
                      style: pw.TextStyle(
                          fontSize: 7, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            // Circular hospital stamp (centre)
            pw.Container(
              width: 56,
              height: 56,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kBlack, width: 1.5),
                shape: pw.BoxShape.circle,
              ),
              alignment: pw.Alignment.center,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('+',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('MEDIMANAGE',
                      style: const pw.TextStyle(fontSize: 5, color: _kSub)),
                  pw.Text('MEDICAL',
                      style: const pw.TextStyle(fontSize: 5, color: _kSub)),
                ],
              ),
            ),
            // System generated disclaimer (right)
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 136,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _kBorder),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('[*]',
                          style: const pw.TextStyle(
                              fontSize: 10, color: _kSub)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'This is a system generated\nreport. No signature required.',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 7, color: _kSub),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Content sections ───────────────────────────────────────────────────────

  static List<pw.Widget> _buildContent(
      PrintConfigState config, Map<String, String> data) {
    final out = <pw.Widget>[];
    final inOrder = config.sectionOrder.toSet();

    // 1. Patient Summary
    if (inOrder.contains(kSectionBasicInfo)) {
      out.add(_buildPatientSummary(data));
      out.add(pw.SizedBox(height: 12));
    }

    // 2. Vitals
    if (inOrder.contains(kSectionVitals)) {
      final vitals = _collectVitals(config, data);
      if (vitals.isNotEmpty) {
        out.add(_buildVitals(vitals));
        out.add(pw.SizedBox(height: 12));
      }
    }

    // 3. Clinical Information / Prescription / Notes
    if (inOrder.contains(kSectionTreatment)) {
      // Clinical info fields (not meds, notes, advice)
      final clinicalFields = kAllPrintFields
          .where((f) =>
              f.sectionId == kSectionTreatment &&
              _kClinicalIds.contains(f.id) &&
              config.enabledFieldIds.contains(f.id) &&
              (data[f.id] ?? '').isNotEmpty)
          .toList();
      if (clinicalFields.isNotEmpty) {
        out.add(_buildClinicalInfo(clinicalFields, data));
        out.add(pw.SizedBox(height: 12));
      }

      // Prescription
      final meds = data['medications'] ?? '';
      if (meds.isNotEmpty && config.enabledFieldIds.contains('medications')) {
        out.add(_buildPrescription(meds));
        out.add(pw.SizedBox(height: 12));
      }

      // Doctor Notes + Follow Up
      final notes = config.enabledFieldIds.contains('notes')
          ? (data['notes'] ?? '')
          : '';
      final advice = config.enabledFieldIds.contains('advice')
          ? (data['advice'] ?? '')
          : '';
      if (notes.isNotEmpty || advice.isNotEmpty) {
        out.add(_buildNotesAndFollowUp(notes, advice));
        out.add(pw.SizedBox(height: 12));
      }
    }

    return out;
  }

  // ── Patient Summary ─────────────────────────────────────────────────────────

  static pw.Widget _buildPatientSummary(Map<String, String> data) {
    final fn = data['firstName'] ?? '';
    final ln = data['lastName'] ?? '';
    final fullName =
        [fn, ln].where((s) => s.isNotEmpty && s != '—').join(' ');
    final age = data['age'] ?? '';
    final gender = data['gender'] ?? '';
    final ageGender =
        [age, gender].where((s) => s.isNotEmpty && s != '—').join(' / ');

    return _borderedBox(
      header: pw.Row(children: [
        _iconBox('P'),
        pw.SizedBox(width: 6),
        pw.Text('PATIENT SUMMARY',
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _kBlack)),
      ]),
      child: pw.Table(
        border: pw.TableBorder(
          verticalInside:
              const pw.BorderSide(color: _kBorder, width: 0.5),
          top: const pw.BorderSide(color: _kBorder, width: 0.5),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(1.5),
          2: pw.FlexColumnWidth(1.5),
          3: pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _kGrey100),
            children: [
              _summaryLabel('Patient Name'),
              _summaryLabel('Age / Gender'),
              _summaryLabel('Phone'),
              _summaryLabel('Address'),
            ],
          ),
          pw.TableRow(children: [
            _summaryValue(fullName.isEmpty ? '—' : fullName),
            _summaryValue(ageGender.isEmpty ? '—' : ageGender),
            _summaryValue(data['phone'] ?? '—'),
            _summaryValue(data['address'] ?? '—'),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _summaryLabel(String t) => pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(12, 6, 12, 2),
        child: pw.Text(t,
            style: const pw.TextStyle(fontSize: 8, color: _kSub)),
      );

  static pw.Widget _summaryValue(String t) => pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _kBlack)),
      );

  // ── Vitals ─────────────────────────────────────────────────────────────────

  static List<Map<String, String>> _collectVitals(
      PrintConfigState config, Map<String, String> data) {
    final out = <Map<String, String>>[];
    if (config.enabledFieldIds.contains('weight') &&
        (data['weight'] ?? '').isNotEmpty) {
      out.add({'label': 'Weight', 'value': data['weight']!});
    }
    if (config.enabledFieldIds.contains('bloodPressure') &&
        (data['bloodPressure'] ?? '').isNotEmpty) {
      out.add({'label': 'Blood Pressure', 'value': data['bloodPressure']!});
    }
    if (config.enabledFieldIds.contains('temperature') &&
        (data['temperature'] ?? '').isNotEmpty) {
      out.add({'label': 'Temperature', 'value': data['temperature']!});
    }
    return out;
  }

  static pw.Widget _buildVitals(List<Map<String, String>> vitals) {
    final cw = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(84),
    };
    for (int i = 0; i < vitals.length; i++) {
      cw[i + 1] = const pw.FlexColumnWidth(1);
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _kBorder),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Table(
        columnWidths: cw,
        border: pw.TableBorder(
          verticalInside:
              const pw.BorderSide(color: _kBorder, width: 0.5),
        ),
        children: [
          pw.TableRow(children: [
            // Black left panel
            pw.Container(
              color: _kBlack,
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('(+)',
                      style: pw.TextStyle(
                          color: _kWhite,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('VITALS',
                      style: pw.TextStyle(
                          color: _kWhite,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('(Latest)',
                      style: const pw.TextStyle(
                          color: PdfColors.grey, fontSize: 7)),
                ],
              ),
            ),
            // Vital metric cells
            ...vitals.map(
              (v) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(v['label']!,
                        style: const pw.TextStyle(fontSize: 8, color: _kSub)),
                    pw.SizedBox(height: 4),
                    pw.Text(v['value']!,
                        style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: _kBlack)),
                  ],
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Clinical Information ───────────────────────────────────────────────────

  static pw.Widget _buildClinicalInfo(
      List<PrintField> fields, Map<String, String> data) {
    return _borderedBox(
      header: pw.Row(children: [
        _iconBox('='),
        pw.SizedBox(width: 6),
        pw.Text('CLINICAL INFORMATION',
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _kBlack)),
      ]),
      child: pw.Column(
        children: fields.asMap().entries.map((entry) {
          final isLast = entry.key == fields.length - 1;
          final f = entry.value;
          return pw.Column(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                      width: 14,
                      child: pw.Text('-',
                          style: const pw.TextStyle(
                              fontSize: 10, color: _kSub))),
                  pw.SizedBox(
                    width: 150,
                    child: pw.Text(f.label,
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _kBlack)),
                  ),
                  pw.Text(':  ',
                      style:
                          const pw.TextStyle(fontSize: 9, color: _kSub)),
                  pw.Expanded(
                    child: pw.Text(data[f.id] ?? '—',
                        style:
                            const pw.TextStyle(fontSize: 9, color: _kText)),
                  ),
                ],
              ),
            ),
            if (!isLast) pw.Divider(color: _kBorder, thickness: 0.5),
          ]);
        }).toList(),
      ),
    );
  }

  // ── Prescription / Medication ──────────────────────────────────────────────

  static pw.Widget _buildPrescription(String medications) {
    return _borderedBox(
      header: pw.Row(children: [
        pw.Text('Rx',
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _kBlack)),
        pw.SizedBox(width: 6),
        pw.Text('PRESCRIPTION / MEDICATION',
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _kBlack)),
      ]),
      child: pw.Table(
        border: pw.TableBorder.all(color: _kBorder, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.5),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1.2),
          3: pw.FlexColumnWidth(1),
          4: pw.FlexColumnWidth(1.5),
        },
        children: [
          // Black header row
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _kBlack),
            children: [
              _rxHeader('Medication'),
              _rxHeader('Dose'),
              _rxHeader('Frequency'),
              _rxHeader('Duration'),
              _rxHeader('Instructions'),
            ],
          ),
          // Data row
          pw.TableRow(children: [
            _rxCell(medications),
            _rxCell('—'),
            _rxCell('—'),
            _rxCell('—'),
            _rxCell('—'),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _rxHeader(String t) => pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _kWhite)),
      );

  static pw.Widget _rxCell(String t) => pw.Padding(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child:
            pw.Text(t, style: const pw.TextStyle(fontSize: 9, color: _kText)),
      );

  // ── Doctor Notes + Follow Up ───────────────────────────────────────────────

  static pw.Widget _buildNotesAndFollowUp(String notes, String advice) {
    final hasNotes = notes.isNotEmpty;
    final hasAdvice = advice.isNotEmpty;

    pw.Widget noteBox() => pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorder),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                _iconBox('N'),
                pw.SizedBox(width: 6),
                pw.Text('DOCTOR NOTES',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _kBlack)),
              ]),
              pw.SizedBox(height: 8),
              pw.Text('- $notes',
                  style: const pw.TextStyle(fontSize: 9, color: _kText)),
            ],
          ),
        );

    pw.Widget adviceBox() => pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _kBorder),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                _iconBox('F'),
                pw.SizedBox(width: 6),
                pw.Text('FOLLOW UP',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _kBlack)),
              ]),
              pw.SizedBox(height: 8),
              pw.Text(advice,
                  style: const pw.TextStyle(fontSize: 9, color: _kText)),
            ],
          ),
        );

    if (hasNotes && hasAdvice) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: noteBox()),
          pw.SizedBox(width: 10),
          pw.Expanded(child: adviceBox()),
        ],
      );
    } else if (hasNotes) {
      return noteBox();
    } else {
      return adviceBox();
    }
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  static pw.Widget _borderedBox(
      {required pw.Widget header, required pw.Widget child}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _kBorder),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: header,
          ),
          pw.Divider(color: _kBorder, thickness: 0.5),
          child,
        ],
      ),
    );
  }

  static pw.Widget _iconBox(String ch) => pw.Container(
        width: 16,
        height: 16,
        decoration: const pw.BoxDecoration(
          color: _kBlack,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
        ),
        alignment: pw.Alignment.center,
        child: pw.Text(ch,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _kWhite)),
      );

  static String _fmtDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${_pad(dt.day)} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _fmtTime(DateTime dt) =>
      '${_pad(dt.hour)}:${_pad(dt.minute)}';

  static String _reportId(DateTime dt) =>
      'RPT-${_pad(dt.day)}${_pad(dt.month)}${dt.year}-${_pad(dt.hour)}${_pad(dt.minute)}${_pad(dt.second)}';

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
