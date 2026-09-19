// visit_view_screen.dart  –  Read-only visit detail view
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../examinations/presentation/screens/examination_screen.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../../../photos/domain/entities/photo_entity.dart';
import '../../../photos/presentation/providers/photo_provider.dart';
import '../../../photos/presentation/widgets/photo_gallery_widget.dart';
import '../../../prescriptions/domain/entities/prescription_entity.dart';
import '../../../prescriptions/presentation/screens/prescription_screen.dart';
import '../../domain/entities/visit_entity.dart';
import '../providers/visit_provider.dart';

const _kP1    = Color(0xFF4B55CC);
const _kP2    = Color(0xFF3D47B4);
const _kRed   = Color(0xFF8A4430);
const _kGreen = Color(0xFF2D7A4E);
const _kAmber = Color(0xFF74633E);

bool  _isDark  (BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _kBg     (BuildContext c) => _isDark(c) ? const Color(0xFF171629) : const Color(0xFFF8F6F2);
Color _kCard   (BuildContext c) => _isDark(c) ? const Color(0xFF2A284D) : Colors.white;
Color _kNavy   (BuildContext c) => _isDark(c) ? const Color(0xFFEEECFF) : const Color(0xFF302D28);
Color _kSlate  (BuildContext c) => _isDark(c) ? const Color(0xFFCCCAE8) : const Color(0xFF6E6A63);
Color _kMuted  (BuildContext c) => _isDark(c) ? const Color(0xFF9896B8) : const Color(0xFF979088);
Color _kBorder (BuildContext c) => _isDark(c) ? const Color(0xFF3A3865) : const Color(0xFFE0DDD7);

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  if (parts.first.isNotEmpty) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  return '?';
}

class VisitViewScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String visitId;
  const VisitViewScreen({super.key, required this.patientId, required this.visitId});

  @override
  ConsumerState<VisitViewScreen> createState() => _VisitViewScreenState();
}

class _VisitViewScreenState extends ConsumerState<VisitViewScreen> {

