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
const _kSidebarText  = PdfColor.fromInt(0xFF00ACC1); // sidebar list teal #00ACC1
const _kSidebarDiv   = PdfColor.fromInt(0xFF4DD0E1); // sidebar divider teal #4DD0E1
const _kLabel        = PdfColor.fromInt(0xFF373737); // patient labels #373737
const _kText         = PdfColor.fromInt(0xFF494949); // credentials  #494949
const _kBannerBg     = PdfColor.fromInt(0xFFD1EBFB); // header bg    #D1EBFB
const _kSectionBg    = PdfColor.fromInt(0xFFD1EBFB); // section bars #D1EBFB
const _kLeftBg       = PdfColor.fromInt(0xFFFEF0DD); // cream panel  #FEF0DD
const _kRedBar       = PdfColor.fromInt(0xFFE42024); // red accent   #E42024
const _kWhite        = PdfColors.white;
const _kSub          = PdfColor.fromInt(0xFF494949);
const _kBorder       = PdfColor.fromInt(0xFF888888);
const _kGrey         = PdfColor.fromInt(0xFF9B9B9B); // underlines
const _kDot          = PdfColor.fromInt(0xFFCFCFCF); // dot pattern

// Dot pattern widget — circles only
pw.Widget _buildDots() {
  final children = <pw.Widget>[];
  const sp = 10.0;
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 32; c++) {
      children.add(pw.Positioned(
        left: c * sp, top: r * sp,
        child: pw.Container(
          width: 1.4, height: 1.4,
          decoration: const pw.BoxDecoration(color: _kDot, shape: pw.BoxShape.circle),
        ),
      ));
    }
  }
  return pw.Stack(children: children);
}
const _kMaroon       = PdfColor.fromInt(0xFF994E89); // kept for compat
const _kPageBorder   = PdfColor.fromInt(0xFFD4AAAA); // light red page border

// ── Font cache (downloaded once, reused across PDF generations) ───────────────
pw.Font? _cachedFontRegular;
pw.Font? _cachedFontMedium;
pw.Font? _cachedFontItalic;
pw.MemoryImage? _cachedBgImage;

Future<(pw.Font, pw.Font, pw.Font)> _loadFonts() async {
  _cachedFontRegular ??= await PdfGoogleFonts.interRegular();
  _cachedFontMedium  ??= await PdfGoogleFonts.interMedium();
  _cachedFontItalic  ??= await PdfGoogleFonts.interItalic();
  return (_cachedFontRegular!, _cachedFontMedium!, _cachedFontItalic!);
}

// ── Main PDF assembly ─────────────────────────────────────────────────────────
//
// Primary path: rasterise opd_paper.pdf as background, overlay dynamic text
// at calibrated coordinates. Falls back to manual letterhead if asset missing.

Future<Uint8List> _assemblePdf(
  Set<String> enabledIds,
  Map<String, String> data,
  Uint8List? logoBytes,
) async {
  try {
    if (_cachedBgImage == null) {
      final assetData     = await rootBundle.load('assets/templates/opd_paper.pdf');
      final templateBytes = assetData.buffer.asUint8List();
      final raster        = await Printing.raster(templateBytes, pages: [0], dpi: 150).first;
      final bgBytes       = await raster.toPng();
      _cachedBgImage      = pw.MemoryImage(bgBytes);
    }
    return _buildTemplatePdf(enabledIds, data, _cachedBgImage!);
  } catch (_) {}
  return _buildManualPdf(enabledIds, data, logoBytes);
}

// ── Template-based PDF (opd_paper.pdf background + overlaid dynamic text) ────

Future<Uint8List> _buildTemplatePdf(
  Set<String> enabledIds,
  Map<String, String> data,
  pw.MemoryImage bgImage,
) async {
  final (font, fontBold, fontItal) = await _loadFonts();

  final fn   = data['firstName'] ?? '';
  final ln   = data['lastName'] ?? '';
  final name = [fn, ln].where((s) => s.isNotEmpty && s != '—').join(' ');
  final date = data['date'] ?? DateFormat('dd-MM-yyyy').format(DateTime.now());

  // OPD paper original dimensions
  const kOpdW = 288.0;
  const kOpdH = 432.0;

  // Scale to A4 — everything scales proportionally, layout stays identical
  final kPageW = PdfPageFormat.a4.width;    // 595.28 pt
  final kPageH = PdfPageFormat.a4.height;   // 841.89 pt
  final sx     = kPageW / kOpdW;            // ≈ 2.066  (horizontal scale)
  final sy     = kPageH / kOpdH;            // ≈ 1.949  (vertical scale)

  // Calibrated overlay coordinates — scaled from OPD originals
  final kNameX = 113.5 * sx;
  final kNameY = 76.2  * sy;
  final kNameW = 106.0 * sx;
  final kDateX = 225.0 * sx;
  final kDateW = 63.0  * sx;

  // Body area — sidebar stays visible, all positions scaled
  final kBodyL = 64.0  * sx;
  final kBodyT = 87.0  * sy;
  final kBodyW = 218.0 * sx;
  final kFootH = 24.0  * sy;

  // Content font scale independent of page scale — 1.5 → 11pt body text on A4
  const kFontScale = 1.5;
  final sections = _buildSectionsTemplate(enabledIds, data, font, fontBold, fontItal, scale: kFontScale);

  final doc = pw.Document(title: 'Patient Medical Report', author: _Clinic.doctor);

  final marginRight = kPageW - kBodyL - kBodyW;

  // Signature footer — rendered once at the bottom of the last page
  final signatureFooter = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: 4 * sy),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 60 * sx, height: 0.5, color: _kNavy),
          pw.SizedBox(height: 2 * sy),
          pw.Text("Doctor's Signature",
              style: pw.TextStyle(font: fontBold, fontSize: 5.5 * sx, color: _kLabel)),
        ],
      ),
    ],
  );

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat(kPageW, kPageH),
        margin: pw.EdgeInsets.only(
          left: kBodyL,
          top: kBodyT,
          right: marginRight,
          bottom: kFootH,
        ),
        // Template background only — name/date shown in Patient Information table
        buildBackground: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Image(bgImage, fit: pw.BoxFit.fill),
        ),
      ),
      // Signature footer only on the last page
      footer: (context) => context.pageNumber == context.pagesCount
          ? signatureFooter
          : pw.SizedBox(),
      build: (context) => sections,
    ),
  );

  return doc.save();
}

