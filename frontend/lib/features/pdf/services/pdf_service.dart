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


// ============================================================================
// DOCTOR / CLINIC INFORMATION
// ============================================================================

class _DoctorInfo {
  static const String name =
      'Dr. Harshal S. Chaudhari';

  static const String title =
      'Brain and Spine surgeon/ Neurosurgeon';

  static const String degree1 =
      'M.B.B.S., M.S. General Surgery';

  static const String degree2 =
      '(K.E.M. Hospital, Mumbai)';

  static const String degree3 =
      'M.Ch. Neurosurgery (G.M.C., Goa)';

  static const String degree4 =
      'Fellow in Neurosurgical Oncology (Tata Memorial Hospital)';

  static const String website =
      'www.drharshalchaudhari.com';

  static const String phone =
      '+91 83900 24528';

  static const String clinicName =
      'The Brain & Spine Clinic';

  static const String tagline =
      'Excellence, Ethics, Efficiency';

  static String address =
      'C/0 Nashik Hematology Services- 6th Floor, '
      'S.K. Empire, Near Ved Mandir, Mico Circle, Nashik';

  static const List<String> specialisations = [
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


// ============================================================================
// COLOURS
// ============================================================================
//
// These correspond to the colours used in the reference letterhead.
// ============================================================================

class _C {
  // Header light blue
  static const PdfColor headerBlue =
      PdfColor.fromInt(0xFFD1EBFB);

  // Clinic title purple
  static const PdfColor clinicPurple =
      PdfColor.fromInt(0xFF994E89);

  // Doctor name blue
  static const PdfColor doctorBlue =
      PdfColor.fromInt(0xFF333980);

  // Tagline
  static const PdfColor taglineBlue =
      PdfColor.fromInt(0xFF40427A);

  // Normal text
  static const PdfColor text =
      PdfColor.fromInt(0xFF494949);

  // Dark text
  static const PdfColor darkText =
      PdfColor.fromInt(0xFF373737);

  // Sidebar text
  static const PdfColor sidebarText =
      PdfColor.fromInt(0xFF4B4C77);

  // Cream logo background
  static const PdfColor cream =
      PdfColor.fromInt(0xFFFEF0DD);

  // Light cyan logo ribbon
  static const PdfColor lightCyan =
      PdfColor.fromInt(0xFFE0F7FF);

  // Green divider
  static const PdfColor greenDivider =
      PdfColor.fromInt(0xFFD5DDAE);

  // Sidebar green border
  static const PdfColor sidebarGreen =
      PdfColor.fromInt(0xFFB1BE76);

  // Red accent
  static const PdfColor red =
      PdfColor.fromInt(0xFFE42024);

  // Grey line
  static const PdfColor greyLine =
      PdfColor.fromInt(0xFF9B9B9B);

  // Grey dots
  static const PdfColor greyDot =
      PdfColor.fromInt(0xFFCFCFCF);

  // Pattern background
  static const PdfColor pattern =
      PdfColor.fromInt(0xFFF3EFEB);

  // Outer border
  static const PdfColor outerBorder =
      PdfColor.fromInt(0xFFD8B8BB);

  static const PdfColor white =
      PdfColors.white;
}


// ============================================================================
// PDF SERVICE
// ============================================================================

class PdfService {

  // ==========================================================================
  // VISIT PDF
  // ==========================================================================

  static Future<Uint8List> buildVisitPdf({
    required PatientEntity patient,
    required VisitEntity visit,
    PrescriptionEntity? prescription,
    String? examinationText,
    String? radiologyText,
    String? clinicAddress,
  }) async {

    if (clinicAddress != null &&
        clinicAddress.trim().isNotEmpty) {
      _DoctorInfo.address =
          clinicAddress.trim();
    }

    final pdf = pw.Document();

    final logo = await _loadLogo();

    // ------------------------------------------------------------------------
    // Built-in fonts.
    //
    // If you have licensed copies of Agency FB / Cambria / Calibri,
    // they can be loaded here using pw.Font.ttf().
    //
    // Helvetica is used as the Android/PDF-safe fallback.
    // ------------------------------------------------------------------------

    final font =
        pw.Font.helvetica();

    final fontBold =
        pw.Font.helveticaBold();

    final fontItalic =
        pw.Font.helveticaOblique();

    pdf.addPage(
      pw.MultiPage(
        pageFormat:
            PdfPageFormat.a4,

        margin:
            const pw.EdgeInsets.fromLTRB(
          25,
          22,
          25,
          25,
        ),

        header: (_) {
          return _letterheadHeader(
            patient: patient,
            date: visit.visitDate,
            logo: logo,
            font: font,
            fontBold: fontBold,
            fontItalic: fontItalic,
          );
        },

        // IMPORTANT:
        // Old footer has intentionally been removed.
        footer: (_) {
          return pw.SizedBox();
        },

        build: (_) => [

          pw.SizedBox(height: 8),

          _buildVisitBody(
            visit: visit,
            prescription: prescription,
            examination: examinationText,
            radiology: radiologyText,
            font: font,
            fontBold: fontBold,
            fontItalic: fontItalic,
          ),
        ],
      ),
    );

    return pdf.save();
  }


  // ==========================================================================
  // SURGERY PDF
  // ==========================================================================

  static Future<Uint8List> buildSurgeryPdf({
    required PatientEntity patient,
    required SurgeryEntity surgery,
    String? clinicAddress,
  }) async {

    if (clinicAddress != null &&
        clinicAddress.trim().isNotEmpty) {
      _DoctorInfo.address =
          clinicAddress.trim();
    }

    final pdf = pw.Document();

    final logo = await _loadLogo();

    final font =
        pw.Font.helvetica();

    final fontBold =
        pw.Font.helveticaBold();

    final fontItalic =
        pw.Font.helveticaOblique();

    pdf.addPage(
      pw.MultiPage(
        pageFormat:
            PdfPageFormat.a4,

        margin:
            const pw.EdgeInsets.fromLTRB(
          25,
          22,
          25,
          25,
        ),

        header: (_) {
          return _letterheadHeader(
            patient: patient,
            date: surgery.surgeryDate,
            logo: logo,
            font: font,
            fontBold: fontBold,
            fontItalic: fontItalic,
          );
        },

        footer: (_) {
          return pw.SizedBox();
        },

        build: (_) => [

          pw.SizedBox(height: 8),

          _buildSurgeryBody(
            surgery: surgery,
            font: font,
            fontBold: fontBold,
            fontItalic: fontItalic,
          ),
        ],
      ),
    );

    return pdf.save();
  }


  // ==========================================================================
  // PRINT
  // ==========================================================================

  static Future<void> printPdf(
    Uint8List bytes,
  ) async {

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
    );
  }


  // ==========================================================================
  // SHARE
  // ==========================================================================

  static Future<void> sharePdf(
    Uint8List bytes,
    String filename,
  ) async {

    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }


  // ==========================================================================
  // LETTERHEAD HEADER
  // ==========================================================================

  static pw.Widget _letterheadHeader({
    required PatientEntity patient,
    required DateTime date,
    required pw.MemoryImage? logo,
    required pw.Font font,
    required pw.Font fontBold,
    required pw.Font fontItalic,
  }) {

    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.stretch,

      children: [

        // ================================================================
        // TOP HEADER
        // ================================================================

        pw.Container(
          height: 88,

          color: _C.headerBlue,

          child: pw.Stack(
            children: [

              // ----------------------------------------------------------
              // GREY DOT PATTERN
              // ----------------------------------------------------------

              pw.Positioned(
                left: 250,
                right: 0,
                top: 50,
                bottom: 0,

                child: _buildDotPattern(),
              ),


              // ----------------------------------------------------------
              // CLINIC NAME
              // ----------------------------------------------------------

              pw.Positioned(
                left: 78,
                top: 20,

                child: pw.Text(
                  _DoctorInfo.clinicName,

                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 20,
                    color: _C.clinicPurple,
                    letterSpacing: 0.5,
                  ),
                ),
              ),


              // ----------------------------------------------------------
              // DOCTOR NAME
              // ----------------------------------------------------------

              pw.Positioned(
                right: 28,
                top: 17,

                child: pw.Text(
                  _DoctorInfo.name,

                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 20,
                    color: _C.doctorBlue,
                  ),
                ),
              ),


              // ----------------------------------------------------------
              // TAGLINE
              // ----------------------------------------------------------

              pw.Positioned(
                left: 128,
                top: 51,

                child: pw.Text(
                  _DoctorInfo.tagline,

                  style: pw.TextStyle(
                    font: fontItalic,
                    fontSize: 11,
                    color: _C.taglineBlue,
                    letterSpacing: 0.4,
                  ),
                ),
              ),


              // ----------------------------------------------------------
              // DOCTOR DETAILS
              // ----------------------------------------------------------

              pw.Positioned(
                right: 28,
                top: 43,

                child: pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.end,

                  children: [

                    pw.Text(
                      _DoctorInfo.title,

                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8.5,
                        color: _C.text,
                      ),
                    ),

                    pw.Text(
                      _DoctorInfo.degree1,

                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: _C.text,
                      ),
                    ),

                    pw.Text(
                      _DoctorInfo.degree2,

                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: _C.text,
                      ),
                    ),

                    pw.Text(
                      _DoctorInfo.degree3,

                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: _C.text,
                      ),
                    ),

                    pw.Text(
                      _DoctorInfo.degree4,

                      style: pw.TextStyle(
                        font: font,
                        fontSize: 7.5,
                        color: _C.text,
                      ),
                    ),

                    pw.SizedBox(height: 1),

                    pw.Text(
                      _DoctorInfo.website,

                      style: pw.TextStyle(
                        font: font,
                        fontSize: 7.5,
                        color: _C.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),


        // ================================================================
        // LOGO
        // ================================================================

        pw.Container(
          height: 72,

          child: pw.Row(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,

            children: [

              // ----------------------------------------------------------
              // LOGO PANEL
              // ----------------------------------------------------------

              pw.Container(
                width: 115,
                height: 120,

                margin:
                    const pw.EdgeInsets.only(
                  left: 35,
                  top: -6,
                ),

                decoration:
                    const pw.BoxDecoration(
                  color: _C.cream,
                ),

                child: logo != null
                    ? pw.Padding(
                        padding:
                            const pw.EdgeInsets.all(
                          8,
                        ),

                        child: pw.Image(
                          logo,
                          fit: pw.BoxFit.contain,
                        ),
                      )
                    : pw.Center(
                        child: pw.Text(
                          'BSC',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 18,
                            color:
                                _C.doctorBlue,
                          ),
                        ),
                      ),
              ),


              // ----------------------------------------------------------
              // SPACE
              // ----------------------------------------------------------

              pw.SizedBox(width: 20),


              // ----------------------------------------------------------
              // EMPTY AREA
              // ----------------------------------------------------------

              pw.Expanded(
                child: pw.SizedBox(),
              ),
            ],
          ),
        ),


        // ================================================================
        // GREEN DIVIDER
        // ================================================================

        pw.Container(
          height: 1.2,
          color: _C.greenDivider,
        ),


        pw.SizedBox(height: 5),


        // ================================================================
        // PATIENT INFORMATION
        // ================================================================

        _patientInfo(
          patient: patient,
          date: date,
          font: font,
          fontBold: fontBold,
        ),

        pw.SizedBox(height: 7),
      ],
    );
  }


  // ==========================================================================
  // GREY DOT PATTERN
  // ==========================================================================

  static pw.Widget _buildDotPattern() {

    final dots = <pw.Widget>[];

    const double spacing = 10;

    for (int row = 0; row < 6; row++) {

      for (int col = 0; col < 20; col++) {

        dots.add(
          pw.Positioned(
            left: col * spacing,
            top: row * spacing,

            child: pw.Container(
              width: 1.3,
              height: 1.3,

              decoration:
                  const pw.BoxDecoration(
                color: _C.greyDot,
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
        );
      }
    }

    return pw.Stack(
      children: dots,
    );
  }


  // ==========================================================================
  // PATIENT NAME / DATE
  // ==========================================================================

  static pw.Widget _patientInfo({
    required PatientEntity patient,
    required DateTime date,
    required pw.Font font,
    required pw.Font fontBold,
  }) {

    return pw.Container(
      height: 31,

      child: pw.Row(
        crossAxisAlignment:
            pw.CrossAxisAlignment.center,

        children: [

          // --------------------------------------------------------------
          // PATIENT NAME
          // --------------------------------------------------------------

          pw.Text(
            'Patient Name :',

            style: pw.TextStyle(
              font: font,
              fontSize: 10.5,
              color: _C.darkText,
            ),
          ),

          pw.SizedBox(width: 5),

          pw.Expanded(
            flex: 6,

            child: pw.Container(
              height: 20,

              decoration:
                  const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: _C.greyLine,
                    width: 0.7,
                  ),
                ),
              ),

              padding:
                  const pw.EdgeInsets.only(
                bottom: 2,
              ),

              child: pw.Text(
                patient.fullName.isEmpty
                    ? ''
                    : patient.fullName,

                maxLines: 1,

                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: _C.darkText,
                ),
              ),
            ),
          ),


          pw.SizedBox(width: 25),


          // --------------------------------------------------------------
          // DATE
          // --------------------------------------------------------------

          pw.Text(
            'Date :',

            style: pw.TextStyle(
              font: font,
              fontSize: 10.5,
              color: _C.darkText,
            ),
          ),

          pw.SizedBox(width: 5),

          pw.Expanded(
            flex: 2,

            child: pw.Container(
              height: 20,

              decoration:
                  const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: _C.greyLine,
                    width: 0.7,
                  ),
                ),
              ),

              padding:
                  const pw.EdgeInsets.only(
                bottom: 2,
              ),

              child: pw.Text(
                DateFormat(
                  'dd/MM/yyyy',
                ).format(date),

                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: _C.darkText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ==========================================================================
  // VISIT BODY
  // ==========================================================================

  static pw.Widget _buildVisitBody({
    required VisitEntity visit,
    PrescriptionEntity? prescription,
    String? examination,
    String? radiology,
    required pw.Font font,
    required pw.Font fontBold,
    required pw.Font fontItalic,
  }) {

    final examText =
        examination ??
        visit.examination ??
        '';

    final rxText =
        _prescriptionText(
          prescription,
        );


    final investigations = <String>[];


    if (visit.clinicalImpression != null &&
        visit.clinicalImpression!
            .trim()
            .isNotEmpty) {

      investigations.add(
        'Impression: '
        '${visit.clinicalImpression!.trim()}',
      );
    }


    if (radiology != null &&
        radiology.trim().isNotEmpty) {

      investigations.add(
        'Imaging: ${radiology.trim()}',
      );
    }


    final content = pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.stretch,

      children: [

        _section(
          'CHIEF COMPLAINT',
          visit.complaints ?? '',
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'EXAMINATION FINDINGS',
          examText,
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'ADVICE',
          visit.plan ?? '',
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'TREATMENT (MEDICINES)',
          rxText,
          font,
          fontBold,
          bodyFont: fontItalic,
        ),


        _sectionDivider(),


        _section(
          'INVESTIGATIONS',
          investigations.join('\n'),
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'CROSS REFERENCE (OTHER DOCTOR CONSULTATION)',
          visit.notes ?? '',
          font,
          fontBold,
        ),
      ],
    );


    return _bodyWithSidebar(
      content: content,
      font: font,
      fontBold: fontBold,
    );
  }


  // ==========================================================================
  // SURGERY BODY
  // ==========================================================================

  static pw.Widget _buildSurgeryBody({
    required SurgeryEntity surgery,
    required pw.Font font,
    required pw.Font fontBold,
    required pw.Font fontItalic,
  }) {

    final team = <String>[];


    if (_has(surgery.primarySurgeon)) {
      team.add(
        'Primary: ${surgery.primarySurgeon}',
      );
    }


    if (_has(surgery.assistantSurgeons)) {
      team.add(
        'Assistants: '
        '${surgery.assistantSurgeons}',
      );
    }


    if (_has(surgery.anesthesiaType)) {
      team.add(
        'Anaesthesia: '
        '${surgery.anesthesiaType}',
      );
    }


    if (_has(surgery.anesthesiologist)) {
      team.add(
        'Anaesthesiologist: '
        '${surgery.anesthesiologist}',
      );
    }


    final content = pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.stretch,

      children: [

        _section(
          'PRE-OPERATIVE DIAGNOSIS',
          surgery.preOpDiagnosis ?? '',
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'PROCEDURE',
          surgery.procedure ?? '',
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'SURGICAL TEAM',
          team.join('\n'),
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'INTRAOPERATIVE FINDINGS',
          surgery.intraopFindings ?? '',
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'IMPLANTS / INSTRUMENTATION',
          surgery.implants ?? '',
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'OPERATIVE NOTES',
          surgery.otNotes ?? '',
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'COMPLICATIONS',
          surgery.complications ?? '',
          font,
          fontBold,
        ),


        _sectionDivider(),


        _section(
          'POST-OPERATIVE PLAN',
          surgery.postOpPlan ?? '',
          font,
          fontBold,
        ),
      ],
    );


    return _bodyWithSidebar(
      content: content,
      font: font,
      fontBold: fontBold,
    );
  }


  // ==========================================================================
  // BODY + LEFT SPECIALISATION SIDEBAR
  // ==========================================================================

  static pw.Widget _bodyWithSidebar({
    required pw.Widget content,
    required pw.Font font,
    required pw.Font fontBold,
  }) {

    return pw.Row(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,

      children: [

        // ==============================================================
        // LEFT SIDEBAR
        // ==============================================================

        pw.Container(
          width: 145,

          decoration:
              const pw.BoxDecoration(
            border: pw.Border(
              right: pw.BorderSide(
                color: _C.sidebarGreen,
                width: 1,
              ),
            ),
          ),

          child: pw.Stack(
            children: [

              // --------------------------------------------------------
              // RED VERTICAL BAR
              // --------------------------------------------------------

              pw.Positioned(
                left: 6,
                top: 72,

                child: pw.Container(
                  width: 8,
                  height: 220,

                  color: _C.red,
                ),
              ),


              // --------------------------------------------------------
              // SPECIALISATIONS
              // --------------------------------------------------------

              pw.Padding(
                padding:
                    const pw.EdgeInsets.only(
                  left: 28,
                  right: 8,
                ),

                child: pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,

                  children: [

                    pw.SizedBox(height: 5),

                    pw.Text(
                      'SPECIALISATIONS',

                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8.5,
                        color: _C.sidebarText,
                        letterSpacing: 0.5,
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    ..._DoctorInfo
                        .specialisations
                        .map(
                      (item) {

                        return pw.Container(
                          width: double.infinity,

                          padding:
                              const pw.EdgeInsets
                                  .only(
                            top: 5,
                            bottom: 5,
                          ),

                          decoration:
                              const pw.BoxDecoration(
                            border: pw.Border(
                              bottom:
                                  pw.BorderSide(
                                color:
                                    _C.greenDivider,
                                width: 0.5,
                              ),
                            ),
                          ),

                          child: pw.Text(
                            item,

                            style: pw.TextStyle(
                              font: font,
                              fontSize: 8.2,
                              color:
                                  _C.sidebarText,
                              lineSpacing: 1.2,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),


        // ==============================================================
        // MAIN CONTENT
        // ==============================================================

        pw.SizedBox(width: 15),

        pw.Expanded(
          child: content,
        ),
      ],
    );
  }


  // ==========================================================================
  // SECTION
  // ==========================================================================

  static pw.Widget _section(
    String title,
    String content,
    pw.Font font,
    pw.Font fontBold, {
    pw.Font? bodyFont,
  }) {

    if (content.trim().isEmpty) {
      return pw.SizedBox();
    }


    return pw.Container(
      padding:
          const pw.EdgeInsets.only(
        top: 4,
        bottom: 7,
      ),

      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.stretch,

        children: [

          // --------------------------------------------------------------
          // TITLE
          // --------------------------------------------------------------

          pw.Text(
            title,

            style: pw.TextStyle(
              font: fontBold,
              fontSize: 8.2,
              color: _C.doctorBlue,
              letterSpacing: 0.3,
            ),
          ),


          pw.SizedBox(height: 4),


          // --------------------------------------------------------------
          // CONTENT
          // --------------------------------------------------------------

          pw.Text(
            content.trim(),

            style: pw.TextStyle(
              font: bodyFont ?? font,
              fontSize: 9.5,
              color: _C.text,
              lineSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }


  // ==========================================================================
  // SECTION DIVIDER
  // ==========================================================================

  static pw.Widget _sectionDivider() {

    return pw.Container(
      height: 0.7,
      color: _C.greenDivider,
    );
  }


  // ==========================================================================
  // PRESCRIPTION TEXT
  // ==========================================================================

  static String _prescriptionText(
    PrescriptionEntity? rx,
  ) {

    if (rx == null) {
      return '';
    }


    final parts = <String>[];


    if (rx.text != null &&
        rx.text!.trim().isNotEmpty) {

      parts.add(
        rx.text!.trim(),
      );
    }


    for (
      var i = 0;
      i < rx.drugs.length;
      i++
    ) {

      final d = rx.drugs[i];


      var line =
          '${i + 1}. ${d.displayName}';


      if (d.displayDosage
          .trim()
          .isNotEmpty) {

        line +=
            '  –  ${d.displayDosage}';
      }


      parts.add(line);
    }


    return parts.join('\n');
  }


  // ==========================================================================
  // HAS TEXT
  // ==========================================================================

  static bool _has(String? value) {

    return value != null &&
        value.trim().isNotEmpty;
  }


  // ==========================================================================
  // LOAD LOGO
  // ==========================================================================

  static Future<pw.MemoryImage?> _loadLogo() async {

    try {

      final data = await rootBundle.load(
        'assets/images/app_logo.png',
      );


      final bytes =
          data.buffer.asUint8List();


      return pw.MemoryImage(bytes);

    } catch (_) {

      return null;
    }
  }
}