  @override
  Widget build(BuildContext context) {
    final patientId  = widget.patientId;
    final visitId    = widget.visitId;
    final visitAsync   = ref.watch(visitEditProvider('$patientId/$visitId'));
    final patientAsync = ref.watch(patientByIdProvider(patientId));
    final examState    = ref.watch(examinationProvider('$patientId/$visitId'));
    final rxState      = ref.watch(prescriptionProvider('$patientId/$visitId'));
    final photoState   = ref.watch(photoProvider(patientId));
    final canWrite     = ref.watch(canWriteProvider);
    final isStaff      = ref.watch(isStaffProvider);

    final visit = visitAsync;
    if (visit == null) {
      return Scaffold(
        backgroundColor: _kBg(context),
        appBar: AppBar(
          backgroundColor: _kP1,
          foregroundColor: Colors.white,
          title: const Text('Visit Details'),
        ),
        body: const Center(child: CircularProgressIndicator(color: _kP1)),
      );
    }

    // Parse examination JSON — field names match the wizard controllers
    final Map<String, String> vitals = {};
    String prevHistoryText        = '';
    String chiefComplaintText     = '';
    String examGeneralText        = '';
    String examNeuroText          = '';
    String imagingText            = '';
    String otherInvestText        = '';
    String adviceText             = '';
    String investigationToBeDone  = '';
    String crossConsultText       = '';
    List<Map<String, dynamic>> examPrescriptions = [];
    String medicationsText        = '';

    if (visit.examination?.isNotEmpty == true) {
      try {
        final m = json.decode(visit.examination!) as Map<String, dynamic>;
        String s(String k) => (m[k] as String?)?.trim() ?? '';

        // Vitals
        if (s('bp').isNotEmpty)     vitals['BP']     = '${s('bp')} mmHg';
        if (s('pulse').isNotEmpty)  vitals['Pulse']  = '${s('pulse')} bpm';
        if (s('temp').isNotEmpty)   vitals['Temp']   = '${s('temp')}°F';
        if (s('spo2').isNotEmpty)   vitals['SpO₂']   = '${s('spo2')}%';
        if (s('weight').isNotEmpty) vitals['Weight'] = '${s('weight')} kg';
        if (s('height').isNotEmpty) vitals['Height'] = '${s('height')} cm';

        // Wizard fields (with old-key fallbacks for legacy data)
        prevHistoryText    = s('previousHistory');
        chiefComplaintText = s('chiefComplaint');
        examGeneralText    = s('examGeneral').isNotEmpty   ? s('examGeneral')   : s('physical');
        examNeuroText      = s('examNeurological').isNotEmpty ? s('examNeurological') : s('systemic');
        imagingText        = s('imaging').isNotEmpty       ? s('imaging')       : s('radiology');
        otherInvestText    = s('otherInvestigation');
        adviceText            = s('advice');
        investigationToBeDone = s('investigationToBeDone');
        crossConsultText      = s('crossConsultation');
        medicationsText    = s('medications');

        // Structured prescriptions saved by wizard
        final presStr = s('prescriptions');
        if (presStr.isNotEmpty) {
          try {
            examPrescriptions = (json.decode(presStr) as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();
          } catch (_) {}
        }
      } catch (_) {}
    }

    // Visit entity vitals fallback
    if (vitals['BP']     == null && visit.bp?.isNotEmpty         == true) vitals['BP']     = visit.bp!;
    if (vitals['Weight'] == null && visit.weight?.isNotEmpty      == true) vitals['Weight'] = visit.weight!;
    if (vitals['Temp']   == null && visit.temperature?.isNotEmpty == true) vitals['Temp']   = visit.temperature!;

    // Patient-level vitals fallback (e.g. temperature recorded on patient profile)
    final patient0 = patientAsync.valueOrNull;
    if (vitals['BP']     == null && patient0?.bloodPressure?.isNotEmpty == true) vitals['BP']     = patient0!.bloodPressure!;
    if (vitals['Weight'] == null && patient0?.weight?.isNotEmpty        == true) vitals['Weight'] = patient0!.weight!;
    if (vitals['Temp']   == null && patient0?.temperature?.isNotEmpty   == true) vitals['Temp']   = patient0!.temperature!;

    // Photo grouping
    final allVP = photoState.photos.where((p) => p.visitId == visitId).toList();
    List<PhotoEntity> cap(String c) => allVP.where((p) => p.caption == c).toList();
    List<PhotoEntity> cat(PhotoCategory c) =>
        allVP.where((p) => p.category == c && (p.caption == null || p.caption!.isEmpty)).toList();

    final prevHistoryPhotos      = cap('Previous History');
    final chiefComplaintPhotos   = cap('Chief Complaint');
    final examGeneralPhotos      = [...cat(PhotoCategory.examination), ...cap('General Examination')];
    final examNeurologicalPhotos = cap('Neurological Examination');
    final clinicalDxPhotos       = cap('Clinical Diagnosis');
    final imagingPhotos          = [...cat(PhotoCategory.radiology), ...cap('Imaging')];
    final otherInvestPhotos      = cap('Other Investigation');
    final impressionPhotos       = cap('Impression');
    final planPhotos             = cap('Treatment Plan');
    final medicinesPhotos        = cap('Medicines');
    final crossConsultPhotos     = cap('Cross Consultation');
    final visitPhotos            = cat(PhotoCategory.visit);
    final txPhotos               = cat(PhotoCategory.treatment);
    final reportPhotos           = photoState.photos
        .where((p) => p.patientId == patientId && p.category == PhotoCategory.patientReport)
        .toList();

    final patient = patientAsync.valueOrNull;
    final dateFmt = DateFormat('d MMM yyyy');
    final timeFmt = DateFormat('h:mm a');
    final chips   = visit.complaints?.isNotEmpty == true
        ? visit.complaints!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final bool hasContent =
        prevHistoryText.isNotEmpty || chiefComplaintText.isNotEmpty ||
        chips.isNotEmpty || vitals.isNotEmpty ||
        examGeneralText.isNotEmpty || examNeuroText.isNotEmpty ||
        examState != null ||
        imagingText.isNotEmpty || otherInvestText.isNotEmpty ||
        visit.clinicalImpression?.isNotEmpty == true ||
        visit.plan?.isNotEmpty == true ||
        examPrescriptions.isNotEmpty || medicationsText.isNotEmpty ||
        (rxState != null && (rxState.text?.isNotEmpty == true || rxState.drugs.isNotEmpty)) ||
        adviceText.isNotEmpty || investigationToBeDone.isNotEmpty || crossConsultText.isNotEmpty ||
        visit.notes?.isNotEmpty == true ||
        allVP.isNotEmpty || reportPhotos.isNotEmpty;

    return Scaffold(
      backgroundColor: _kBg(context),
      appBar: AppBar(
        backgroundColor: _kP1,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 17),
          onPressed: () => context.pop(),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Visit Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          if (patient != null)
            Text(patient.fullName,
                style: const TextStyle(fontSize: 11, color: Colors.white70,
                    fontWeight: FontWeight.w500)),
        ]),
        actions: [
          if (canWrite)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit Visit',
              onPressed: () => context.push('/patients/$patientId/visits/$visitId'),
            ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [

          // ── Rich visit header ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4B55CC), Color(0xFF353FBB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _kP1.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(children: [
              // Decorative circles
              Positioned(right: -18, top: -18,
                child: Container(width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ))),
              Positioned(right: 30, bottom: -25,
                child: Container(width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  // Patient initials avatar
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                    ),
                    child: Center(child: Text(
                      patient != null ? _initials(patient.fullName) : '?',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                    )),
                  ),
                  const SizedBox(width: 13),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (patient != null)
                      Text(patient.fullName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 0.1)),
                    const SizedBox(height: 5),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Text(visit.visitType.label,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Text(dateFmt.format(visit.visitDate),
                          style: const TextStyle(fontSize: 11, color: Colors.white70,
                              fontWeight: FontWeight.w500)),
                    ]),
                    const SizedBox(height: 2),
                    Text(timeFmt.format(visit.visitDate),
                        style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  ])),
                  if (visit.isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: const Text('DRAFT',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                ]),
              ),
            ]),
          ),

          if (!hasContent)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Column(children: [
                Icon(Icons.note_alt_outlined, size: 40, color: _kMuted(context)),
                const SizedBox(height: 10),
                Text('No details recorded.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kNavy(context))),
              ])),
            ),

          // ── All sections in ONE compact card ────────────────────────
          if (hasContent)
            Container(
              decoration: BoxDecoration(
                color: _kCard(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder(context)),
              ),
              child: _buildSections(
                context,
                isStaff: ref.read(isStaffProvider),
                patient: patient,
                visit: visit,
                examPrescriptions: examPrescriptions,
                medicationsText: medicationsText,
                prevHistoryText: prevHistoryText,
                chiefComplaintText: chiefComplaintText,
                chips: chips,
                vitals: vitals,
                examGeneralText: examGeneralText,
                examNeuroText: examNeuroText,
                examState: examState,
                imagingText: imagingText,
                otherInvestText: otherInvestText,
                adviceText: adviceText,
                investigationToBeDone: investigationToBeDone,
                crossConsultText: crossConsultText,
                rxState: rxState,
                prevHistoryPhotos: prevHistoryPhotos,
                chiefComplaintPhotos: chiefComplaintPhotos,
                examGeneralPhotos: examGeneralPhotos,
                clinicalDxPhotos: clinicalDxPhotos,
                examNeurologicalPhotos: examNeurologicalPhotos,
                imagingPhotos: imagingPhotos,
                otherInvestPhotos: otherInvestPhotos,
                impressionPhotos: impressionPhotos,
                planPhotos: planPhotos,
                medicinesPhotos: medicinesPhotos,
                crossConsultPhotos: crossConsultPhotos,
                visitPhotos: visitPhotos,
                txPhotos: txPhotos,
                reportPhotos: reportPhotos,
              ),
            ),
        ],
      ),

      floatingActionButton: canWrite
          ? FloatingActionButton.small(
              onPressed: () => context.push('/patients/$patientId/visits/$visitId'),
              backgroundColor: _kP1,
              foregroundColor: Colors.white,
              tooltip: 'Edit Visit',
              child: const Icon(Icons.edit_rounded, size: 18),
            )
          : null,
    );
  }
}