// ── Manual letterhead fallback (used when template asset is unavailable) ──────

Future<Uint8List> _buildManualPdf(
  Set<String> enabledIds,
  Map<String, String> data,
  Uint8List? logoBytes,
) async {
  final logo     = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
  final doc      = pw.Document(title: 'Patient Medical Report', author: _Clinic.doctor);
  final font     = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();
  final fontItal = pw.Font.helveticaOblique();

  // Using built-in PDF fonts — no internet required
  final clinicFont  = pw.Font.helveticaBold();
  final doctorFont  = pw.Font.timesBold();
  final taglineFont = pw.Font.timesItalic();

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
            _buildHeader(font, fontBold, fontItal, logo, clinicFont, doctorFont, taglineFont),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(font, fontBold),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
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

// Header layout (top → bottom):
//   1. Full-width blue strip (155pt)
//      TOP 52pt  — pure blue: clinic name (Oswald) left, doctor name (Lora Bold) right
//      LOWER 103pt — cream logo panel (left, 118pt), tagline (centre), credentials (right)
//   2. Cream pointed-bottom triangle (118×18pt)
pw.Widget _buildHeader(
  pw.Font font,
  pw.Font fontBold,
  pw.Font fontItal,
  pw.MemoryImage? logo,
  pw.Font clinicFont,
  pw.Font doctorFont,
  pw.Font taglineFont,
) {
  const double logoW    = 121.5;
  const double nameRowH = 52.0;
  const double blueH    = 155.0;
  const double triH     = 18.0;
  const double credW    = 268.0; // wide enough for "Dr. Harshal S. Chaudhari" on one line

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // ── HEADER BACKGROUND: rounded top + angled bottom-right notch ──────────
      pw.SizedBox(
        height: blueH,
        child: pw.Stack(
          children: [
            // HTML-inspired shape covers ONLY the name row (clinic + doctor names)
            pw.Positioned(
              top: 0, left: 0, right: 0, bottom: blueH - nameRowH,
              child: pw.CustomPaint(
                painter: (PdfGraphics g, PdfPoint sz) {
                  final W = sz.x;
                  final H = sz.y;
                  const r = 20.0;       // top corner radius
                  const k = r * 0.5523; // Bezier quarter-circle control offset
                  // notch dimensions scaled from HTML (35px / 120px, 45% width, 8% offset)
                  final notchH  = H * 35.0 / 120.0;
                  final notchLB = W * 0.55;   // notch bottom-left x (55% from left)
                  final notchLT = W * 0.586;  // notch top-left x (58.6% = 55% + 8%×45%)
                  g
                    ..setFillColor(_kBannerBg)
                    ..moveTo(0, 0)           // bottom-left
                    ..lineTo(notchLB, 0)     // bottom edge → notch start
                    ..lineTo(notchLT, notchH)// diagonal cut upward
                    ..lineTo(W, notchH)      // right along notch top
                    ..lineTo(W, H)           // up right edge to top-right (no rounding)
                    ..lineTo(0, H)           // left along top to top-left (no rounding)
                    ..closePath()            // back to (0, 0)
                    ..fillPath();
                },
              ),
            ),
            // Dot pattern — right side of name row only
            pw.Positioned(
              top: 4, left: 200, right: 0, bottom: blueH - nameRowH + 4,
              child: _buildDots(),
            ),
            // Logo panel — no background, logo fills full width to the green border line
            pw.Positioned(
              top: nameRowH, left: 0, bottom: 0,
              child: pw.Container(
                width: logoW,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    right: pw.BorderSide(color: _kSidebarBrd, width: 1.5),
                  ),
                ),
                padding: pw.EdgeInsets.zero,
                child: logo != null
                    ? pw.Image(logo, fit: pw.BoxFit.contain,
                        alignment: pw.Alignment.center)
                    : pw.Center(
                        child: pw.Text('BSC',
                            style: pw.TextStyle(
                                font: fontBold, fontSize: 18, color: _kNavy))),
              ),
            ),
            // Top name row — Row layout: logo gap | clinic Expanded | doctor fixed width
            // Using Row prevents any overlap between the two names
            pw.Positioned(
              top: 0, left: 0, right: 0,
              child: pw.SizedBox(
                height: nameRowH,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(width: 12), // left margin for clinic name
                    pw.Expanded(
                      child: pw.Text(
                        _Clinic.name,
                        style: pw.TextStyle(
                            font: clinicFont, fontSize: 20,
                            color: _kClinicPurple, letterSpacing: 0.4),
                      ),
                    ),
                    pw.SizedBox(
                      width: 245,
                      child: pw.Text(
                        _Clinic.doctor,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            font: doctorFont, fontSize: 20, color: _kNavy),
                      ),
                    ),
                    pw.SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            // Tagline — lower section, right of logo panel
            pw.Positioned(
              top: nameRowH + 14, left: logoW + 16,
              child: pw.Text(
                _Clinic.tagline,
                style: pw.TextStyle(
                    font: taglineFont, fontSize: 11.5,
                    color: _kTagline, letterSpacing: 0.2),
              ),
            ),
            // Credentials — lower section, shifted left from right edge
            pw.Positioned(
              top: nameRowH + 4, right: 20,
              child: pw.SizedBox(
                width: credW,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _hCred(_Clinic.designation, font, 10.5),
                    _hCred(_Clinic.degree1,     font, 10.0),
                    _hCred(_Clinic.degree1b,    font, 10.0),
                    _hCred(_Clinic.degree2,     font, 10.0),
                    _hCred(_Clinic.degree3,     font, 9.5),
                    pw.SizedBox(height: 2),
                    _pdfGlobeRow(_Clinic.website, font, 9.5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // ── CREAM POINTED TRIANGLE ─────────────────────────────────────────────
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.CustomPaint(
            size: const PdfPoint(logoW, triH),
            painter: (PdfGraphics g, PdfPoint sz) {
              g
                ..setFillColor(_kLeftBg)
                ..moveTo(0, sz.y)
                ..lineTo(sz.x, sz.y)
                ..lineTo(sz.x / 2, 0)
                ..closePath()
                ..fillPath();
            },
          ),
          pw.Expanded(child: pw.SizedBox()),
        ],
      ),
    ],
  );
}

// Credential line helper
pw.Widget _hCred(String text, pw.Font font, double size) => pw.Text(
  text,
  textAlign: pw.TextAlign.right,
  style: pw.TextStyle(font: font, fontSize: size, color: _kText),
);

// Draws a globe icon (circle + vertical + horizontal meridians) in navy.
pw.Widget _pdfGlobeRow(String text, pw.Font font, double fontSize) {
  const iconSize = 10.0;
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.SizedBox(
        width: iconSize,
        height: iconSize,
        child: pw.CustomPaint(
          size: const PdfPoint(iconSize, iconSize),
          painter: (PdfGraphics g, PdfPoint sz) {
            final cx = sz.x / 2;
            final cy = sz.y / 2;
            final r  = sz.x / 2 - 0.5;
            g.setStrokeColor(_kNavy);
            g.setLineWidth(0.7);
            // Outer circle
            g.drawEllipse(cx, cy, r, r);
            g.strokePath();
            // Vertical meridian
            g.moveTo(cx, cy - r);
            g.lineTo(cx, cy + r);
            g.strokePath();
            // Equator
            g.moveTo(cx - r, cy);
            g.lineTo(cx + r, cy);
            g.strokePath();
            // Inner horizontal oval (latitude arc)
            g.drawEllipse(cx, cy, r * 0.55, r * 0.3);
            g.strokePath();
          },
        ),
      ),
      pw.SizedBox(width: 3),
      pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: fontSize, color: _kText),
      ),
    ],
  );
}

// ── Left sidebar: specialisations list + red bar (items 1-7 only) ────────────
//
// Per-item: padding top=10, bottom=9, text≈8pt, divider=0.8pt → ≈27.8pt
// Item 0 (Brain and Spine Injury): top 0–27.8pt  → NO red bar
// Red bar starts at top of item 1: 27.8pt ≈ 28pt
// Items 1-7 = 7 items × 27.8pt = 194.6pt ≈ 195pt

// Sidebar dot pattern (smaller grid to fit 121.5pt width)
pw.Widget _buildSidebarDots() {
  final children = <pw.Widget>[];
  const sp = 8.0;
  for (int r = 0; r < 100; r++) {
    for (int c = 0; c < 15; c++) {
      children.add(pw.Positioned(
        left: c * sp, top: r * sp,
        child: pw.Container(
          width: 1.2, height: 1.2,
          decoration: const pw.BoxDecoration(
              color: _kDot, shape: pw.BoxShape.circle),
        ),
      ));
    }
  }
  return pw.Stack(children: children);
}

pw.Widget _buildSidebar(pw.Font font, pw.Font fontBold) {
  return pw.Container(
    width: 121.5,
    decoration: const pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border(
        right: pw.BorderSide(color: _kSidebarBrd, width: 1.5),
      ),
    ),
    child: pw.Stack(
      children: [
        // Subtle dot pattern background
        pw.Positioned.fill(child: _buildSidebarDots()),
        // Red vertical bar — items 1–7 (Vascular Neurosurgery → Slip disc)
        pw.Positioned(
          left: 4, top: 35,
          child: pw.Container(width: 3, height: 245, color: _kRedBar),
        ),
        // Specialisations list
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 14, right: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ..._Clinic.specialisations.map(
                (s) => pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.fromLTRB(0, 12, 0, 11),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: _kGreenDiv, width: 0.8),
                    ),
                  ),
                  child: pw.Text(
                    s,
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 8.0, color: _kNavy),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
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

  const underline = pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _kGrey, width: 0.7)),
  );
  final lbl = pw.TextStyle(font: fontBold, fontSize: 10, color: _kLabel);
  final val = pw.TextStyle(font: font,     fontSize: 10, color: _kText);

  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('Patient Name :', style: lbl),
        pw.SizedBox(width: 6),
        pw.Expanded(
          flex: 5,
          child: pw.Text(name, style: val),
        ),
        pw.SizedBox(width: 24),
        pw.Text('Date :', style: lbl),
        pw.SizedBox(width: 6),
        pw.Expanded(
          flex: 2,
          child: pw.Text(date, style: val),
        ),
      ],
    ),
  );
}