// ── Sections in wizard order ──────────────────────────────────────────────────
Widget _buildSections(
  BuildContext context, {
  required bool isStaff,
  required PatientEntity? patient,
  required VisitEntity visit,
  required List<Map<String, dynamic>> examPrescriptions,
  required String medicationsText,
  required String prevHistoryText,
  required String chiefComplaintText,
  required List<String> chips,
  required Map<String, String> vitals,
  required String examGeneralText,
  required String examNeuroText,
  required dynamic examState,
  required String imagingText,
  required String otherInvestText,
  required String adviceText,
  required String investigationToBeDone,
  required String crossConsultText,
  required dynamic rxState,
  required List<PhotoEntity> prevHistoryPhotos,
  required List<PhotoEntity> chiefComplaintPhotos,
  required List<PhotoEntity> examGeneralPhotos,
  required List<PhotoEntity> clinicalDxPhotos,
  required List<PhotoEntity> examNeurologicalPhotos,
  required List<PhotoEntity> imagingPhotos,
  required List<PhotoEntity> otherInvestPhotos,
  required List<PhotoEntity> impressionPhotos,
  required List<PhotoEntity> planPhotos,
  required List<PhotoEntity> medicinesPhotos,
  required List<PhotoEntity> crossConsultPhotos,
  required List<PhotoEntity> visitPhotos,
  required List<PhotoEntity> txPhotos,
  required List<PhotoEntity> reportPhotos,
}) {
  // Build list of visible section widgets in wizard sequence
  final sections = <Widget>[];

  // ── Step 1: Patient Info ─────────────────────────────────────────────────
  if (patient != null) {
    bool ne(String? v) => v != null && v.trim().isNotEmpty;

    final infoRows = <Widget>[];

    // Row helper: label + collapsible value side by side
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 115,
          child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: _kMuted(context))),
        ),
        Expanded(
          child: _CollapsibleText(value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _kNavy(context))),
        ),
      ]),
    );

    // 1. Full Name
    infoRows.add(row('Name', patient.fullName));

    // 2. Age / Gender / Email
    final ageParts = <String>[];
    if (patient.computedAge > 0) ageParts.add('${patient.computedAge} yrs');
    if (ne(patient.sex)) ageParts.add(patient.sex!);
    if (ageParts.isNotEmpty) infoRows.add(row('Age / Gender', ageParts.join('  ·  ')));
    if (ne(patient.email)) infoRows.add(row('Email', patient.email!));

    // 3. ID Proof Type / ID Number
    if (ne(patient.idProofType)) infoRows.add(row('ID Proof Type', patient.idProofType!));
    if (ne(patient.idProofNumber)) infoRows.add(row('ID Number', patient.idProofNumber!));

    // 4. Phone Number / Alternate Phone / Full Address
    if (ne(patient.phone)) infoRows.add(row('Phone Number', patient.phone!));
    if (ne(patient.altPhone)) infoRows.add(row('Alternate Phone', patient.altPhone!));
    if (ne(patient.address)) infoRows.add(row('Full Address', patient.address!));

    // 5. Weight / Blood Pressure / Temperature — only for staff
    if (isStaff) {
      if (ne(patient.weight))        infoRows.add(row('Weight', patient.weight!));
      if (ne(patient.bloodPressure)) infoRows.add(row('Blood Pressure', patient.bloodPressure!));
      if (ne(patient.temperature))   infoRows.add(row('Temperature', patient.temperature!));
    }

    // 6. Known Allergies
    if (ne(patient.allergies)) infoRows.add(row('Known Allergies', patient.allergies!));

    if (infoRows.isNotEmpty)
      sections.add(_CS('Patient Information', Icons.person_outline_rounded, _kP1,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: infoRows),
        context));
  }

  // ── Clinical fields — hidden for staff (they only see Patient Information) ──
  if (!isStaff) {

  // 2. Chief Complaint
  final complaintText = chiefComplaintText.isNotEmpty
      ? chiefComplaintText
      : (visit.complaints?.trim() ?? '');
  final complaintChips = chips.isNotEmpty ? chips
      : complaintText.isNotEmpty ? complaintText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
      : <String>[];
  if (complaintText.isNotEmpty || chiefComplaintPhotos.isNotEmpty)
    sections.add(_CS('Chief Complaint', Icons.report_problem_outlined, _kP1,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (complaintText.isNotEmpty)
          _CollapsibleText(complaintText,
              style: TextStyle(fontSize: 12, color: _kNavy(context), height: 1.5)),
        if (chiefComplaintPhotos.isNotEmpty) _PhotoRow('', chiefComplaintPhotos),
      ]), context));

  // 3. Previous History
  if (prevHistoryText.isNotEmpty || prevHistoryPhotos.isNotEmpty)
    sections.add(_CS('Previous History', Icons.history_outlined, _kAmber,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (prevHistoryText.isNotEmpty)
          _CollapsibleText(prevHistoryText, style: TextStyle(fontSize: 12, color: _kNavy(context), height: 1.5)),
        if (prevHistoryPhotos.isNotEmpty) _PhotoRow('', prevHistoryPhotos),
      ]), context));

  // 4. Examination Finding — a. Vitals  b. General Examination  c. Neurological Examination
  {
    final hasVitals = vitals.isNotEmpty;
    final hasGeneral = examGeneralText.isNotEmpty || examGeneralPhotos.isNotEmpty || clinicalDxPhotos.isNotEmpty;
    final hasNeuro = examNeuroText.isNotEmpty || examState != null || examNeurologicalPhotos.isNotEmpty;
    if (hasVitals || hasGeneral || hasNeuro)
      sections.add(_CS('Examination Finding', Icons.person_search_outlined, _kAmber,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // a. Vitals
          if (hasVitals) ...[
            Text('a. Vitals',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kMuted(context))),
            const SizedBox(height: 5),
            Wrap(spacing: 8, runSpacing: 6,
                children: vitals.entries.map((e) => _VitalTile(e.key, e.value)).toList()),
            const SizedBox(height: 8),
          ],
          // b. General Examination
          if (hasGeneral) ...[
            Text('b. General Examination',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kMuted(context))),
            const SizedBox(height: 4),
            if (examGeneralText.isNotEmpty)
              _CollapsibleText(examGeneralText, style: TextStyle(fontSize: 12, color: _kNavy(context), height: 1.5)),
            if (examGeneralPhotos.isNotEmpty) _PhotoRow('', examGeneralPhotos),
            if (clinicalDxPhotos.isNotEmpty)  _PhotoRow('', clinicalDxPhotos),
            const SizedBox(height: 6),
          ],
          // c. Neurological Examination
          if (hasNeuro) ...[
            Text('c. Neurological Examination',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kMuted(context))),
            const SizedBox(height: 4),
            if (examNeuroText.isNotEmpty)
              _CollapsibleText(examNeuroText, style: TextStyle(fontSize: 12, color: _kNavy(context), height: 1.5)),
            if (examState != null) ...[
              if ((examState.generalText as String?)?.isNotEmpty    == true) _VF('General',      examState.generalText as String, context),
              if ((examState.motorText as String?)?.isNotEmpty      == true) _VF('Motor',        examState.motorText as String, context),
              if ((examState.sensoryText as String?)?.isNotEmpty    == true) _VF('Sensory',      examState.sensoryText as String, context),
              if ((examState.reflexesText as String?)?.isNotEmpty   == true) _VF('Reflexes',     examState.reflexesText as String, context),
              if ((examState.cerebellarText as String?)?.isNotEmpty == true) _VF('Cerebellar',   examState.cerebellarText as String, context),
              if ((examState.specialTestsText as String?)?.isNotEmpty == true) _VF('Special Tests', examState.specialTestsText as String, context),
            ],
            if (examNeurologicalPhotos.isNotEmpty) _PhotoRow('', examNeurologicalPhotos),
          ],
        ]), context));
  }

  // 5. Previous Investigations
  if (imagingText.isNotEmpty || otherInvestText.isNotEmpty ||
      imagingPhotos.isNotEmpty || otherInvestPhotos.isNotEmpty)
    sections.add(_CS('Previous Investigations', Icons.biotech_outlined, _kP2,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imagingText.isNotEmpty)     _VF('Imaging',              imagingText,     context),
        if (otherInvestText.isNotEmpty) _VF('Other Investigations', otherInvestText, context),
        if (imagingPhotos.isNotEmpty)    _PhotoRow('', imagingPhotos),
        if (otherInvestPhotos.isNotEmpty) _PhotoRow('', otherInvestPhotos),
      ]), context));

  // 6. Impression
  if (visit.clinicalImpression?.isNotEmpty == true || impressionPhotos.isNotEmpty)
    sections.add(_CS('Impression', Icons.lightbulb_outline_rounded, _kGreen,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (visit.clinicalImpression?.isNotEmpty == true)
          _CollapsibleText(visit.clinicalImpression!, style: TextStyle(fontSize: 12, color: _kNavy(context), height: 1.5)),
        if (impressionPhotos.isNotEmpty) _PhotoRow('', impressionPhotos),
      ]), context));

  // 7. Treatment Plan
  if (visit.plan?.isNotEmpty == true || planPhotos.isNotEmpty)
    sections.add(_CS('Treatment Plan', Icons.assignment_outlined, _kGreen,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (visit.plan?.isNotEmpty == true)
          _CollapsibleText(visit.plan!, style: TextStyle(fontSize: 12, color: _kNavy(context), height: 1.5)),
        if (planPhotos.isNotEmpty) _PhotoRow('', planPhotos),
      ]), context));

  // 8. Medicine / Treatment
  final hasPrescription = examPrescriptions.isNotEmpty || medicationsText.isNotEmpty ||
      (rxState != null && (rxState.text?.isNotEmpty == true || (rxState.drugs as List).isNotEmpty)) ||
      medicinesPhotos.isNotEmpty;

  if (hasPrescription)
    sections.add(_CS('Medicine / Treatment', Icons.medication_outlined, _kP1,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (examPrescriptions.isNotEmpty)
          _ExamRxTable(prescriptions: examPrescriptions, context: context)
        else if (medicationsText.isNotEmpty)
          _CollapsibleText(medicationsText, style: TextStyle(fontSize: 12, color: _kNavy(context), height: 1.5)),
        if (rxState != null && examPrescriptions.isEmpty && medicationsText.isEmpty) ...[
          if (rxState.text?.isNotEmpty == true) _VF('Notes', rxState.text as String, context),
          if ((rxState.drugs as List).isNotEmpty) _RxTable(drugs: rxState.drugs as List<DrugEntry>),
        ],
        if (medicinesPhotos.isNotEmpty) _PhotoRow('', medicinesPhotos),
      ]), context));

  // 9. Advice — a. Instructions  b. Investigation Should be done  c. Cross Consultation
  final adviceItems = <Widget>[];
  if (adviceText.isNotEmpty)
    adviceItems.add(_VF('a. Instructions', adviceText, context));
  if (investigationToBeDone.isNotEmpty)
    adviceItems.add(_VF('b. Investigation Should be done', investigationToBeDone, context));
  if (crossConsultText.isNotEmpty || crossConsultPhotos.isNotEmpty) {
    adviceItems.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('c. Cross Consultation:',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted(context))),
      const SizedBox(height: 2),
      if (crossConsultText.isNotEmpty)
        _CollapsibleText(crossConsultText, style: TextStyle(fontSize: 12, color: _kNavy(context), height: 1.4)),
      if (crossConsultPhotos.isNotEmpty) _PhotoRow('', crossConsultPhotos),
    ]));
  }
  if (adviceItems.isNotEmpty)
    sections.add(_CS('Advice', Icons.tips_and_updates_outlined, _kGreen,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: adviceItems),
      context));

  // 12. Doctor's Notes (private — hidden for staff)
  if (!isStaff && visit.notes?.isNotEmpty == true)
    sections.add(_CS("Doctor's Notes", Icons.lock_outline_rounded, _kAmber,
      _CollapsibleText(visit.notes!, style: TextStyle(fontSize: 12, color: _kNavy(context), height: 1.5)),
      context));

  // 13. Orphan visit/treatment photos
  if (visitPhotos.isNotEmpty || txPhotos.isNotEmpty)
    sections.add(_CS('Photos', Icons.photo_library_outlined, _kAmber,
      Column(children: [
        if (visitPhotos.isNotEmpty) _PhotoRow('', visitPhotos),
        if (txPhotos.isNotEmpty) _PhotoRow('', txPhotos),
      ]), context));

  // 14. Reports
  if (reportPhotos.isNotEmpty)
    sections.add(_CS('Reports', Icons.upload_file_rounded, _kAmber,
      _PhotoRow('', reportPhotos), context));

  } // end !isStaff clinical sections

  // Mark last section so no trailing divider
  if (sections.isEmpty) return const SizedBox.shrink();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    for (int i = 0; i < sections.length; i++)
      i == sections.length - 1
          ? _wrapLast(sections[i])
          : sections[i],
  ]);
}

// Strips the trailing divider from the last section by re-wrapping
Widget _wrapLast(Widget sec) {
  if (sec is Column) return sec;
  return sec;
}

// ── Compact section inside single card ────────────────────────────────────────
Widget _CS(String title, IconData icon, Color color, Widget child,
    BuildContext context, {bool isLast = false}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: _kSlate(context).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 13, color: _kSlate(context)),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                color: _kSlate(context), letterSpacing: 0.2)),
      ]),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 13),
      child: child,
    ),
    if (!isLast) Divider(height: 1, color: _kBorder(context)),
  ]);
}

// ── Labelled field (label above collapsible value) ───────────────────────────
Widget _VF(String label, String value, BuildContext context) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('$label:',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: _kMuted(context))),
    const SizedBox(height: 2),
    _CollapsibleText(value,
        style: TextStyle(fontSize: 12, color: _kNavy(context), height: 1.4)),
  ]),
);

// kept for compatibility
Widget _VField(String label, String value, BuildContext context) =>
    _VF(label, value, context);

// ── Vital tile ────────────────────────────────────────────────────────────────
class _VitalTile extends StatelessWidget {
  final String label, value;
  const _VitalTile(this.label, this.value);

  static const _icons = <String, IconData>{
    'BP': Icons.favorite_outline, 'Pulse': Icons.monitor_heart_outlined,
    'Temp': Icons.thermostat_outlined, 'SpO₂': Icons.air_outlined,
    'Weight': Icons.scale_outlined, 'Height': Icons.height_outlined,
  };
  static const _colors = <String, Color>{
    'BP': _kP1, 'Pulse': _kRed, 'Temp': _kAmber,
    'SpO₂': _kP2, 'Weight': _kGreen, 'Height': Color(0xFF52537A),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors[label] ?? _kP1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icons[label] ?? Icons.analytics_outlined, size: 13, color: c),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.w700)),
          Text(value, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }
}