// ── Compact sections layout for template background (218 pt body width) ──────
//
// Uses 8 pt body / 7.5 pt heading, 65 pt label width, start-aligned rows so
// multi-line values line up with the first line of their label. Vitals are
// rendered as an inline trio with abbreviated labels so they fit on one line.

List<pw.Widget> _buildSectionsTemplate(
  Set<String> enabled,
  Map<String, String> data,
  pw.Font font,
  pw.Font fontBold,
  pw.Font fontItal, {
  double scale = 1.0,
}) {
  final double fs     = 7.5  * scale;   // body text
  final double fsh    = 8.0  * scale;   // section heading — bigger & darker
  final double lw     = 62.0 * scale;   // label column width
  final double hp     = 5.0  * scale;   // horizontal padding inside section
  final double rowGap = 3.5  * scale;   // space between consecutive field rows
  const kC          = PdfColor.fromInt(0xFF101A3A); // values
  const kHeading    = PdfColor.fromInt(0xFF000000); // section heading — black
  const kLabelColor = PdfColor.fromInt(0xFF101A3A); // same dark navy as values — bold weight provides distinction
  const kAccent     = PdfColor.fromInt(0xFF3B82F6); // blue left-border accent
  const kDivider    = PdfColor.fromInt(0xFF999999); // section divider
  const kVitalBdr   = PdfColor.fromInt(0xFF3B82F6); // vital box border (blue, no fill)

  String dv(String k) => enabled.contains(k) ? (data[k]?.trim() ?? '') : '';

  // ── single field row ──────────────────────────────────────────────────────
  // RichText with justify: label+value inline, all lines (incl. continuation)
  // stretch to fill the full available width — no blank right-side gaps.
  pw.Widget fr(String label, String value) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: rowGap),
    child: label.isEmpty
        ? pw.Text(value,
            textAlign: pw.TextAlign.justify,
            style: pw.TextStyle(font: font, fontSize: fs, color: kC))
        : pw.RichText(
            textAlign: pw.TextAlign.justify,
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: '$label : ',
                  style: pw.TextStyle(font: fontBold, fontSize: fs, color: kLabelColor),
                ),
                pw.TextSpan(
                  text: value,
                  style: pw.TextStyle(font: font, fontSize: fs, color: kC),
                ),
              ],
            ),
          ),
  );

  // ── section block — bold header + content below ──────────────────────────
  pw.Widget sec(String title, List<pw.Widget> items) => pw.Inseparable(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.fromLTRB(hp, 3 * scale, hp, 2 * scale),
          child: pw.Text(title,
              style: pw.TextStyle(font: fontBold, fontSize: fsh, color: kHeading, letterSpacing: 0.3)),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.fromLTRB(hp + 3, 2 * scale, hp, 2 * scale),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: items),
        ),
        pw.SizedBox(height: 2 * scale),
        pw.Container(height: 0.5, color: kDivider),
        pw.SizedBox(height: 2 * scale),
      ],
    ),
  );

  // ── inline section — header + value on the same line ─────────────────────
  pw.Widget secInline(String title, String value) => pw.Inseparable(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.fromLTRB(hp, 3 * scale, hp, 2 * scale),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(
                text: '$title : ',
                style: pw.TextStyle(font: fontBold, fontSize: fsh, color: kHeading, letterSpacing: 0.3),
              ),
              pw.TextSpan(
                text: value,
                style: pw.TextStyle(font: font, fontSize: fs, color: kC),
              ),
            ]),
          ),
        ),
        pw.SizedBox(height: 2 * scale),
        pw.Container(height: 0.5, color: kDivider),
        pw.SizedBox(height: 5 * scale),
      ],
    ),
  );

  final sections = <pw.Widget>[];

  // PATIENT INFORMATION TABLE
  {
    String raw(String k) => (data[k]?.trim() ?? '').replaceAll('—', '').trim();
    final fn      = raw('firstName');
    final ln      = raw('lastName');
    final name    = [fn, ln].where((s) => s.isNotEmpty).join(' ');
    final dateVal = raw('date');
    final phone   = raw('phone');
    final email   = raw('email');
    final age     = raw('age');
    final gender  = raw('gender');
    final address = raw('address');

    final rows = <(String, String)>[];
    if (name.isNotEmpty)    rows.add(('Patient Name', name));
    if (dateVal.isNotEmpty) rows.add(('Date',         dateVal));
    if (phone.isNotEmpty)   rows.add(('Phone',        phone));
    if (email.isNotEmpty)   rows.add(('Email',        email));
    if (age.isNotEmpty)     rows.add(('Age',          age));
    if (gender.isNotEmpty)  rows.add(('Gender',       gender));
    if (address.isNotEmpty) rows.add(('Address',      address));

    if (rows.isNotEmpty) {
      // Separate address (full-width row) from the rest (2-column pairs)
      final mainRows   = rows.where((r) => r.$1 != 'Address').toList();
      final addressRow = rows.where((r) => r.$1 == 'Address').firstOrNull;

      final pad      = pw.EdgeInsets.fromLTRB(4, 2.5 * scale, 4, 2.5 * scale);
      final lblStyle = pw.TextStyle(font: fontBold, fontSize: fs * 0.9, color: kLabelColor);
      final valStyle = pw.TextStyle(font: font,     fontSize: fs,        color: kC);
      const side     = pw.BorderSide(color: kDivider, width: 0.5);

      final tableWidgets = <pw.Widget>[];

      if (mainRows.isNotEmpty) {
        final tableRows = <pw.TableRow>[];
        for (int i = 0; i < mainRows.length; i += 2) {
          final left  = mainRows[i];
          final right = i + 1 < mainRows.length ? mainRows[i + 1] : null;
          tableRows.add(pw.TableRow(children: [
            pw.Padding(padding: pad, child: pw.Text(left.$1,         style: lblStyle)),
            pw.Padding(padding: pad, child: pw.Text(left.$2,         style: valStyle)),
            pw.Padding(padding: pad, child: pw.Text(right?.$1 ?? '', style: lblStyle)),
            pw.Padding(padding: pad, child: pw.Text(right?.$2 ?? '', style: valStyle)),
          ]));
        }
        // If address follows, omit bottom border so tables join seamlessly
        final mainBorder = addressRow != null
            ? pw.TableBorder(top: side, left: side, right: side, bottom: pw.BorderSide.none,
                             horizontalInside: side, verticalInside: side)
            : pw.TableBorder.all(color: kDivider, width: 0.5);
        tableWidgets.add(pw.Table(
          border: mainBorder,
          columnWidths: {
            0: pw.FixedColumnWidth(48 * scale),
            1: pw.FlexColumnWidth(2),
            2: pw.FixedColumnWidth(48 * scale),
            3: pw.FlexColumnWidth(2),
          },
          children: tableRows,
        ));
      }

      // Address row: 2-column so value spans full remaining width
      if (addressRow != null) {
        // Draw the missing border between main table (bottom:none) and address table (top:none)
        if (mainRows.isNotEmpty) {
          tableWidgets.add(pw.Container(height: 0.5, color: kDivider));
        }
        final addrBorder = mainRows.isNotEmpty
            ? pw.TableBorder(top: pw.BorderSide.none, left: side, right: side,
                             bottom: side, horizontalInside: side, verticalInside: side)
            : pw.TableBorder.all(color: kDivider, width: 0.5);
        tableWidgets.add(pw.Table(
          border: addrBorder,
          columnWidths: {
            0: pw.FixedColumnWidth(48 * scale),
            1: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(children: [
              pw.Padding(padding: pad, child: pw.Text('Address', style: lblStyle)),
              pw.Padding(padding: pad, child: pw.Text(addressRow.$2, style: valStyle)),
            ]),
          ],
        ));
      }

      sections.add(sec('PATIENT INFORMATION', [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: tableWidgets,
        ),
      ]));
    }
  }

  // 1. KNOWN ALLERGIES
  if (dv('allergies').isNotEmpty)
    sections.add(secInline('KNOWN ALLERGIES', dv('allergies')));

  // 2. CHIEF COMPLAINT
  if (dv('chiefComplaint').isNotEmpty)
    sections.add(secInline('CHIEF COMPLAINT', dv('chiefComplaint')));

  // 3. PREVIOUS HISTORY
  if (dv('previousHistory').isNotEmpty)
    sections.add(secInline('PREVIOUS HISTORY', dv('previousHistory')));

  // 4. EXAMINATION FINDING — a. Vitals  b. General Examination  c. Neurological Examination
  {
    final hasW  = dv('weight').isNotEmpty;
    final hasBP = dv('bloodPressure').isNotEmpty;
    final hasT  = dv('temperature').isNotEmpty;
    final items = <pw.Widget>[
      // a. Vitals — Weight : val   BP : val   Temp : val  (all inline on one row)
      if (hasW || hasBP || hasT) pw.Padding(
        padding: pw.EdgeInsets.only(bottom: rowGap),
        child: pw.Row(
          children: [
            if (hasW) ...[
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Weight : ', style: pw.TextStyle(font: fontBold, fontSize: fs, color: kLabelColor)),
                pw.TextSpan(text: dv('weight'),   style: pw.TextStyle(font: font,     fontSize: fs, color: kC)),
              ])),
              if (hasBP || hasT) pw.SizedBox(width: 12),
            ],
            if (hasBP) ...[
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'BP : ',              style: pw.TextStyle(font: fontBold, fontSize: fs, color: kLabelColor)),
                pw.TextSpan(text: dv('bloodPressure'),  style: pw.TextStyle(font: font,     fontSize: fs, color: kC)),
              ])),
              if (hasT) pw.SizedBox(width: 12),
            ],
            if (hasT) pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Temp : ',      style: pw.TextStyle(font: fontBold, fontSize: fs, color: kLabelColor)),
              pw.TextSpan(text: dv('temperature'), style: pw.TextStyle(font: font,  fontSize: fs, color: kC)),
            ])),
          ],
        ),
      ),
      // b. General Examination
      if (dv('examGeneral').isNotEmpty)      fr('General Examination',      dv('examGeneral')),
      // c. Neurological Examination
      if (dv('examNeurological').isNotEmpty) fr('Neurological Examination', dv('examNeurological')),
    ];
    if (items.isNotEmpty) sections.add(sec('EXAMINATION FINDING', items));
  }

  // 5. PREVIOUS INVESTIGATIONS — a. Imaging  b. Other Investigations
  {
    final items = <pw.Widget>[
      if (dv('imaging').isNotEmpty)            fr('Imaging',              dv('imaging')),
      if (dv('otherInvestigation').isNotEmpty) fr('Other Investigations', dv('otherInvestigation')),
    ];
    if (items.isNotEmpty) sections.add(sec('PREVIOUS INVESTIGATIONS', items));
  }

  // 6. IMPRESSION
  {
    final diag = dv('clinicalDiagnosis');
    final impr = dv('diagnosis');
    if (diag.isNotEmpty || impr.isNotEmpty) {
      final combined = [diag, impr].where((s) => s.isNotEmpty).join(' / ');
      sections.add(secInline('IMPRESSION', combined));
    }
  }

  // 7. TREATMENT PLAN
  if (dv('treatmentPlan').isNotEmpty)
    sections.add(secInline('TREATMENT PLAN', dv('treatmentPlan')));

  // 8. MEDICINE / TREATMENT
  if (dv('medications').isNotEmpty) {
    final cellPad = pw.EdgeInsets.all(3.5 * scale);

    pw.Widget hCell(String t) => pw.Padding(
          padding: cellPad,
          child: pw.Text(t,
              style: pw.TextStyle(font: fontBold, fontSize: fs, color: kC)),
        );

    pw.Widget dCell(String t) => pw.Padding(
          padding: cellPad,
          child: pw.Text(t.trim().isEmpty ? '-' : t.trim(),
              style: pw.TextStyle(font: font, fontSize: fs, color: kC)),
        );

    final meds = _parseMedsForPdf(dv('medications'));
    if (meds.isNotEmpty) {
      sections.add(sec('MEDICINE / TREATMENT', [
        pw.Table(
          tableWidth: pw.TableWidth.max,
          border: pw.TableBorder.all(color: _kBorder, width: 0.4),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),  // Medicine
            1: pw.FlexColumnWidth(2),  // Dose
            2: pw.FlexColumnWidth(2),  // Route
            3: pw.FlexColumnWidth(3),  // Frequency
            4: pw.FlexColumnWidth(3),  // Duration
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.white),
              children: ['Medicine', 'Dose', 'Route', 'Frequency', 'Duration']
                  .map(hCell)
                  .toList(),
            ),
            ...meds.asMap().entries.map((e) {
              final m  = e.value;
              final bg = e.key.isOdd
                  ? const PdfColor.fromInt(0xFFF8FAFC)
                  : null;
              return pw.TableRow(
                decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
                children: [
                  pw.Padding(
                    padding: cellPad,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          m.medicine.trim().isEmpty ? '-' : m.medicine.trim(),
                          style: pw.TextStyle(
                              font: font, fontSize: fs, color: kC),
                        ),
                        if (m.specialInstruction.isNotEmpty)
                          pw.Text('* ${m.specialInstruction}',
                              style: pw.TextStyle(
                                  font: font,
                                  fontSize: fs - 1,
                                  color: const PdfColor.fromInt(0xFFB07D2A),
                                  fontStyle: pw.FontStyle.italic)),
                      ],
                    ),
                  ),
                  dCell(m.dose),
                  dCell(m.route),
                  dCell(m.frequency),
                  dCell(m.duration),
                ],
              );
            }),
          ],
        ),
      ]));
    }
  }

  // 9. ADVICE — a. Instructions  b. Investigation Should be done  c. Cross Consultation
  {
    final items = <pw.Widget>[
      if (dv('advice').isNotEmpty)                fr('Instructions',               dv('advice')),
      if (dv('investigationToBeDone').isNotEmpty) fr('Investigation Should be done', dv('investigationToBeDone')),
      if (dv('crossConsultation').isNotEmpty)     fr('Cross Consultation',         dv('crossConsultation')),
    ];
    if (items.isNotEmpty) sections.add(sec('ADVICE', items));
  }

  // NOTES
  if (dv('notes').isNotEmpty)
    sections.add(sec('NOTES', [fr('', dv('notes'))]));

  return sections;
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

  // Build list of sections — only include sections/fields that have actual data
  final sections = <pw.Widget>[];

  // PATIENT CONTACT & ID
  {
    final items = <pw.Widget>[
      if (d('phone').isNotEmpty)   _fieldRow('Phone',   d('phone'),   font, fontBold),
      if (d('address').isNotEmpty) _fieldRow('Address', d('address'), font, fontBold),
      if (d('email').isNotEmpty)   _fieldRow('Email',   d('email'), font, fontBold),
    ];
    if (items.isNotEmpty) sections.add(_section('PATIENT CONTACT & ID', fontBold, items));
  }

  // VITALS — only show vitals that have a value
  {
    final hasW  = d('weight').isNotEmpty;
    final hasBP = d('bloodPressure').isNotEmpty;
    final hasT  = d('temperature').isNotEmpty;
    if (hasW || hasBP || hasT) {
      sections.add(_section('VITALS', fontBold, [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (hasW)  ...[_vitalLabel('Weight',         font, fontBold), pw.Expanded(flex: 2, child: _valueUnderline(d('weight'),        font)), pw.SizedBox(width: 10)],
            if (hasBP) ...[_vitalLabel('Blood Pressure', font, fontBold), pw.Expanded(flex: 2, child: _valueUnderline(d('bloodPressure'),  font)), pw.SizedBox(width: 10)],
            if (hasT)  ...[_vitalLabel('Temperature',    font, fontBold), pw.Expanded(flex: 2, child: _valueUnderline(d('temperature'),    font))],
          ],
        ),
      ]));
    }
  }

  // KNOWN ALLERGIES
  if (d('allergies').isNotEmpty)
    sections.add(_section('KNOWN ALLERGIES', fontBold, [
      _fieldRow('', d('allergies'), font, fontBold),
    ]));

  // PRESENTING COMPLAINTS
  {
    final items = <pw.Widget>[
      if (d('chiefComplaint').isNotEmpty)   _fieldRow('Chief Complaint',   d('chiefComplaint'),   font, fontBold),
      if (d('previousHistory').isNotEmpty)  _fieldRow('Previous History',  d('previousHistory'),  font, fontBold),
    ];
    if (items.isNotEmpty) sections.add(_section('PRESENTING COMPLAINTS', fontBold, items));
  }

  // EXAMINATION FINDINGS
  {
    final items = <pw.Widget>[
      if (d('examGeneral').isNotEmpty)
        _fieldRow('General Examination', d('examGeneral'), font, fontBold),
      if (d('examNeurological').isNotEmpty)
        _fieldRow('Neurological Examination', d('examNeurological'), font, fontBold),
    ];
    if (items.isNotEmpty) sections.add(_section('EXAMINATION FINDINGS', fontBold, items));
  }

  // PREVIOUS INVESTIGATIONS
  {
    final items = <pw.Widget>[
      if (d('imaging').isNotEmpty)            _fieldRow('Imaging',             d('imaging'),             font, fontBold),
      if (d('otherInvestigation').isNotEmpty) _fieldRow('Other Investigation', d('otherInvestigation'),  font, fontBold),
    ];
    if (items.isNotEmpty) sections.add(_section('PREVIOUS INVESTIGATIONS', fontBold, items));
  }

  // IMPRESSION
  {
    final items = <pw.Widget>[
      if (d('clinicalDiagnosis').isNotEmpty) _fieldRow('Clinical Diagnosis', d('clinicalDiagnosis'), font, fontBold),
      if (d('diagnosis').isNotEmpty)         _fieldRow('Impression',         d('diagnosis'),         font, fontBold),
    ];
    if (items.isNotEmpty) sections.add(_section('IMPRESSION', fontBold, items));
  }

  // TREATMENT PLAN
  if (d('treatmentPlan').isNotEmpty)
    sections.add(_section('TREATMENT PLAN', fontBold, [
      _fieldRow('Treatment Plan', d('treatmentPlan'), font, fontBold),
    ]));

  // TREATMENT (MEDICINES) — only shown when there is data
  if (d('medications').isNotEmpty)
    sections.add(_section('TREATMENT (MEDICINES)', fontBold, [
      _buildMedicinesTable(d('medications'), font, fontBold),
    ]));

  // ADVICE — after treatment
  if (d('advice').isNotEmpty || d('investigationToBeDone').isNotEmpty)
    sections.add(_section('ADVICE', fontBold, [
      if (d('advice').isNotEmpty)
        pw.Text(d('advice'), style: pw.TextStyle(font: font, fontSize: 9.5, color: _kText)),
      if (d('investigationToBeDone').isNotEmpty) ...[
        if (d('advice').isNotEmpty) pw.SizedBox(height: 4),
        _fieldRow('Investigation Should be done', d('investigationToBeDone'), font, fontBold),
      ],
    ]));

  // CROSS REFERENCE
  if (d('crossConsultation').isNotEmpty)
    sections.add(_section('CROSS REFERENCE (OTHER DOCTOR CONSULTATION)', fontBold, [
      _fieldRow('Cross Consultation', d('crossConsultation'), font, fontBold),
    ]));

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: sections,
  );
}