// ── Prescription table ────────────────────────────────────────────────────────
class _RxTable extends StatelessWidget {
  final List<DrugEntry> drugs;
  const _RxTable({required this.drugs});

  @override
  Widget build(BuildContext context) => Column(
    children: drugs.map((d) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _kP1.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kP1.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        const Icon(Icons.medication_outlined, size: 15, color: _kP1),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.displayName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: _kNavy(context))),
          if (d.displayDosage.isNotEmpty)
            Text(d.displayDosage,
                style: TextStyle(fontSize: 11, color: _kMuted(context))),
        ])),
      ]),
    )).toList(),
  );
}

// ── Collapsible text — shows 2 lines by default, expands on tap ──────────────
class _CollapsibleText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _CollapsibleText(this.text, {this.style});

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  bool _expanded = false;

  // Heuristic: likely to exceed 2 lines if >100 chars or has newlines
  bool get _isLong =>
      widget.text.length > 100 || widget.text.contains('\n');

  @override
  Widget build(BuildContext ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.text,
          maxLines: _expanded ? null : 2,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: widget.style),
      if (_isLong)
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              _expanded ? 'See less' : 'See more',
              style: const TextStyle(
                  fontSize: 11, color: _kP1, fontWeight: FontWeight.w600),
            ),
          ),
        ),
    ]);
  }
}