// ── Section block: plain bold heading + content + thin green divider ─────────
// NO filled background — matches reference design (Image #45)

pw.Widget _section(String title, pw.Font fontBold, List<pw.Widget> items) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // Plain bold navy heading — no background fill
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 5),
        child: pw.Text(
          title,
          style: pw.TextStyle(
              font: fontBold, fontSize: 9.5, color: _kNavy, letterSpacing: 0.3),
        ),
      ),
      // Content
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(10, 0, 10, 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: items,
        ),
      ),
      // Thin green divider
      pw.Container(height: 0.7, color: _kGreenDiv),
    ],
  );
}

// ── Medicines table builder ───────────────────────────────────────────────────

class _MedRow {
  final String medicine;
  final String dose;
  final String route;
  final String frequency;
  final String duration;
  final String specialInstruction;
  const _MedRow({required this.medicine, required this.dose, required this.route, required this.frequency, required this.duration, this.specialInstruction = ''});
}

List<_MedRow> _parseMedsForPdf(String raw) {
  return raw.split('\n').where((l) => l.trim().isNotEmpty).map((line) {
    // Extract special instruction (anything after last " | ")
    final pipeIdx = line.lastIndexOf(' | ');
    final lineMain = pipeIdx >= 0 ? line.substring(0, pipeIdx).trim() : line;
    final specialInstruction = pipeIdx >= 0 ? line.substring(pipeIdx + 3).trim() : '';
    final doseMatch   = RegExp(r'\[([^\]]+)\]').firstMatch(lineMain);
    final dose        = doseMatch?.group(1) ?? '';
    final withoutDose = lineMain.replaceFirst(doseMatch?.group(0) ?? '', '').trim();
    final routeMatch  = RegExp(r'\(([^)]+)\)').firstMatch(withoutDose);
    final route       = routeMatch?.group(1) ?? '';
    final withoutRoute = withoutDose.replaceFirst(routeMatch?.group(0) ?? '', '').trim();
    final dashIdx  = withoutRoute.indexOf(' - ');
    final medicine = dashIdx >= 0 ? withoutRoute.substring(0, dashIdx).trim() : withoutRoute;
    final right    = dashIdx >= 0 ? withoutRoute.substring(dashIdx + 3).trim() : '';
    final mulIdx   = right.indexOf(' × ');
    final frequency = mulIdx >= 0 ? right.substring(0, mulIdx).trim() : right;
    final duration  = mulIdx >= 0 ? right.substring(mulIdx + 3).trim() : '';
    return _MedRow(medicine: medicine, dose: dose, route: route, frequency: frequency, duration: duration, specialInstruction: specialInstruction);
  }).toList();
}