// ── Exam prescription table (from wizard JSON) ───────────────────────────────
class _ExamRxTable extends StatelessWidget {
  final List<Map<String, dynamic>> prescriptions;
  final BuildContext context;
  const _ExamRxTable({required this.prescriptions, required this.context});

  String _s(Map<String, dynamic> m, String k) => (m[k] as String?)?.trim() ?? '';

  @override
  Widget build(BuildContext ctx) {
    return Column(
      children: prescriptions.map((m) {
        final medicine  = _s(m, 'medicine');
        final dose      = _s(m, 'dose');
        final route     = _s(m, 'route');
        final freq      = _s(m, 'frequency');
        final duration  = _s(m, 'duration');
        final note      = _s(m, 'specialInstruction');
        if (medicine.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _kP1.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kP1.withValues(alpha: 0.12)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.medication_outlined, size: 13, color: _kP1),
              const SizedBox(width: 6),
              Expanded(
                child: Text(medicine,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: _kNavy(ctx))),
              ),
            ]),
            if (dose.isNotEmpty || route.isNotEmpty || freq.isNotEmpty || duration.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                [
                  if (dose.isNotEmpty) dose,
                  if (route.isNotEmpty) route,
                  if (freq.isNotEmpty) freq,
                  if (duration.isNotEmpty) duration,
                ].join('  ·  '),
                style: TextStyle(fontSize: 11, color: _kSlate(ctx)),
              ),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(note,
                  style: const TextStyle(
                      fontSize: 10, color: _kAmber, fontStyle: FontStyle.italic)),
            ],
          ]),
        );
      }).toList(),
    );
  }
}