pw.Widget _buildMedicinesTable(String raw, pw.Font font, pw.Font fontBold) {
  final meds = _parseMedsForPdf(raw);
  if (meds.isEmpty) return pw.SizedBox();

  const headers = ['Medicine', 'Dose', 'Route', 'Frequency', 'Duration'];

  pw.Widget headerCell(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: _kNavy)),
      );

  pw.Widget dataCell(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t.trim().isEmpty ? '-' : t.trim(),
            style: pw.TextStyle(font: font, fontSize: 8.5, color: _kText)),
      );

  return pw.Table(
    border: pw.TableBorder.all(color: _kBorder, width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(4),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(2),
      3: pw.FlexColumnWidth(2),
      4: pw.FlexColumnWidth(2),
    },
    children: [
      // Header row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEEEEF8)),
        children: headers.map(headerCell).toList(),
      ),
      // Data rows
      ...meds.asMap().entries.map((e) {
        final m = e.value;
        final bg = e.key.isOdd ? const PdfColor.fromInt(0xFFFAFAFF) : null;
        return pw.TableRow(
          decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
          children: [
            // Medicine cell shows special instruction as italic note below name
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(m.medicine.trim().isEmpty ? '-' : m.medicine.trim(),
                      style: pw.TextStyle(font: font, fontSize: 8.5, color: _kText)),
                  if (m.specialInstruction.isNotEmpty)
                    pw.Text('* ${m.specialInstruction}',
                        style: pw.TextStyle(
                            font: font, fontSize: 7.5,
                            color: const PdfColor.fromInt(0xFFB07D2A),
                            fontStyle: pw.FontStyle.italic)),
                ],
              ),
            ),
            dataCell(m.dose),
            dataCell(m.route),
            dataCell(m.frequency),
            dataCell(m.duration),
          ],
        );
      }),
    ],
  );
}

// ── Field row: fixed-width label + colon + underlined value area ─────────────

pw.Widget _fieldRow(
  String label,
  String value,
  pw.Font font,
  pw.Font fontBold,
) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (label.isNotEmpty) ...[
          pw.SizedBox(
            width: 115,
            child: pw.Text(label,
                style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: _kLabel)),
          ),
          pw.Text('  :',
              style: pw.TextStyle(font: font, fontSize: 9.5, color: _kLabel)),
          pw.SizedBox(width: 4),
        ],
        pw.Expanded(
          child: pw.Text(value,
              style: pw.TextStyle(font: font, fontSize: 9.5, color: _kText)),
        ),
      ],
    ),
  );
}

// Value text + underline (reused for fields and vitals)
pw.Widget _valueUnderline(String value, pw.Font font) {
  return pw.Text(value,
      style: pw.TextStyle(font: font, fontSize: 9.5, color: _kText));
}

// Vital label (e.g. "Weight  :")
pw.Widget _vitalLabel(String label, pw.Font font, pw.Font fontBold) {
  return pw.Text('$label  :',
      style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: _kLabel));
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
    _buildManualPdf(Set<String>.from(args.$1), args.$2, args.$3);

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
  addRow('Known Allergies',     'allergies');
  addRow('Chief Complaint',     'chiefComplaint');
  addRow('Previous History',    'previousHistory');
  addRow('General Examination', 'examGeneral');
  addRow('Neurological Examination', 'examNeurological');
  addRow('Clinical Diagnosis',  'clinicalDiagnosis');
  addRow('Imaging',             'imaging');
  addRow('Other Investigation', 'otherInvestigation');
  addRow('Impression',          'diagnosis');
  addRow('Advice',                       'advice');
  addRow('Investigation Should be done', 'investigationToBeDone');
  addRow('Medications',                  'medications');
  addRow('Cross Consultation',           'crossConsultation');
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
      final bd = await rootBundle.load('assets/images/app_logo.png');
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
      final bd = await rootBundle.load('assets/images/app_logo.png');
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

    // Build filename: PatientFullName_DDMMYYYY
    final firstName = (data['firstName'] ?? '').trim();
    final lastName  = (data['lastName']  ?? '').trim();
    final fullName  = [firstName, lastName].where((s) => s.isNotEmpty).join('');
    final now       = DateTime.now();
    String _p2(int v) => v.toString().padLeft(2, '0');
    final dateStr   = '${_p2(now.day)}${_p2(now.month)}${now.year}';
    final fileName  = fullName.isNotEmpty ? '${fullName}_$dateStr.pdf' : 'patient_report_$dateStr.pdf';

    try {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return;
    } catch (_) {}

    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
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