// ── Photo row — compact filename list with open button ───────────────────────
class _PhotoRow extends StatefulWidget {
  final String label;
  final List<PhotoEntity> photos;
  const _PhotoRow(this.label, this.photos);

  @override
  State<_PhotoRow> createState() => _PhotoRowState();
}

class _PhotoRowState extends State<_PhotoRow> {
  bool _expanded = false;

  String _name(PhotoEntity p) {
    if (p.caption?.isNotEmpty == true && p.caption!.contains('.')) return p.caption!;
    final parts = p.storagePath.split('/');
    return parts.isNotEmpty ? parts.last : 'Attachment';
  }

  IconData _icon(PhotoEntity p) {
    final n = _name(p).toLowerCase();
    if (n.endsWith('.pdf'))  return Icons.picture_as_pdf_rounded;
    if (n.endsWith('.xls') || n.endsWith('.xlsx')) return Icons.table_chart_rounded;
    if (n.endsWith('.doc') || n.endsWith('.docx')) return Icons.description_rounded;
    return Icons.image_rounded;
  }

  Color _iconColor(PhotoEntity p) {
    final n = _name(p).toLowerCase();
    if (n.endsWith('.pdf'))  return const Color(0xFFEF4444);
    if (n.endsWith('.xls') || n.endsWith('.xlsx')) return const Color(0xFF16A34A);
    if (n.endsWith('.doc') || n.endsWith('.docx')) return const Color(0xFF2563EB);
    return _kP1;
  }

  Future<void> _open(PhotoEntity p) async {
    final url = p.url;
    if (url != null && url.isNotEmpty) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Widget _tile(PhotoEntity p, BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _iconColor(p).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _iconColor(p).withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Icon(_icon(p), size: 15, color: _iconColor(p)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _name(p),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: _kNavy(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (p.url != null || p.localPath != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _open(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kP1.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('View',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kP1)),
            ),
          ),
        ],
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();
    final showAll = _expanded || widget.photos.length <= 2;
    final visible = showAll ? widget.photos : widget.photos.take(2).toList();
    final hidden  = widget.photos.length - 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(widget.label.toUpperCase(),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: _kMuted(context), letterSpacing: 0.7)),
          const SizedBox(height: 5),
        ],
        ...visible.map((p) => _tile(p, context)),
        if (widget.photos.length > 2)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                _expanded ? 'See less' : '+$hidden more attachment${hidden > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: _kP1, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}
