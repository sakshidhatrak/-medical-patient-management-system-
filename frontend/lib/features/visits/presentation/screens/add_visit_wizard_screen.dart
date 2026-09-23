// ─────────────────────────────────────────────────────────────────────────────
// add_visit_wizard_screen.dart  –  3-step visit wizard
// Step 1: Patient Info (read-only, auto-populated)
// Step 2: Treatment (exact same fields as patient registration)
// Step 3: Preview & Print
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../../../photos/domain/entities/photo_entity.dart';
import '../../../photos/presentation/providers/photo_provider.dart';
import '../../../print_configuration/presentation/providers/print_config_provider.dart';
import '../../domain/entities/visit_entity.dart';
import '../providers/visit_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../medicines/data/medicine_service.dart';

// ── Fixed accent colours ───────────────────────────────────────────────────────
const _kBlue  = Color(0xFF5B5ECC);
const _kBlue2 = Color(0xFF4B55CC);
const _kGreen = Color(0xFF4EC080);
const _kRed   = Color(0xFFE07878);
const _kAmber = Color(0xFFD4A855);
const _kP1    = Color(0xFF5B5ECC);

// ── Theme-aware surface / text colours ────────────────────────────────────────
bool  _isDarkCtx(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _kBg    (BuildContext c) => _isDarkCtx(c) ? const Color(0xFF171629) : const Color(0xFFF8F6F2);
Color _kCard  (BuildContext c) => _isDarkCtx(c) ? const Color(0xFF252545) : Colors.white;
Color _kWiz   (BuildContext c) => _isDarkCtx(c) ? const Color(0xFF1E1C35) : const Color(0xFFECEAE4);
Color _kNavy  (BuildContext c) => _isDarkCtx(c) ? const Color(0xFFEEECFF) : const Color(0xFF302D28);
Color _kSlate (BuildContext c) => _isDarkCtx(c) ? const Color(0xFFCCCAE8) : const Color(0xFF6E6A63);
Color _kMuted (BuildContext c) => _isDarkCtx(c) ? const Color(0xFF9896B8) : const Color(0xFF979088);
Color _kBorder(BuildContext c) => _isDarkCtx(c) ? const Color(0xFF3A3865) : const Color(0xFFE0DDD7);

const _kVisitTypeLabels = ['OPD', 'Emergency', 'Follow-up'];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class AddVisitWizardScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String? visitId; // null = new visit, non-null = edit existing

  const AddVisitWizardScreen({
    super.key,
    required this.patientId,
    this.visitId,
  });

  @override
  ConsumerState<AddVisitWizardScreen> createState() => _AddVisitWizardState();
}

class _AddVisitWizardState extends ConsumerState<AddVisitWizardScreen> {
  // ── Wizard state ───────────────────────────────────────────────────────────
  int _step = 0;
  late final PageController _pageCtrl;
  bool _saving            = false;
  bool _visitLoaded       = false;
  bool _visitLoading      = false;
  bool _justSaved         = false;
  bool _visitTypeResolved = false; // true once we've set the type from existing visits
  PatientEntity? _patient;
  VisitEntity? _savedVisit;

  // ── Visit meta ─────────────────────────────────────────────────────────────
  DateTime  _visitDate = DateTime.now();
  VisitType _visitType = VisitType.opd;

  // ── Treatment: History & Complaint ────────────────────────────────────────
  final _prevHistoryCtrl     = TextEditingController();
  final _prevHistoryFiles    = <({String name, Uint8List bytes})>[];
  final _complaintCtrl       = TextEditingController();
  final _chiefComplaintFiles = <({String name, Uint8List bytes})>[];

  // ── Treatment: Examination Finding ────────────────────────────────────────
  String _examTab = 'general';
  final _examGeneralCtrl       = TextEditingController();
  final _examGeneralFiles      = <({String name, Uint8List bytes})>[];
  final _examNeurologicalCtrl  = TextEditingController();
  final _examNeurologicalFiles = <({String name, Uint8List bytes})>[];

  // ── Treatment: Investigation ──────────────────────────────────────────────
  final _clinicalDiagnosisCtrl  = TextEditingController();
  final _clinicalDiagnosisFiles = <({String name, Uint8List bytes})>[];
  final _imagingCtrl            = TextEditingController();
  final _imagingFiles           = <({String name, Uint8List bytes})>[];
  final _otherInvestCtrl        = TextEditingController();
  final _otherInvestFiles       = <({String name, Uint8List bytes})>[];

  // ── Treatment: Clinical Plan ──────────────────────────────────────────────
  final _diagnosisCtrl      = TextEditingController(); // Impression
  final _impressionFiles    = <({String name, Uint8List bytes})>[];
  final _treatmentCtrl      = TextEditingController(); // Plan
  final _planFiles          = <({String name, Uint8List bytes})>[];
  final _treatmentMedFiles  = <({String name, Uint8List bytes})>[];
  final _prescriptionRows   = <_PrescriptionRow>[]; // Structured prescriptions
  final _treatNotesCtrl       = TextEditingController();
  final _otNotesCtrl                 = TextEditingController();
  final _adviceCtrl                  = TextEditingController();
  final _crossConsultCtrl            = TextEditingController();
  final _crossConsultFiles           = <({String name, Uint8List bytes})>[];
  final _investigationToBeDoneCtrl   = TextEditingController();
  final _investigationToBeDoneFiles  = <({String name, Uint8List bytes})>[];

  // ── Vitals (per visit) ────────────────────────────────────────────────────
  final _weightCtrl = TextEditingController();
  final _bpCtrl     = TextEditingController();
  final _tempCtrl   = TextEditingController();

  // ── Patient fields editable in Step 1 ────────────────────────────────────
  bool _patientFieldsPopulated = false;
  final _pat1FirstNameCtrl  = TextEditingController();
  final _pat1LastNameCtrl   = TextEditingController();
  final _pat1AgeCtrl        = TextEditingController();
  final _pat1PhoneCtrl      = TextEditingController();
  final _pat1AltPhoneCtrl   = TextEditingController();
  final _pat1EmailCtrl      = TextEditingController();
  final _pat1AddressCtrl    = TextEditingController();
  final _pat1IdTypeCtrl     = TextEditingController();
  final _pat1IdNumberCtrl   = TextEditingController();
  String? _pat1Gender;
  final _pat1WeightCtrl     = TextEditingController();
  final _pat1BpCtrl         = TextEditingController();
  final _pat1TempCtrl       = TextEditingController();
  final _pat1AllergyCtrl    = TextEditingController();

  static const _stepLabels = ['Visit Details', 'Preview & Print'];
  static const _stepSubtitles = [
    'Patient info & treatment details',
    'Review & export visit record',
  ];
  static const _stepIcons = [
    Icons.edit_note_outlined,
    Icons.print_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _step = 0;
    _pageCtrl = PageController(initialPage: 0);
    if (widget.visitId != null) {
      _visitLoading = true;
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [
      _prevHistoryCtrl, _complaintCtrl,
      _examGeneralCtrl, _examNeurologicalCtrl,
      _clinicalDiagnosisCtrl, _imagingCtrl, _otherInvestCtrl,
      _diagnosisCtrl, _treatmentCtrl,
      _treatNotesCtrl, _otNotesCtrl, _adviceCtrl, _crossConsultCtrl,
      _investigationToBeDoneCtrl,
      _weightCtrl, _bpCtrl, _tempCtrl,
      _pat1FirstNameCtrl, _pat1LastNameCtrl, _pat1AgeCtrl,
      _pat1PhoneCtrl, _pat1AltPhoneCtrl, _pat1EmailCtrl,
      _pat1AddressCtrl, _pat1IdTypeCtrl, _pat1IdNumberCtrl,
      _pat1WeightCtrl, _pat1BpCtrl, _pat1TempCtrl, _pat1AllergyCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Populate from existing visit (edit mode) ───────────────────────────────
  void _populateFromVisit(VisitEntity v) {
    if (_visitLoaded) return;
    _visitLoaded  = true;
    _visitLoading = false;
    _visitDate = v.visitDate;
    _visitType = v.visitType;

    void set(TextEditingController c, String? val) {
      if (val?.isNotEmpty == true) c.text = val!;
    }
    set(_complaintCtrl,    v.complaints);
    set(_diagnosisCtrl,    v.clinicalImpression);
    set(_treatmentCtrl,    v.plan);
    set(_treatNotesCtrl,   v.notes);

    if (v.examination?.isNotEmpty == true) {
      try {
        final m = jsonDecode(v.examination!) as Map<String, dynamic>;
        void se(TextEditingController c, String k) {
          if (m[k] is String && (m[k] as String).isNotEmpty) c.text = m[k] as String;
        }
        se(_prevHistoryCtrl,         'previousHistory');
        se(_examGeneralCtrl,         'examGeneral');
        se(_examNeurologicalCtrl,    'examNeurological');
        se(_clinicalDiagnosisCtrl,   'clinicalDiagnosis');
        se(_imagingCtrl,             'imaging');
        se(_otherInvestCtrl,         'otherInvestigation');
        // Load structured prescriptions (new format)
        if (m.containsKey('prescriptions')) {
          try {
            final list = jsonDecode(m['prescriptions'] as String) as List;
            _prescriptionRows.clear();
            for (final item in list) {
              if (item is Map<String, dynamic>) {
                _prescriptionRows.add(_PrescriptionRow.fromJson(item));
              }
            }
          } catch (_) {}
        }
        // Backward compat: plain text medications → name-only rows
        if (_prescriptionRows.isEmpty && (m['medications'] as String? ?? '').isNotEmpty) {
          final lines = (m['medications'] as String).split('\n')
              .where((l) => l.trim().isNotEmpty);
          for (final line in lines) {
            _prescriptionRows.add(_PrescriptionRow(medicine: line.trim()));
          }
        }
        se(_otNotesCtrl,                'otNotes');
        se(_adviceCtrl,                 'advice');
        se(_investigationToBeDoneCtrl,  'investigationToBeDone');
        se(_crossConsultCtrl,           'crossConsultation');
        se(_bpCtrl,                  'bp');
        se(_weightCtrl,              'weight');
        se(_tempCtrl,                'temperature');
      } catch (_) {}
    }
    setState(() {});
  }

  void _populatePatientFields(PatientEntity patient) {
    if (_patientFieldsPopulated) return;
    _patientFieldsPopulated = true;
    _pat1FirstNameCtrl.text = patient.firstName;
    _pat1LastNameCtrl.text  = patient.lastName;
    _pat1AgeCtrl.text       = patient.age?.toString() ?? '';
    _pat1PhoneCtrl.text     = patient.phone ?? '';
    _pat1AltPhoneCtrl.text  = patient.altPhone ?? '';
    _pat1EmailCtrl.text     = patient.email ?? '';
    _pat1AddressCtrl.text   = patient.address ?? '';
    _pat1IdTypeCtrl.text    = patient.idProofType ?? '';
    _pat1IdNumberCtrl.text  = patient.idProofNumber ?? '';
    _pat1Gender             = patient.sex?.isNotEmpty == true ? patient.sex : null;
    _pat1WeightCtrl.text    = patient.weight ?? '';
    _pat1BpCtrl.text        = patient.bloodPressure ?? '';
    _pat1TempCtrl.text      = patient.temperature ?? '';
    _pat1AllergyCtrl.text   = patient.allergies ?? '';
    // Seed visit-level vitals from patient record only when no exam JSON has already
    // set them (se() runs before this — for new visits _weightCtrl is still empty).
    if (_weightCtrl.text.isEmpty) _weightCtrl.text = patient.weight ?? '';
    if (_bpCtrl.text.isEmpty)     _bpCtrl.text     = patient.bloodPressure ?? '';
    if (_tempCtrl.text.isEmpty)   _tempCtrl.text    = patient.temperature ?? '';
  }

  Future<void> _savePatientEdits(PatientEntity original) async {
    if (!_patientFieldsPopulated || _patient == null) return;
    String? _v(String s) => s.trim().isEmpty ? null : s.trim();
    final fn = _pat1FirstNameCtrl.text.trim();
    // Construct directly so cleared fields become null (copyWith uses ?? which ignores null)
    final updated = PatientEntity(
      id:            original.id,
      prn:           original.prn,
      firstName:     fn.isNotEmpty ? fn : original.firstName,
      lastName:      _pat1LastNameCtrl.text.trim(),
      age:           _v(_pat1AgeCtrl.text) == null ? null : int.tryParse(_pat1AgeCtrl.text.trim()),
      dateOfBirth:   original.dateOfBirth,
      sex:           _pat1Gender?.toLowerCase(),
      phone:         _v(_pat1PhoneCtrl.text),
      altPhone:      _v(_pat1AltPhoneCtrl.text),
      email:         _v(_pat1EmailCtrl.text),
      address:       _v(_pat1AddressCtrl.text),
      idProofType:   _v(_pat1IdTypeCtrl.text),
      idProofNumber: _v(_pat1IdNumberCtrl.text),
      weight:        _v(_weightCtrl.text),
      bloodPressure: _v(_bpCtrl.text),
      temperature:   _v(_tempCtrl.text),
      allergies:     _v(_pat1AllergyCtrl.text),
      medicalHistory:  original.medicalHistory,
      previousHistory: original.previousHistory,
      opdType:       original.opdType,
      notes:         original.notes,
      isActive:      original.isActive,
      createdAt:     original.createdAt,
      updatedAt:     original.updatedAt,
      createdBy:     original.createdBy,
      updatedBy:     original.updatedBy,
      syncStatus:    original.syncStatus,
    );
    await ref.read(patientsProvider.notifier).updatePatient(updated);
    _patient = updated;
  }

  // ── Build examination JSON ────────────────────────────────────────────────
  String? _buildExamination() {
    final m = <String, String>{};
    void add(String k, String v) { if (v.isNotEmpty) m[k] = v; }
    add('previousHistory',   _prevHistoryCtrl.text.trim());
    add('examGeneral',       _examGeneralCtrl.text.trim());
    add('examNeurological',  _examNeurologicalCtrl.text.trim());
    add('clinicalDiagnosis', _clinicalDiagnosisCtrl.text.trim());
    add('imaging',           _imagingCtrl.text.trim());
    add('otherInvestigation',_otherInvestCtrl.text.trim());
    // Store structured prescriptions as JSON array
    if (_prescriptionRows.isNotEmpty) {
      m['prescriptions'] = jsonEncode(_prescriptionRows.map((r) => r.toJson()).toList());
      add('medications', _prescriptionRows.map((r) =>
          '${r.medicine}${r.dose.isNotEmpty ? " [${r.dose}]" : ""}${r.route.isNotEmpty ? " (${r.route})" : ""}${r.frequency.isNotEmpty ? " - ${r.frequency}" : ""}${r.duration.isNotEmpty ? " × ${r.duration}" : ""}${r.specialInstruction.isNotEmpty ? " | ${r.specialInstruction}" : ""}').join('\n'));
    }
    add('otNotes',               _otNotesCtrl.text.trim());
    add('advice',                _adviceCtrl.text.trim());
    add('investigationToBeDone', _investigationToBeDoneCtrl.text.trim());
    add('crossConsultation',     _crossConsultCtrl.text.trim());
    add('bp',                _bpCtrl.text.trim());
    add('weight',            _weightCtrl.text.trim());
    add('temperature',       _tempCtrl.text.trim());
    return m.isEmpty ? null : jsonEncode(m);
  }

  // ── Validate at least one treatment field is filled ───────────────────────
  bool _hasAnyTreatmentData() {
    final ctrls = [
      _prevHistoryCtrl, _complaintCtrl,
      _examGeneralCtrl, _examNeurologicalCtrl,
      _clinicalDiagnosisCtrl, _imagingCtrl, _otherInvestCtrl,
      _diagnosisCtrl, _treatmentCtrl,
      _treatNotesCtrl, _otNotesCtrl, _adviceCtrl,
      _weightCtrl, _bpCtrl, _tempCtrl,
    ];
    return ctrls.any((c) => c.text.trim().isNotEmpty) ||
        _prescriptionRows.isNotEmpty           ||
        _prevHistoryFiles.isNotEmpty           || _chiefComplaintFiles.isNotEmpty ||
        _examGeneralFiles.isNotEmpty           || _examNeurologicalFiles.isNotEmpty ||
        _clinicalDiagnosisFiles.isNotEmpty     || _imagingFiles.isNotEmpty ||
        _otherInvestFiles.isNotEmpty           || _impressionFiles.isNotEmpty ||
        _planFiles.isNotEmpty                  || _treatmentMedFiles.isNotEmpty ||
        _investigationToBeDoneFiles.isNotEmpty || _crossConsultFiles.isNotEmpty;
  }

  // ── Upload all files picked in the wizard for a given visitId ────────────
  Future<void> _uploadVisitFiles(String visitId) async {
    final notifier = ref.read(photoProvider(widget.patientId).notifier);
    // 3-tuple: (files, category, sectionLabel) — sectionLabel stored as caption
    final batches = <(List<({String name, Uint8List bytes})>, PhotoCategory, String)>[
      (_prevHistoryFiles,       PhotoCategory.visit,       'Previous History'),
      (_chiefComplaintFiles,    PhotoCategory.visit,       'Chief Complaint'),
      (_examGeneralFiles,       PhotoCategory.examination, 'General Examination'),
      (_examNeurologicalFiles,  PhotoCategory.examination, 'Neurological Examination'),
      (_clinicalDiagnosisFiles, PhotoCategory.visit,       'Clinical Diagnosis'),
      (_imagingFiles,           PhotoCategory.radiology,   'Imaging'),
      (_otherInvestFiles,       PhotoCategory.visit,       'Other Investigation'),
      (_impressionFiles,        PhotoCategory.treatment,   'Impression'),
      (_planFiles,              PhotoCategory.treatment,   'Treatment Plan'),
      (_treatmentMedFiles,             PhotoCategory.treatment,   'Medicines'),
      (_investigationToBeDoneFiles,    PhotoCategory.visit,       'Investigation to be done'),
      (_crossConsultFiles,             PhotoCategory.visit,       'Cross Consultation'),
    ];

    int uploaded = 0;
    final List<String> failed = [];

    for (final batch in batches) {
      for (final f in batch.$1) {
        final result = await notifier.upload(
          bytes:    f.bytes,
          filename: f.name,
          category: batch.$2,
          visitId:  visitId,
          caption:  batch.$3,  // section label stored as caption
        );
        if (result != null) {
          uploaded++;
        } else {
          // Read error from provider state
          final err = ref.read(photoProvider(widget.patientId)).error;
          failed.add('${f.name}: ${err ?? 'unknown error'}');
        }
      }
    }

    if (!mounted) return;
    if (failed.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$uploaded file(s) uploaded. ${failed.length} failed:',
                style: TextStyle(fontWeight: FontWeight.w700,
                    color: Colors.white, fontSize: 13)),
            const SizedBox(height: 4),
            ...failed.map((e) => Text(e,
                style: TextStyle(color: Colors.white70, fontSize: 11))),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else if (uploaded > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$uploaded file(s) uploaded successfully',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _kBlue2,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── Save / Create visit ───────────────────────────────────────────────────
  Future<void> _save() async {
    if (_saving) return;
    // For new visits: once saved, block re-entry even if the user navigates
    // back to step 1 and taps the button again before _step updates.
    if (widget.visitId == null && _savedVisit != null) return;
    _saving = true; // set synchronously before any await so rapid taps are blocked
    final isNew = widget.visitId == null;

    if (isNew && !ref.read(isStaffProvider) && !_hasAnyTreatmentData()) {
      _saving = false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(Icons.info_outline, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Please fill at least one treatment field to save the visit.',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _kAmber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    setState(() {}); // trigger rebuild to show spinner

    try {
      String? nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

      if (isNew) {
        // Timeout guards against a SQLite hang leaving the spinner frozen forever.
        final visit = await ref
            .read(visitsProvider(widget.patientId).notifier)
            .createFullVisit(
              patientId:          widget.patientId,
              type:               _visitType,
              visitDate:          _visitDate,
              complaints:         nullIfEmpty(_complaintCtrl.text),
              examination:        _buildExamination(),
              clinicalImpression: nullIfEmpty(_diagnosisCtrl.text),
              plan:               nullIfEmpty(_treatmentCtrl.text),
              notes:              nullIfEmpty(_treatNotesCtrl.text),
            )
            .timeout(const Duration(seconds: 12), onTimeout: () => null);

        if (!mounted) return;

        if (visit != null) {
          // Persist prescription for offline medicine history
          final medNames = _prescriptionRows.map((r) =>
              '${r.medicine}${r.dose.isNotEmpty ? " [${r.dose}]" : ""}${r.route.isNotEmpty ? " (${r.route})" : ""}${r.frequency.isNotEmpty ? " - ${r.frequency}" : ""}${r.duration.isNotEmpty ? " × ${r.duration}" : ""}').join('\n');
          if (medNames.isNotEmpty) {
            unawaited(ref.read(medicineServiceProvider).savePrescription(
              visitId: visit.id,
              patientId: widget.patientId,
              visitDate: _visitDate,
              medicationsText: medNames,
            ));
          }
          // Keep _saving = true (button disabled) during file upload so a
          // second tap cannot create a duplicate visit while files are uploading.
          await _uploadVisitFiles(visit.id);
          if (_patient != null) {
            await _savePatientEdits(_patient!);
            ref.invalidate(patientByIdProvider(widget.patientId));
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Visit saved  ·  ${DateFormat('dd MMM yyyy').format(_visitDate)}',
                style: TextStyle(fontWeight: FontWeight.w600),
              )),
            ]),
            backgroundColor: _kBlue2,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ));
          // Atomically: reset spinner + record saved visit + advance to review.
          // Doing this in one setState prevents any intermediate frame where the
          // Save button is re-enabled while still on step 1.
          setState(() {
            _saving    = false;
            _savedVisit = visit;
            _justSaved  = true;
            _step       = 1;
          });
          unawaited(_pageCtrl.animateToPage(1,
              duration: const Duration(milliseconds: 300), curve: Curves.easeInOut));
        } else {
          if (mounted) setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to save visit. Please try again.'),
            backgroundColor: _kRed,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        // Edit mode – update existing visit
        final editNotifier = ref.read(visitEditProvider('${widget.patientId}/${widget.visitId!}').notifier);
        final current      = ref.read(visitEditProvider('${widget.patientId}/${widget.visitId!}'));
        if (current == null) return;

        // Construct directly so cleared fields become null (copyWith uses ?? which ignores null)
        editNotifier.update(VisitEntity(
          id:                 current.id,
          patientId:          current.patientId,
          visitDate:          _visitDate,
          visitType:          _visitType,
          complaints:         nullIfEmpty(_complaintCtrl.text),
          examination:        _buildExamination(),
          clinicalImpression: nullIfEmpty(_diagnosisCtrl.text),
          plan:               nullIfEmpty(_treatmentCtrl.text),
          notes:              nullIfEmpty(_treatNotesCtrl.text),
          bp:                 nullIfEmpty(_bpCtrl.text),
          temperature:        nullIfEmpty(_tempCtrl.text),
          weight:             nullIfEmpty(_weightCtrl.text),
          status:             'completed',
          isActive:           current.isActive,
          createdAt:          current.createdAt,
          updatedAt:          current.updatedAt,
          createdBy:          current.createdBy,
          updatedBy:          current.updatedBy,
          syncStatus:         current.syncStatus,
        ));
        final ok = await editNotifier.save()
            .timeout(const Duration(seconds: 12), onTimeout: () => false);
        if (!mounted) return;

        if (ok) {
          final medNamesEdit = _prescriptionRows.map((r) => r.medicine).join('\n');
          if (medNamesEdit.isNotEmpty) {
            unawaited(ref.read(medicineServiceProvider).savePrescription(
              visitId: widget.visitId!,
              patientId: widget.patientId,
              visitDate: _visitDate,
              medicationsText: medNamesEdit,
            ));
          }
          // Keep _saving = true during file upload (same fix as new-visit path).
          await _uploadVisitFiles(widget.visitId!);
          if (_patient != null) {
            await _savePatientEdits(_patient!);
            ref.invalidate(patientByIdProvider(widget.patientId));
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Visit updated  ·  ${DateFormat('dd MMM yyyy').format(_visitDate)}',
                style: TextStyle(fontWeight: FontWeight.w600),
              )),
            ]),
            backgroundColor: _kBlue2,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ));
          final updatedVisit = ref.read(visitEditProvider('${widget.patientId}/${widget.visitId!}'));
          // Push the updated entity into the visits list so the patient detail
          // card reflects the new data without requiring navigation away.
          if (updatedVisit != null) {
            ref.read(visitsProvider(widget.patientId).notifier).replaceInList(updatedVisit);
          }
          setState(() {
            _saving    = false;
            _justSaved  = true;
            _savedVisit = updatedVisit;
            _step       = 1;
          });
          unawaited(_pageCtrl.animateToPage(1,
              duration: const Duration(milliseconds: 300), curve: Curves.easeInOut));
        } else {
          if (mounted) setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to update visit. Please try again.'),
            backgroundColor: _kRed,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save visit. Please try again.'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      // Always reset the spinner — no exception or navigation can leave it stuck.
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  void _nextStep() {
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  // Free navigation between all steps — no save triggered by tab tap.
  void _goToStep(int target) {
    if (target == _step) return;
    setState(() => _step = target);
    _pageCtrl.animateToPage(target,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _openPrint() {
    if (_patient == null) return;
    final visit = _savedVisit;
    if (visit == null) return;
    // Build print data map from patient + visit
    final patNotes = <String, String>{};
    if (_patient!.notes?.isNotEmpty == true) {
      try {
        final decoded = jsonDecode(_patient!.notes!) as Map<String, dynamic>;
        patNotes.addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
      } catch (_) {}
    }
    String pn(String k) => patNotes[k]?.isNotEmpty == true ? patNotes[k]! : '—';
    final fullName = '${_patient!.firstName} ${_patient!.lastName}'.trim();
    final gender   = _patient!.sex?.isNotEmpty == true
        ? '${_patient!.sex![0].toUpperCase()}${_patient!.sex!.substring(1)}'
        : '—';

    ref.read(activePatientDataProvider.notifier).state = {
      'firstName':      _patient!.firstName,
      'lastName':       _patient!.lastName,
      'date':           DateFormat('dd-MM-yyyy  hh:mm a').format(_visitDate),
      'gender':         gender,
      'phone':          _patient!.phone ?? '—',
      'age':            _patient!.age != null ? '${_patient!.age} yrs' : '—',
      'address':        _patient!.address ?? '—',
      'email':          pn('email'),
      'weight':         _weightCtrl.text.trim(),
      'bloodPressure':  _bpCtrl.text.trim(),
      'temperature':    _tempCtrl.text.trim(),
      'allergies':      _pat1AllergyCtrl.text.trim().isNotEmpty ? _pat1AllergyCtrl.text.trim() : (_patient?.allergies?.isNotEmpty == true ? _patient!.allergies! : pn('allergies')),
      'medicalHistory': pn('clinicalNotes'),
      'previousHistory':_prevHistoryCtrl.text.trim(),
      'chiefComplaint': _complaintCtrl.text.trim(),
      'examGeneral':    _examGeneralCtrl.text.trim(),
      'examNeurological': _examNeurologicalCtrl.text.trim(),
      'clinicalDiagnosis': _clinicalDiagnosisCtrl.text.trim(),
      'imaging':        _imagingCtrl.text.trim(),
      'otherInvestigation': _otherInvestCtrl.text.trim(),
      'diagnosis':      _diagnosisCtrl.text.trim(),
      'treatmentPlan':  _treatmentCtrl.text.trim(),
      'medications':    _prescriptionRows.map((r) =>
          '${r.medicine}${r.dose.isNotEmpty ? " [${r.dose}]" : ""}${r.route.isNotEmpty ? " (${r.route})" : ""}${r.frequency.isNotEmpty ? " - ${r.frequency}" : ""}${r.specialInstruction.isNotEmpty ? " — ${r.specialInstruction}" : ""}').join('\n'),
      'otNotes':             _otNotesCtrl.text.trim(),
      'advice':              _adviceCtrl.text.trim(),
      'investigationToBeDone': _investigationToBeDoneCtrl.text.trim(),
      'crossConsultation':   _crossConsultCtrl.text.trim(),
      'visitType':      visit.visitType.label,
    };
    context.push('/print-config');
  }

  // ── File helpers ──────────────────────────────────────────────────────────
  Widget _fileChip(String name, VoidCallback onClear) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _kBlue.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kBlue.withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      Icon(Icons.insert_drive_file_rounded, color: _kBlue, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text(name,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy(context)),
          overflow: TextOverflow.ellipsis)),
      GestureDetector(onTap: onClear,
          child: Icon(Icons.close_rounded, size: 14, color: _kMuted(context))),
    ]),
  );

  String _makeFileName(String section, String originalName, {int index = 0}) {
    final now = DateTime.now();
    final ts = '${now.day.toString().padLeft(2, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.year}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final ext = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'jpg';
    final prn = (_patient?.prn ?? widget.patientId).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final sec = section.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final suffix = index > 0 ? '_$index' : '';
    return '${prn}_${sec}_$ts$suffix.$ext';
  }

  Future<void> _pickFiles(
      void Function(List<({String name, Uint8List bytes})>) onPicked, {
      String sectionName = '',
  }) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _kCard(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16,
            16 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: _kBorder(ctx), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Add Attachment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: _kNavy(ctx))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _mediaOptionTile(ctx, 'Camera',
                Icons.camera_alt_rounded, _kBlue, 'camera')),
            const SizedBox(width: 12),
            Expanded(child: _mediaOptionTile(ctx, 'Gallery / Files',
                Icons.photo_library_outlined, _kGreen, 'gallery')),
          ]),
        ]),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'camera') {
      try {
        final picker = ImagePicker();
        final img = await picker.pickImage(
            source: ImageSource.camera, imageQuality: 85);
        if (img == null || !mounted) return;
        final bytes = await img.readAsBytes();
        final name = _makeFileName(sectionName, 'photo.jpg');
        onPicked([(name: name, bytes: bytes)]);
      } catch (_) {}
    } else {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
          withData: true,
          allowMultiple: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final valid = result.files.where((f) => f.bytes != null).toList();
          final multi = valid.length > 1;
          final picked = valid.asMap().entries
              .map((e) => (
                    name: _makeFileName(sectionName, e.value.name,
                        index: multi ? e.key + 1 : 0),
                    bytes: e.value.bytes!,
                  ))
              .toList();
          if (picked.isNotEmpty) onPicked(picked);
        }
      } catch (_) {}
    }
  }

  Widget _mediaOptionTile(BuildContext ctx, String label, IconData icon,
      Color color, String value) =>
      GestureDetector(
        onTap: () => Navigator.pop(ctx, value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: color)),
          ]),
        ),
      );

  Widget _fieldWithUpload({
    required String label,
    required TextEditingController controller,
    required List<({String name, Uint8List bytes})> files,
    required void Function(List<({String name, Uint8List bytes})>) onFilesChange,
    List<PhotoEntity> existingPhotos = const [],
    int maxLines = 2,
    IconData prefixIcon = Icons.notes_rounded,
    String hint = '',
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate(context))),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(fontSize: 14, color: _kNavy(context), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
          prefixIcon: Icon(prefixIcon, size: 17, color: _kMuted(context)),
          suffixIcon: Tooltip(
            message: 'Upload files',
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(Icons.upload_file_rounded, size: 20,
                      color: files.isNotEmpty ? _kBlue : _kMuted(context)),
                  onPressed: () => _pickFiles((picked) =>
                      setState(() => onFilesChange([...files, ...picked])),
                      sectionName: label),
                ),
                if (files.isNotEmpty)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      width: 15, height: 15,
                      decoration: BoxDecoration(
                          color: _kBlue, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${files.length}',
                          style: TextStyle(
                              color: Colors.white, fontSize: 8,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
          filled: true, fillColor: _kBg(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _kBorder(context))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _kBorder(context))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _kP1, width: 1.5)),
        ),
      ),
      if (files.isNotEmpty) ...[
        const SizedBox(height: 6),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: List.generate(files.length, (idx) {
            final f = files[idx];
            return _fileChip(f.name, () => setState(() {
              final updated = List<({String name, Uint8List bytes})>.from(files);
              updated.removeAt(idx);
              onFilesChange(updated);
            }));
          }),
        ),
      ],
      if (existingPhotos.isNotEmpty) ...[
        const SizedBox(height: 6),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: existingPhotos.map(_existingPhotoChip).toList(),
        ),
      ],
    ]);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(patientByIdProvider(widget.patientId));
    patientAsync.whenData((p) { if (p != null && _patient == null) _patient = p; });

    // Reactively set Follow-up once visits load (for new visit only)
    if (widget.visitId == null && !_visitTypeResolved) {
      final existing = ref.watch(visitsProvider(widget.patientId));
      if (existing.isNotEmpty) {
        _visitTypeResolved = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _visitType = VisitType.followUp);
        });
      }
    }

    if (widget.visitId != null) {
      final visit = ref.watch(visitEditProvider('${widget.patientId}/${widget.visitId!}'));
      if (visit != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _populateFromVisit(visit));
      }
    }

    final vp      = MediaQuery.of(context).viewPadding;
    return Scaffold(
      backgroundColor: _kBg(context),
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: _buildBottomNav(),
      body: Column(children: [
        SizedBox(height: vp.top),
        _buildWizardHeader(),
        _buildStepBar(),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(patientAsync),
              _buildStep3(),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Wizard header ─────────────────────────────────────────────────────────
  Widget _buildWizardHeader() => Container(
    color: _kCard(context),
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
    child: Row(children: [
      IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 18, color: _kNavy(context)),
        onPressed: () {
          if (_step == 1) {
            // If saved/edit mode: go to patient timeline; if unsaved draft: go back to form
            final isUnsaved = _savedVisit == null && widget.visitId == null;
            if (isUnsaved) {
              _prevStep();
            } else {
              context.go('/patients/${widget.patientId}');
            }
          } else if (_step == 0) {
            context.pop();
          } else {
            _prevStep();
          }
        },
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.visitId == null ? 'New Visit' : 'Visit Details',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: _kNavy(context), letterSpacing: -0.3),
          ),
          Text(_stepSubtitles[_step],
              style: TextStyle(fontSize: 12, color: _kMuted(context))),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Step ${_step + 1} of 2',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    ]),
  );

  // ── Step bar ──────────────────────────────────────────────────────────────
  Widget _buildStepBar() => Container(
    color: _kCard(context),
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_stepLabels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final segIdx = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 15),
                color: segIdx < _step ? _kBlue : _kBorder(context),
              ),
            );
          }
          final idx      = i ~/ 2;
          final isDone    = idx < _step;
          final isCurrent = idx == _step;
          return GestureDetector(
            onTap: () => _goToStep(idx),
            behavior: HitTestBehavior.opaque,
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (isDone || isCurrent) ? _kBlue : _kCard(context),
                  shape: BoxShape.circle,
                  border: (isDone || isCurrent)
                      ? null
                      : Border.all(color: _kBorder(context), width: 1.5),
                  boxShadow: (isDone || isCurrent)
                      ? [BoxShadow(
                          color: _kBlue.withValues(alpha: 0.4),
                          blurRadius: 8, offset: const Offset(0, 3))]
                      : null,
                ),
                alignment: Alignment.center,
                child: isDone
                    ? Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : Text('${idx + 1}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: isCurrent ? Colors.white : _kMuted(context))),
              ),
              const SizedBox(height: 4),
              Text(_stepLabels[idx],
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w600,
                      color: isCurrent ? _kBlue : isDone ? _kSlate(context) : _kMuted(context),
                      letterSpacing: 0.1)),
            ]),
          );
        }),
        // Print icon shortcut (active only on step 3)
        GestureDetector(
          onTap: _step == 1 ? _openPrint : null,
          child: Container(
            margin: const EdgeInsets.only(left: 10),
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _step == 1
                  ? _kBlue.withValues(alpha: 0.15)
                  : _kWiz(context),
              shape: BoxShape.circle,
              border: Border.all(
                  color: _step == 1 ? _kBlue : _kBorder(context), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.open_in_new_rounded, size: 14,
                color: _step == 1 ? _kBlue : _kMuted(context)),
          ),
        ),
      ],
    ),
  );

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isPreview = _step == 1;
    final isLast    = _step == 0;

    return Container(
      color: _kCard(context),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!isPreview) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / 3,
              minHeight: 3,
              backgroundColor: _kBorder(context),
              color: _kBlue,
            ),
          ),
          const SizedBox(height: 10),
          // Back + primary action on one row
          Row(children: [
            if (_step > 0) ...[
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _prevStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kSlate(context),
                    side: BorderSide(color: _kBorder(context), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : (isLast ? _save : _nextStep),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _kBlue.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(isLast
                          ? Icons.check_circle_outline_rounded
                          : Icons.arrow_forward_rounded,
                          size: 18),
                  label: _saving
                      ? const SizedBox.shrink()
                      : Text(isLast
                          ? (widget.visitId == null ? 'Save Visit' : 'Update Visit')
                          : 'Continue'),
                ),
              ),
            ),
          ]),
        ] else ...[
          // Preview step: Edit + Go to Patient
          Row(children: [
            if (widget.visitId != null) ...[
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _step = 0);
                      _pageCtrl.jumpToPage(0);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSlate(context),
                      side: BorderSide(color: _kBorder(context), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => context.go('/patients/${widget.patientId}'),
                  icon: const Icon(Icons.person_outlined, size: 17),
                  label: const Text('Patient'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }


  // ── Editable field for Step 1 patient card ───────────────────────────────
  Widget _editField(String label, TextEditingController ctrl, {
    TextInputType? keyboard, int maxLines = 1, String hint = '',
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: _kMuted(context))),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboard,
          style: TextStyle(
              fontSize: 13, color: _kNavy(context), fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint.isNotEmpty ? hint : null,
            hintStyle: TextStyle(color: _kMuted(context), fontSize: 12),
            filled: true, fillColor: _kBg(context),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _kBorder(context))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _kBorder(context))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _kBlue, width: 1.5)),
          ),
        ),
      ]);

  Widget _pat1GenderDropdown() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Gender', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: _kMuted(context))),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _pat1Gender,
          dropdownColor: _kCard(context),
          iconEnabledColor: _kMuted(context),
          items: ['male', 'female', 'other']
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(
                        '${g[0].toUpperCase()}${g.substring(1)}',
                        style: TextStyle(color: _kNavy(context), fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _pat1Gender = v),
          decoration: InputDecoration(
            filled: true, fillColor: _kBg(context),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _kBorder(context))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _kBorder(context))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _kBlue, width: 1.5)),
          ),
          style: TextStyle(
              fontSize: 13, color: _kNavy(context), fontWeight: FontWeight.w500),
        ),
      ]);

  // ── Step 1 : Patient Info (editable) ──────────────────────────────────────
  Widget _buildStep1(AsyncValue<PatientEntity?> patientAsync) {
    // Photo setup (needed for step-2 sections, must be unconditional ref.watch)
    final allPtPhotos = ref.watch(photoProvider(widget.patientId)).photos;
    // Build visitPhotos with same logic as visit_view_screen:
    // linked photos first, then orphans (visitId=null), deduplicated by storagePath.
    final _seenPaths = <String>{};
    final visitPhotos = <PhotoEntity>[];
    if (widget.visitId != null) {
      for (final p in allPtPhotos.where((p) => p.visitId == widget.visitId)) {
        if (_seenPaths.add(p.storagePath)) visitPhotos.add(p);
      }
    }
    // Include orphan photos by caption so old uploads show in the right section.
    for (final p in allPtPhotos.where((p) =>
        (p.visitId == null || p.visitId!.isEmpty) &&
        (p.surgeryId == null || p.surgeryId!.isEmpty) &&
        p.category != PhotoCategory.patientReport)) {
      if (_seenPaths.add(p.storagePath)) visitPhotos.add(p);
    }
    List<PhotoEntity> ep(String caption) =>
        visitPhotos.where((p) => p.caption == caption).toList();
    const knownCaptions = {
      'Previous History', 'Chief Complaint', 'General Examination',
      'Neurological Examination', 'Imaging', 'Other Investigation',
      'Impression', 'Treatment Plan', 'Medicines',
      'Cross Consultation', 'Clinical Diagnosis',
    };
    final orphanPhotos = visitPhotos
        .where((p) => p.caption == null || !knownCaptions.contains(p.caption))
        .toList();

    return patientAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kBlue)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (patient) {
        if (patient == null) {
          return const Center(child: Text('Patient not found'));
        }

        _populatePatientFields(patient);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Visit Date & Type ────────────────────────────────────────
            _WizardCard(
              title: 'Visit Details',
              icon: Icons.calendar_today_outlined,
              color: _kBlue,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Visit Date (tap to pick)
                Expanded(
                  flex: 5,
                  child: GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _visitDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        builder: (c, w) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(primary: _kBlue),
                          ),
                          child: w!,
                        ),
                      );
                      if (d != null) setState(() => _visitDate = d);
                    },
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Visit Date',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: _kSlate(context))),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: _kWiz(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kBorder(context)),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 15, color: _kBlue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM yyyy').format(_visitDate),
                              style: TextStyle(fontSize: 13, color: _kNavy(context),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(Icons.edit_outlined, size: 13, color: _kMuted(context)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                // Visit Type
                Expanded(
                  flex: 5,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Visit Type',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: _kSlate(context))),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      value: _visitType.label,
                      dropdownColor: _kCard(context),
                      iconEnabledColor: _kMuted(context),
                      isExpanded: true,
                      items: _kVisitTypeLabels
                          .map((l) => DropdownMenuItem(
                                value: l,
                                child: Text(l,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: _kNavy(context), fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _visitType = switch (v) {
                          'Emergency' => VisitType.emergency,
                          'Follow-up' => VisitType.followUp,
                          _           => VisitType.opd,
                        });
                      },
                      decoration: InputDecoration(
                        filled: true, fillColor: _kWiz(context),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _kBorder(context))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _kBorder(context))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: _kBlue, width: 1.5)),
                      ),
                      style: TextStyle(
                          fontSize: 13, color: _kNavy(context), fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ]),
            ),

            // ── Patient Basic Info (editable) ─────────────────────────────
            _WizardCard(
              title: 'Basic Information',
              icon: Icons.person_outline_rounded,
              color: _kBlue,
              child: Column(children: [
                Row(children: [
                  Expanded(child: _editField('First Name', _pat1FirstNameCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _editField('Last Name', _pat1LastNameCtrl)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _editField('Age', _pat1AgeCtrl,
                      keyboard: TextInputType.number, hint: 'yrs')),
                  const SizedBox(width: 12),
                  Expanded(child: _pat1GenderDropdown()),
                ]),
                const SizedBox(height: 10),
                _roRow('UHID', patient.prn),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _editField('Phone', _pat1PhoneCtrl,
                      keyboard: TextInputType.phone)),
                  const SizedBox(width: 12),
                  Expanded(child: _editField('Alt Phone', _pat1AltPhoneCtrl,
                      keyboard: TextInputType.phone)),
                ]),
                const SizedBox(height: 10),
                _editField('Email', _pat1EmailCtrl,
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _editField('Address', _pat1AddressCtrl, maxLines: 2),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _editField('ID Proof Type', _pat1IdTypeCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _editField('ID Number', _pat1IdNumberCtrl)),
                ]),
              ]),
            ),

            // ── Vitals ─────────────────────────────────────────────────────
            _WizardCard(
              title: 'Vitals',
              icon: Icons.monitor_heart_outlined,
              color: _kBlue,
              child: Row(children: [
                Expanded(child: _editField('Weight', _weightCtrl, hint: 'kg')),
                const SizedBox(width: 12),
                Expanded(child: _editField('Blood Pressure', _bpCtrl, hint: 'mmHg')),
                const SizedBox(width: 12),
                Expanded(child: _editField('Temperature', _tempCtrl, hint: '°F')),
              ]),
            ),

            // Known Allergies — visible for all roles
            const SizedBox(height: 6),
            _WizardCard(
              title: 'Known Allergies',
              icon: Icons.warning_amber_outlined,
              color: _kBlue,
              child: _editField('Known Allergies', _pat1AllergyCtrl,
                  maxLines: 2, hint: 'e.g. Penicillin, Sulfa drugs'),
            ),

            // ════════════════════════════════════════════════════════
            // Treatment & Advice section — hidden for staff role
            // ════════════════════════════════════════════════════════
            if (!ref.read(isStaffProvider)) ...[

            const SizedBox(height: 6),

            // 2. Chief Complaint
            _WizardCard(
              title: 'Chief Complaint',
              icon: Icons.report_problem_outlined,
              color: _kBlue,
              child: _fieldWithUpload(
                label: 'Chief Complaint',
                controller: _complaintCtrl,
                files: _chiefComplaintFiles,
                onFilesChange: (f) => _chiefComplaintFiles..clear()..addAll(f),
                existingPhotos: ep('Chief Complaint'),
                prefixIcon: Icons.report_problem_outlined,
                hint: 'Primary reason for visit…',
              ),
            ),

            // 3. Previous History
            _WizardCard(
              title: 'Previous History',
              icon: Icons.history_edu_outlined,
              color: _kBlue,
              child: _fieldWithUpload(
                label: 'Previous History',
                controller: _prevHistoryCtrl,
                files: _prevHistoryFiles,
                onFilesChange: (f) => _prevHistoryFiles..clear()..addAll(f),
                existingPhotos: ep('Previous History'),
                prefixIcon: Icons.history_edu_outlined,
                hint: 'Enter previous medical history…',
              ),
            ),

            // 4. Examination Finding
            _WizardCard(
              title: 'Examination Finding',
              icon: Icons.person_search_outlined,
              color: _kBlue,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _examTab = 'general'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _examTab == 'general' ? _kBlue : _kCard(context),
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10)),
                          border: Border.all(
                              color: _examTab == 'general' ? _kBlue : _kBorder(context)),
                        ),
                        alignment: Alignment.center,
                        child: Text('General',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: _examTab == 'general' ? Colors.white : _kSlate(context))),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _examTab = 'neurological'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _examTab == 'neurological' ? _kBlue : _kCard(context),
                          borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10)),
                          border: Border.all(
                              color: _examTab == 'neurological' ? _kBlue : _kBorder(context)),
                        ),
                        alignment: Alignment.center,
                        child: Text('Neurological',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: _examTab == 'neurological' ? Colors.white : _kSlate(context))),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                if (_examTab == 'general') ...[
                  _fieldWithUpload(
                    label: 'General Examination',
                    controller: _examGeneralCtrl,
                    files: _examGeneralFiles,
                    onFilesChange: (f) => _examGeneralFiles..clear()..addAll(f),
                    existingPhotos: ep('General Examination'),
                    prefixIcon: Icons.person_search_outlined,
                    hint: 'General examination findings…',
                    maxLines: 3,
                  ),
                ] else ...[
                  _fieldWithUpload(
                    label: 'Neurological Examination',
                    controller: _examNeurologicalCtrl,
                    files: _examNeurologicalFiles,
                    onFilesChange: (f) => _examNeurologicalFiles..clear()..addAll(f),
                    existingPhotos: ep('Neurological Examination'),
                    prefixIcon: Icons.psychology_outlined,
                    hint: 'Neurological examination findings…',
                    maxLines: 3,
                  ),
                ],
              ]),
            ),

            // 5. Previous Investigations
            _WizardCard(
              title: 'Previous Investigations',
              icon: Icons.science_outlined,
              color: _kBlue,
              child: Column(children: [
                _fieldWithUpload(
                  label: 'Imaging',
                  controller: _imagingCtrl,
                  files: _imagingFiles,
                  onFilesChange: (f) => _imagingFiles..clear()..addAll(f),
                  existingPhotos: ep('Imaging'),
                  prefixIcon: Icons.image_search_rounded,
                  hint: 'Imaging findings (X-Ray, MRI, CT…)',
                ),
                const SizedBox(height: 12),
                _fieldWithUpload(
                  label: 'Other Investigations',
                  controller: _otherInvestCtrl,
                  files: _otherInvestFiles,
                  onFilesChange: (f) => _otherInvestFiles..clear()..addAll(f),
                  existingPhotos: ep('Other Investigation'),
                  prefixIcon: Icons.biotech_outlined,
                  hint: 'Lab reports, other tests…',
                ),
              ]),
            ),

            // 6. Impression
            _WizardCard(
              title: 'Impression',
              icon: Icons.lightbulb_outline_rounded,
              color: _kBlue,
              child: _fieldWithUpload(
                label: 'Impression',
                controller: _diagnosisCtrl,
                files: _impressionFiles,
                onFilesChange: (f) => _impressionFiles..clear()..addAll(f),
                existingPhotos: ep('Impression'),
                prefixIcon: Icons.rule_outlined,
                hint: 'Clinical impression / assessment…',
              ),
            ),

            // 7. Treatment Plan
            _WizardCard(
              title: 'Treatment Plan',
              icon: Icons.assignment_outlined,
              color: _kBlue,
              child: _fieldWithUpload(
                label: 'Treatment Plan',
                controller: _treatmentCtrl,
                files: _planFiles,
                onFilesChange: (f) => _planFiles..clear()..addAll(f),
                existingPhotos: ep('Treatment Plan'),
                prefixIcon: Icons.assignment_outlined,
                hint: 'Recommended treatment plan…',
              ),
            ),

            // 8. Medicine / Treatment
            _WizardCard(
              title: 'Medicine / Treatment',
              icon: Icons.medication_outlined,
              color: _kBlue,
              child: _buildMedicationTable(),
            ),

            // 8b. OT Notes
            _WizardCard(
              title: 'OT Notes',
              icon: Icons.local_hospital_outlined,
              color: _kBlue,
              child: _vField(
                label: 'OT Notes',
                controller: _otNotesCtrl,
                maxLines: 4,
                prefixIcon: Icons.local_hospital_outlined,
                hint: 'Operation theatre notes…',
              ),
            ),

            // 9. Advice
            _WizardCard(
              title: 'Advice',
              icon: Icons.tips_and_updates_outlined,
              color: _kBlue,
              child: Column(children: [
                _vField(
                  label: 'Instructions',
                  controller: _adviceCtrl,
                  maxLines: 3,
                  prefixIcon: Icons.tips_and_updates_outlined,
                  hint: 'Instructions given to patient…',
                ),
                const SizedBox(height: 12),
                _fieldWithUpload(
                  label: 'Investigation to be done',
                  controller: _investigationToBeDoneCtrl,
                  files: _investigationToBeDoneFiles,
                  onFilesChange: (f) => _investigationToBeDoneFiles..clear()..addAll(f),
                  existingPhotos: ep('Investigation to be done'),
                  prefixIcon: Icons.assignment_late_outlined,
                  hint: 'Tests / investigations to be done…',
                ),
                const SizedBox(height: 12),
                _fieldWithUpload(
                  label: 'Cross Consultation',
                  controller: _crossConsultCtrl,
                  files: _crossConsultFiles,
                  onFilesChange: (f) => _crossConsultFiles..clear()..addAll(f),
                  existingPhotos: ep('Cross Consultation'),
                  prefixIcon: Icons.people_outline_rounded,
                  hint: 'Referred to / consulted with…',
                ),
              ]),
            ),

            // Doctor's Notes (private)
            _WizardCard(
              title: "Doctor's Notes",
              icon: Icons.lock_outline_rounded,
              color: _kBlue,
              child: _vField(
                label: 'Notes (for your reference only)',
                controller: _treatNotesCtrl,
                maxLines: 4,
                hint: 'Private notes — will not appear on the patient sheet…',
              ),
            ),
            ], // end of Treatment & Advice section (hidden for staff)
          ],
        );
      },
    );
  }

  // Read-only field row for Step 1
  Widget _roRow(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: _kMuted(context))),
      const SizedBox(height: 4),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: _kWiz(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder(context)),
        ),
        child: Text(value,
            style: TextStyle(
                fontSize: 13, color: _kNavy(context), fontWeight: FontWeight.w500)),
      ),
    ],
  );

  // ── Unified photo filename resolver ──────────────────────────────────────────
  // Returns custom filename (PRN_section_ts.ext) if stored, otherwise a
  // readable caption-based fallback for legacy UUID-named photos.
  static final _uuidPat = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-',
      caseSensitive: false);
  // Cloudinary public_id: alphanumeric only, no extension, 12+ chars
  static final _cloudinaryPat = RegExp(r'^[a-zA-Z0-9]{12,}$');

  bool _isRandom(String s) =>
      _uuidPat.hasMatch(s) ||
      (!s.contains('.') && _cloudinaryPat.hasMatch(s));

  String _resolvePhotoName(PhotoEntity p) {
    final orig = p.originalFilename;
    if (orig != null && orig.isNotEmpty && !_isRandom(orig)) return orig;
    final pathLast = p.storagePath.split('/').last;
    if (!_isRandom(pathLast)) return pathLast;
    // Fall back to caption-based name for legacy UUID/Cloudinary photos
    final ext = pathLast.contains('.') ? pathLast.split('.').last : 'jpg';
    final cap = (p.caption?.isNotEmpty == true ? p.caption! : 'Photo')
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .trim()
        .replaceAll(' ', '_');
    return '$cap.$ext';
  }

  // ── Existing photo chip (shown inline under each section in edit mode) ──────
  Widget _existingPhotoChip(PhotoEntity p) {
    final filename = _resolvePhotoName(p);
    return GestureDetector(
      onTap: () {
        if (p.url != null && p.url!.isNotEmpty) {
          launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _kBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBlue.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.insert_drive_file_rounded, color: _kBlue, size: 13),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(filename,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: _kNavy(context)),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () =>
                ref.read(photoProvider(widget.patientId).notifier).delete(p),
            child: Icon(Icons.close_rounded, size: 14, color: _kMuted(context)),
          ),
        ]),
      ),
    );
  }

  // ── Step 2 : Treatment (exact same as patient registration) ───────────────
  Widget _buildStep2() {
    // Watch once unconditionally — correct Riverpod pattern for ConsumerState.
    // Calling ref.watch() inside a nested local function (old pattern) caused
    // the subscription to be registered only when that branch rendered, which
    // meant Follow-up visits (different tab or section state) sometimes missed
    // the provider update.
    final _allPatientPhotos = ref.watch(photoProvider(widget.patientId)).photos;
    // Same deduplication logic as _buildStep1 and visit_view_screen.
    final _seenPaths2 = <String>{};
    final _visitPhotos = <PhotoEntity>[];
    if (widget.visitId != null) {
      for (final p in _allPatientPhotos.where((p) => p.visitId == widget.visitId)) {
        if (_seenPaths2.add(p.storagePath)) _visitPhotos.add(p);
      }
    }
    for (final p in _allPatientPhotos.where((p) =>
        (p.visitId == null || p.visitId!.isEmpty) &&
        (p.surgeryId == null || p.surgeryId!.isEmpty) &&
        p.category != PhotoCategory.patientReport)) {
      if (_seenPaths2.add(p.storagePath)) _visitPhotos.add(p);
    }

    // Filter existing photos by section caption.
    List<PhotoEntity> ep(String caption) =>
        _visitPhotos.where((p) => p.caption == caption).toList();

    // Catch photos that have a visitId match but no recognised section caption
    // (e.g. uploaded before the caption feature, or from an unknown section).
    const _knownCaptions = {
      'Previous History', 'Chief Complaint', 'General Examination',
      'Neurological Examination', 'Imaging', 'Other Investigation',
      'Impression', 'Treatment Plan', 'Medicines',
      'Cross Consultation', 'Clinical Diagnosis',
    };
    final _orphanPhotos = _visitPhotos
        .where((p) => p.caption == null || !_knownCaptions.contains(p.caption))
        .toList();

    return ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [

      // ── History & Complaint ──────────────────────────────────────────
      _WizardCard(
        title: 'History & Complaint',
        icon: Icons.history_edu_outlined,
        color: _kBlue,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _fieldWithUpload(
            label: 'Previous History',
            controller: _prevHistoryCtrl,
            files: _prevHistoryFiles,
            onFilesChange: (f) => _prevHistoryFiles..clear()..addAll(f),
            existingPhotos: ep('Previous History'),
            prefixIcon: Icons.history_edu_outlined,
            hint: 'Enter previous medical history…',
          ),
          const SizedBox(height: 14),
          _fieldWithUpload(
            label: 'Chief Complaint',
            controller: _complaintCtrl,
            files: _chiefComplaintFiles,
            onFilesChange: (f) => _chiefComplaintFiles..clear()..addAll(f),
            existingPhotos: ep('Chief Complaint'),
            prefixIcon: Icons.report_problem_outlined,
            hint: 'Primary reason for visit…',
          ),
        ]),
      ),

      // ── Examination Finding ──────────────────────────────────────────
      _WizardCard(
        title: 'Examination Finding',
        icon: Icons.person_search_outlined,
        color: _kBlue,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _examTab = 'general'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _examTab == 'general' ? _kBlue : _kCard(context),
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10)),
                    border: Border.all(
                        color: _examTab == 'general' ? _kBlue : _kBorder(context)),
                  ),
                  alignment: Alignment.center,
                  child: Text('General',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _examTab == 'general' ? Colors.white : _kSlate(context))),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _examTab = 'neurological'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _examTab == 'neurological' ? _kBlue : _kCard(context),
                    borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(10),
                        bottomRight: Radius.circular(10)),
                    border: Border.all(
                        color: _examTab == 'neurological' ? _kBlue : _kBorder(context)),
                  ),
                  alignment: Alignment.center,
                  child: Text('Neurological',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _examTab == 'neurological' ? Colors.white : _kSlate(context))),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_examTab == 'general') ...[
            TextFormField(
              controller: _examGeneralCtrl,
              maxLines: 3,
              style: TextStyle(
                  fontSize: 14, color: _kNavy(context), fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'General examination findings…',
                hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
                prefixIcon: Icon(Icons.person_search_outlined,
                    size: 17, color: _kMuted(context)),
                suffixIcon: Tooltip(
                  message: 'Upload files',
                  child: Stack(alignment: Alignment.center,
                      clipBehavior: Clip.none, children: [
                    IconButton(
                      icon: Icon(Icons.upload_file_rounded, size: 20,
                          color: _examGeneralFiles.isNotEmpty
                              ? _kBlue
                              : _kMuted(context)),
                      onPressed: () => _pickFiles((picked) =>
                          setState(() => _examGeneralFiles.addAll(picked)),
                          sectionName: 'GeneralExamination'),
                    ),
                    if (_examGeneralFiles.isNotEmpty)
                      Positioned(right: 6, top: 6,
                        child: Container(
                          width: 15, height: 15,
                          decoration: BoxDecoration(
                              color: _kBlue, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${_examGeneralFiles.length}',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 8,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ]),
                ),
                filled: true, fillColor: _kBg(context),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kBorder(context))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kBorder(context))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kP1, width: 1.5)),
              ),
            ),
            if (_examGeneralFiles.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6,
                  children: List.generate(_examGeneralFiles.length, (idx) =>
                    _fileChip(_examGeneralFiles[idx].name, () =>
                        setState(() => _examGeneralFiles.removeAt(idx))))),
            ],
            if (ep('General Examination').isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6,
                  children: ep('General Examination').map(_existingPhotoChip).toList()),
            ],
          ] else ...[
            TextFormField(
              controller: _examNeurologicalCtrl,
              maxLines: 3,
              style: TextStyle(
                  fontSize: 14, color: _kNavy(context), fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Neurological examination findings…',
                hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
                prefixIcon: Icon(Icons.psychology_outlined,
                    size: 17, color: _kMuted(context)),
                suffixIcon: Tooltip(
                  message: 'Upload files',
                  child: Stack(alignment: Alignment.center,
                      clipBehavior: Clip.none, children: [
                    IconButton(
                      icon: Icon(Icons.upload_file_rounded, size: 20,
                          color: _examNeurologicalFiles.isNotEmpty
                              ? _kBlue
                              : _kMuted(context)),
                      onPressed: () => _pickFiles((picked) =>
                          setState(() =>
                              _examNeurologicalFiles.addAll(picked)),
                          sectionName: 'NeurologicalExamination'),
                    ),
                    if (_examNeurologicalFiles.isNotEmpty)
                      Positioned(right: 6, top: 6,
                        child: Container(
                          width: 15, height: 15,
                          decoration: BoxDecoration(
                              color: _kBlue, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${_examNeurologicalFiles.length}',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 8,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ]),
                ),
                filled: true, fillColor: _kBg(context),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kBorder(context))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kBorder(context))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kP1, width: 1.5)),
              ),
            ),
            if (_examNeurologicalFiles.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6,
                  children: List.generate(_examNeurologicalFiles.length,
                    (idx) => _fileChip(_examNeurologicalFiles[idx].name,
                        () => setState(() =>
                            _examNeurologicalFiles.removeAt(idx))))),
            ],
            if (ep('Neurological Examination').isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6,
                  children: ep('Neurological Examination').map(_existingPhotoChip).toList()),
            ],
          ],
        ]),
      ),

      // ── Previous Investigations ──────────────────────────────────────
      _WizardCard(
        title: 'Previous Investigations',
        icon: Icons.science_outlined,
        color: _kBlue,
        child: Column(children: [
          _fieldWithUpload(
            label: 'Imaging',
            controller: _imagingCtrl,
            files: _imagingFiles,
            onFilesChange: (f) => _imagingFiles..clear()..addAll(f),
            existingPhotos: ep('Imaging'),
            prefixIcon: Icons.image_search_rounded,
            hint: 'Imaging findings (X-Ray, MRI, CT…)',
          ),
          const SizedBox(height: 12),
          _fieldWithUpload(
            label: 'Other Investigation',
            controller: _otherInvestCtrl,
            files: _otherInvestFiles,
            onFilesChange: (f) => _otherInvestFiles..clear()..addAll(f),
            existingPhotos: ep('Other Investigation'),
            prefixIcon: Icons.biotech_outlined,
            hint: 'Lab reports, other tests…',
          ),
        ]),
      ),

      // ── Impression ───────────────────────────────────────────────────
      _WizardCard(
        title: 'Impression',
        icon: Icons.lightbulb_outline_rounded,
        color: _kBlue,
        child: _fieldWithUpload(
          label: 'Clinical Impression',
          controller: _diagnosisCtrl,
          files: _impressionFiles,
          onFilesChange: (f) => _impressionFiles..clear()..addAll(f),
          existingPhotos: ep('Impression'),
          prefixIcon: Icons.rule_outlined,
          hint: 'Clinical impression / assessment…',
        ),
      ),

      // ── Clinical Plan ────────────────────────────────────────────────
      _WizardCard(
        title: 'Clinical Plan',
        icon: Icons.assignment_outlined,
        color: _kBlue,
        child: Column(children: [
          _fieldWithUpload(
            label: 'Plan',
            controller: _treatmentCtrl,
            files: _planFiles,
            onFilesChange: (f) => _planFiles..clear()..addAll(f),
            existingPhotos: ep('Treatment Plan'),
            prefixIcon: Icons.assignment_outlined,
            hint: 'Recommended plan…',
          ),
          const SizedBox(height: 12),
          _buildMedicationTable(),
          const SizedBox(height: 12),
          _vField(
            label: 'OT Notes',
            controller: _otNotesCtrl,
            maxLines: 4,
            prefixIcon: Icons.local_hospital_outlined,
            hint: 'Operation theatre notes…',
          ),
          const SizedBox(height: 12),
          _vField(
            label: 'Advice',
            controller: _adviceCtrl,
            maxLines: 3,
            prefixIcon: Icons.tips_and_updates_outlined,
            hint: 'Advice given to patient…',
          ),
          const SizedBox(height: 12),
          _fieldWithUpload(
            label: 'Cross Consultation',
            controller: _crossConsultCtrl,
            files: _crossConsultFiles,
            onFilesChange: (f) => _crossConsultFiles..clear()..addAll(f),
            existingPhotos: ep('Cross Consultation'),
            prefixIcon: Icons.people_outline_rounded,
            hint: 'Referred to / consulted with…',
          ),
        ]),
      ),

      // ── Doctor's Notes (private — not printed) ───────────────────────
      _WizardCard(
        title: "Doctor's Notes",
        icon: Icons.lock_outline_rounded,
        color: _kBlue,
        child: _vField(
          label: 'Notes (for your reference only)',
          controller: _treatNotesCtrl,
          maxLines: 4,
          hint: 'Private notes — will not appear on the patient sheet…',
        ),
      ),
    ],
  );
  }

  // ── Structured medication table ───────────────────────────────────────────
  Widget _buildMedicationTable() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Treatment / Medications',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate(context))),
        const Spacer(),
        GestureDetector(
          onTap: _showAddMedicineSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text('Add Medicine', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      if (_prescriptionRows.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: _kBg(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder(context)),
          ),
          child: Column(children: [
            Icon(Icons.medication_outlined, color: _kMuted(context), size: 28),
            const SizedBox(height: 6),
            Text('No medicines added', style: TextStyle(fontSize: 12, color: _kMuted(context))),
            const SizedBox(height: 2),
            Text('Tap "Add Medicine" to prescribe',
                style: TextStyle(fontSize: 11, color: _kMuted(context).withValues(alpha: 0.7))),
          ]),
        )
      else ...[
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10), topRight: Radius.circular(10)),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: Text('Medicine',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSlate(context)))),
            Expanded(flex: 2, child: Text('Dose',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSlate(context)))),
            Expanded(flex: 2, child: Text('Route',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSlate(context)))),
            Expanded(flex: 2, child: Text('Freq.',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSlate(context)))),
            Expanded(flex: 2, child: Text('Duration',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSlate(context)))),
            SizedBox(width: 24),
          ]),
        ),
        Container(
          decoration: BoxDecoration(
            color: _kBg(context),
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
            border: Border.all(color: _kBorder(context)),
          ),
          child: Column(
            children: List.generate(_prescriptionRows.length, (idx) {
              final row = _prescriptionRows[idx];
              return Container(
                decoration: BoxDecoration(
                  border: idx > 0
                      ? Border(top: BorderSide(color: _kBorder(context), width: 0.5))
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(flex: 3, child: Text(row.medicine,
                        style: TextStyle(fontSize: 12, color: _kNavy(context),
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text(row.dose.isNotEmpty ? row.dose : '—',
                        style: TextStyle(fontSize: 12, color: _kSlate(context)),
                        overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text(row.route,
                        style: TextStyle(fontSize: 12, color: _kSlate(context)),
                        overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text(row.frequency,
                        style: TextStyle(fontSize: 12, color: _kSlate(context)),
                        overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text(row.duration.isNotEmpty ? row.duration : '—',
                        style: TextStyle(fontSize: 12, color: _kSlate(context)),
                        overflow: TextOverflow.ellipsis)),
                    GestureDetector(
                      onTap: () => setState(() => _prescriptionRows.removeAt(idx)),
                      child: Icon(Icons.close_rounded, size: 16, color: _kMuted(context)),
                    ),
                  ]),
                  if (row.specialInstruction.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.info_outline_rounded, size: 11, color: _kAmber),
                      const SizedBox(width: 4),
                      Expanded(child: Text(row.specialInstruction,
                          style: TextStyle(fontSize: 10, color: _kAmber,
                              fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                ]),
              );
            }),
          ),
        ),
      ],
    ]);
  }

  Future<void> _showAddMedicineSheet() async {
    final result = await showModalBottomSheet<_PrescriptionRow>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMedicineSheet(
        patientId: widget.patientId,
        medicineService: ref.read(medicineServiceProvider),
      ),
    );
    if (result != null && result.medicine.isNotEmpty) {
      setState(() => _prescriptionRows.add(result));
    }
  }

  // Simple text field (no file upload) for Step 2
  Widget _vField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    IconData? prefixIcon,
    String? hint,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate(context))),
    const SizedBox(height: 6),
    TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
          fontSize: 14, color: _kNavy(context), fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 17, color: _kMuted(context))
            : null,
        filled: true, fillColor: _kBg(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kBorder(context))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kBorder(context))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kP1, width: 1.5)),
      ),
    ),
  ]);

  // ── Step 3 : Preview & Print ──────────────────────────────────────────────
  Widget _buildStep3() {
    final p = _patient;
    String fv(String? s) => (s?.isNotEmpty == true) ? s! : '—';

    // Parse patient notes JSON
    final notes = <String, String>{};
    if (p?.notes?.isNotEmpty == true) {
      try {
        final decoded = jsonDecode(p!.notes!) as Map<String, dynamic>;
        notes.addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
      } catch (_) {}
    }
    String n(String k) => notes[k]?.isNotEmpty == true ? notes[k]! : '—';

    final fullName = p != null
        ? '${p.firstName} ${p.lastName}'.trim()
        : '—';
    final gender = p?.sex?.isNotEmpty == true
        ? '${p!.sex![0].toUpperCase()}${p.sex!.substring(1)}'
        : '—';

    // ── Local helpers ────────────────────────────────────────────────────
    Widget iField(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 9, color: _kMuted(context),
                fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 13, color: _kNavy(context), fontWeight: FontWeight.w600)),
      ]),
    );

    Widget eRow(String label, String value,
        List<({String name, Uint8List bytes})> files) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, color: _kMuted(context), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        if (value.isNotEmpty)
          Text(value,
              style: TextStyle(
                  fontSize: 13, color: _kNavy(context), fontWeight: FontWeight.w600))
        else if (files.isEmpty)
          Text('—',
              style: TextStyle(
                  fontSize: 13, color: _kMuted(context), fontWeight: FontWeight.w500)),
        if (files.isNotEmpty) ...[
          if (value.isNotEmpty) const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4,
              children: files.map((f) => _fileViewChip(f)).toList()),
        ],
        const SizedBox(height: 4),
      ]),
    );

    Widget pRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, color: _kMuted(context), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13, color: _kNavy(context), fontWeight: FontWeight.w600)),
      ]),
    );

    Widget sCard(String title, IconData icon, Color color, Widget body) =>
        Container(
          decoration: BoxDecoration(
            color: _kCard(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder(context)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 15),
                ),
                const SizedBox(width: 9),
                Text(title,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: _kNavy(context))),
              ]),
            ),
            Divider(height: 1, color: _kBorder(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: body,
            ),
          ]),
        );

    Widget twoCol(Widget left, Widget right) => Column(children: [
      Padding(padding: const EdgeInsets.only(bottom: 10), child: left),
      Padding(padding: const EdgeInsets.only(bottom: 10), child: right),
    ]);

    const vDiv = SizedBox.shrink();

    // ── Visit vitals: only use what the user actually typed this visit
    final wt   = _weightCtrl.text.trim();
    final bp   = _bpCtrl.text.trim();
    final temp = _tempCtrl.text.trim();

    // Loading overlay for edit mode while visit data is fetching
    if (_visitLoading) {
      return const Center(child: CircularProgressIndicator(color: _kBlue));
    }

    // Determine banner style
    final isUnsavedDraft = _savedVisit == null && widget.visitId == null;
    final isViewMode     = widget.visitId != null && !_justSaved;
    final bannerColor = isUnsavedDraft ? _kAmber : _kBlue;
    final bannerIcon = isUnsavedDraft ? Icons.edit_note_outlined
        : isViewMode ? Icons.assignment_outlined
        : Icons.check_rounded;
    final bannerTitle = isUnsavedDraft
        ? 'Draft Preview  ·  Not saved yet'
        : isViewMode
            ? 'Visit Record'
            : (widget.visitId == null ? 'Visit Saved Successfully!' : 'Visit Updated Successfully!');

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        // ── Banner ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bannerColor.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: bannerColor, shape: BoxShape.circle),
              child: Icon(bannerIcon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bannerTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: _kNavy(context),
                        fontSize: 15)),
                RichText(text: TextSpan(children: [
                  TextSpan(text: 'Date: ',
                      style: TextStyle(color: _kMuted(context), fontSize: 11)),
                  TextSpan(
                    text: DateFormat('dd MMM yyyy').format(_visitDate),
                    style: TextStyle(
                        color: bannerColor, fontWeight: FontWeight.w700,
                        fontSize: 11),
                  ),
                  TextSpan(text: '  ·  ',
                      style: TextStyle(color: _kMuted(context), fontSize: 11)),
                  TextSpan(text: fullName,
                      style: TextStyle(
                          color: _kNavy(context), fontSize: 11)),
                  TextSpan(text: '  ·  ',
                      style: TextStyle(color: _kMuted(context), fontSize: 11)),
                  TextSpan(text: _visitType.label,
                      style: TextStyle(
                          color: bannerColor, fontWeight: FontWeight.w600,
                          fontSize: 11)),
                ])),
              ]),
            ),
            Stack(alignment: Alignment.bottomRight, children: [
              Icon(Icons.assignment_outlined, size: 44,
                  color: bannerColor.withValues(alpha: 0.3)),
              if (!isViewMode)
                Container(
                  width: 17, height: 17,
                  decoration: BoxDecoration(
                      color: bannerColor, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded,
                      color: Colors.white, size: 11),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Vitals | Clinical Snapshot ────────────────────────────────────
        twoCol(
          sCard('Vitals', Icons.monitor_heart_outlined, _kBlue,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              pRow('Weight', fv(wt)),
              pRow('Blood Pressure', fv(bp)),
              pRow('Temperature', fv(temp)),
            ]),
          ),
          sCard('Clinical Snapshot', Icons.health_and_safety_outlined,
              _kBlue,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(fv(p?.allergies ?? n('allergies')),
                  style: TextStyle(fontSize: 13, color: _kNavy(context),
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),

        // ── History & Complaint | Examination Finding ─────────────────────
        twoCol(
          sCard('History & Complaint', Icons.history_edu_outlined,
              _kBlue,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('Previous History',
                  _prevHistoryCtrl.text.trim(), _prevHistoryFiles),
              eRow('Chief Complaint',
                  _complaintCtrl.text.trim(), _chiefComplaintFiles),
            ]),
          ),
          sCard('Examination Finding', Icons.search_outlined,
              _kBlue2,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('General',
                  _examGeneralCtrl.text.trim(), _examGeneralFiles),
              eRow('Neurological',
                  _examNeurologicalCtrl.text.trim(), _examNeurologicalFiles),
            ]),
          ),
        ),

        // ── Previous Investigations ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: sCard('Previous Investigations', Icons.science_outlined,
              const Color(0xFFF59E0B),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('Imaging', _imagingCtrl.text.trim(), _imagingFiles),
              eRow('Other Investigation',
                  _otherInvestCtrl.text.trim(), _otherInvestFiles),
            ]),
          ),
        ),

        // ── Impression ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: sCard('Impression', Icons.lightbulb_outline_rounded, _kAmber,
            eRow('Clinical Impression',
                _diagnosisCtrl.text.trim(), _impressionFiles),
          ),
        ),

        // ── Clinical Plan ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: sCard('Clinical Plan', Icons.assignment_outlined, _kBlue,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('Plan', _treatmentCtrl.text.trim(), _planFiles),
              if (_prescriptionRows.isNotEmpty) ...[
                Text('Prescriptions',
                    style: TextStyle(fontSize: 10, color: _kMuted(context),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ...List.generate(_prescriptionRows.length, (idx) {
                  final r = _prescriptionRows[idx];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                                color: _kBlue.withValues(alpha: 0.12),
                                shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text('${idx + 1}',
                                style: TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.w800,
                                    color: _kBlue)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                    fontSize: 12, color: _kNavy(context),
                                    fontWeight: FontWeight.w600),
                                children: [
                                  TextSpan(text: r.medicine),
                                  if (r.dose.isNotEmpty)
                                    TextSpan(text: '  ${r.dose}',
                                        style: TextStyle(
                                            color: _kSlate(context), fontWeight: FontWeight.w500)),
                                  TextSpan(text: '  ·  ${r.route}  ·  ${r.frequency}',
                                      style: TextStyle(
                                          color: _kMuted(context), fontSize: 11,
                                          fontWeight: FontWeight.w500)),
                                  if (r.duration.isNotEmpty)
                                    TextSpan(text: '  ×  ${r.duration}',
                                        style: TextStyle(
                                            color: _kMuted(context), fontSize: 11,
                                            fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ]),
                        if (r.specialInstruction.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Row(children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 10, color: _kAmber),
                              const SizedBox(width: 4),
                              Expanded(child: Text(r.specialInstruction,
                                  style: TextStyle(fontSize: 10, color: _kAmber,
                                      fontStyle: FontStyle.italic))),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ] else
                eRow('Treatment', '', _treatmentMedFiles),
              pRow('Advice', fv(_adviceCtrl.text.trim())),
              eRow('Investigation to be done', fv(_investigationToBeDoneCtrl.text.trim()), _investigationToBeDoneFiles),
              eRow('Cross Consultation', fv(_crossConsultCtrl.text.trim()), _crossConsultFiles),
            ]),
          ),
        ),

        // ── OT Notes ──────────────────────────────────────────────────────
        if (_otNotesCtrl.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: sCard('OT Notes', Icons.medical_services_outlined,
                const Color(0xFF6B21A8),
              Text(_otNotesCtrl.text.trim(),
                  style: TextStyle(fontSize: 13, color: _kNavy(context),
                      fontWeight: FontWeight.w500)),
            ),
          ),

        // ── Doctor's Notes (private) ──────────────────────────────────────
        if (_treatNotesCtrl.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: sCard("Doctor's Notes", Icons.lock_outline_rounded,
                _kBlue,
              Text(_treatNotesCtrl.text.trim(),
                  style: TextStyle(fontSize: 13, color: _kNavy(context),
                      fontWeight: FontWeight.w500)),
            ),
          ),
      ],
    );
  }

  // File view chip for Step 3 preview
  Widget _fileViewChip(({String name, Uint8List bytes}) f) {
    final ext = f.name.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);
    return InkWell(
      onTap: () => _viewFile(f),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _kBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBlue.withValues(alpha: 0.22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
              color: _kBlue, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(f.name,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy(context)),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          Icon(Icons.visibility_outlined, color: _kBlue, size: 14),
        ]),
      ),
    );
  }

  void _viewFile(({String name, Uint8List bytes}) f) {
    final ext = f.name.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: _kWiz(context),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: _kBorder(context))),
              ),
              child: Row(children: [
                Icon(isImage
                    ? Icons.image_outlined
                    : Icons.insert_drive_file_outlined,
                    color: _kBlue, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(f.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: _kNavy(context),
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18),
                  color: _kMuted(context),
                  onPressed: () => Navigator.pop(ctx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                ),
              ]),
            ),
            Flexible(
              child: isImage
                  ? InteractiveViewer(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Image.memory(f.bytes),
                      ))
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.insert_drive_file_rounded,
                            size: 72, color: _kMuted(context)),
                        const SizedBox(height: 16),
                        Text(f.name,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: _kNavy(context)),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('${(f.bytes.length / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                                fontSize: 12, color: _kMuted(context))),
                        const SizedBox(height: 16),
                        Text(
                          'Preview not available for this file type.',
                          style: TextStyle(fontSize: 12, color: _kMuted(context)),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Prescription row data model ───────────────────────────────────────────────

class _PrescriptionRow {
  String medicine;
  String dose;
  String route;
  String frequency;
  String duration;
  String specialInstruction;

  _PrescriptionRow({
    this.medicine = '',
    this.dose = '',
    this.route = '',
    this.frequency = '',
    this.duration = '',
    this.specialInstruction = '',
  });

  Map<String, dynamic> toJson() => {
    'medicine':           medicine,
    'dose':               dose,
    'route':              route,
    'frequency':          frequency,
    'duration':           duration,
    'specialInstruction': specialInstruction,
  };

  static _PrescriptionRow fromJson(Map<String, dynamic> j) => _PrescriptionRow(
    medicine:           j['medicine']           as String? ?? '',
    dose:               j['dose']               as String? ?? '',
    route:              j['route']              as String? ?? '',
    frequency:          j['frequency']          as String? ?? '',
    duration:           j['duration']           as String? ?? '',
    specialInstruction: j['specialInstruction'] as String? ?? '',
  );
}

// ── Add Medicine bottom sheet ─────────────────────────────────────────────────

class _AddMedicineSheet extends StatefulWidget {
  final String patientId;
  final MedicineService medicineService;

  const _AddMedicineSheet({
    required this.patientId,
    required this.medicineService,
  });

  @override
  State<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

const _kRoutes     = ['Oral', 'IV', 'IM', 'SC', 'Topical', 'SL', 'Inhalation', 'Rectal', 'Nasal'];
const _kFreqs      = ['OD', 'BD', 'TDS', 'QID', 'SOS', 'PRN', 'HS', 'Weekly', 'Fortnightly', 'Monthly'];

class _AddMedicineSheetState extends State<_AddMedicineSheet> {
  final _nameCtrl        = TextEditingController();
  final _doseCtrl        = TextEditingController();
  final _routeCtrl       = TextEditingController();
  final _freqCtrl        = TextEditingController();
  final _durCtrl         = TextEditingController();
  final _specialCtrl     = TextEditingController();
  final _nameFocus       = FocusNode();

  List<MedicineSuggestion> _suggestions = [];
  bool _showSugg = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _routeCtrl.dispose();
    _freqCtrl.dispose();
    _durCtrl.dispose();
    _specialCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onNameChanged() async {
    final q = _nameCtrl.text.trim();
    if (q.length < 2) {
      if (mounted) setState(() { _suggestions = []; _showSugg = false; });
      return;
    }
    final results = await widget.medicineService.getSuggestions(
        query: q, patientId: widget.patientId);
    if (!mounted) return;
    setState(() { _suggestions = results; _showSugg = results.isNotEmpty; });
  }

  void _selectSuggestion(MedicineSuggestion s) {
    _nameCtrl.text = s.name;
    if (s.defaultDose?.isNotEmpty == true && _doseCtrl.text.isEmpty) {
      _doseCtrl.text = s.defaultDose!;
    }
    if (s.frequency?.isNotEmpty == true && _freqCtrl.text.isEmpty) {
      _freqCtrl.text = s.frequency!;
    }
    setState(() { _suggestions = []; _showSugg = false; });
  }

  void _submit() {
    final med = _nameCtrl.text.trim();
    if (med.isEmpty) return;
    Navigator.of(context).pop(_PrescriptionRow(
      medicine:           med,
      dose:               _doseCtrl.text.trim(),
      route:              _routeCtrl.text.trim(),
      frequency:          _freqCtrl.text.trim(),
      duration:           _durCtrl.text.trim(),
      specialInstruction: _specialCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard(context),
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: _kBorder(context), borderRadius: BorderRadius.circular(2)),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: _kBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.medication_rounded, color: _kBlue, size: 17),
              ),
              const SizedBox(width: 10),
              Text('Add Medicine',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: _kNavy(context))),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close_rounded, color: _kMuted(context), size: 20),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: _kBorder(context)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Medicine name with autocomplete ────────────────────────────
                Text('Medicine Name *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _kSlate(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  autofocus: true,
                  style: TextStyle(fontSize: 14, color: _kNavy(context),
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Type medicine name…',
                    hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
                    prefixIcon: Icon(Icons.medication_outlined, size: 17, color: _kMuted(context)),
                    suffixIcon: _nameCtrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _nameCtrl.clear();
                              setState(() { _suggestions = []; _showSugg = false; }); },
                            child: Icon(Icons.close_rounded, size: 16, color: _kMuted(context)))
                        : null,
                    filled: true, fillColor: _kBg(context),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _kBorder(context))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _kBorder(context))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _kBlue, width: 1.5)),
                  ),
                ),
                // Suggestions dropdown
                if (_showSugg && _suggestions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: _kWiz(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder(context)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: _kBorder(context)),
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        return InkWell(
                          onTap: () => _selectSuggestion(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            child: Row(children: [
                              Icon(
                                s.isHistory
                                    ? Icons.history_rounded
                                    : Icons.medication_rounded,
                                size: 15,
                                color: s.isHistory ? _kGreen : _kBlue,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                  Text(s.name,
                                      style: TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600,
                                          color: _kNavy(context))),
                                  if (s.subtitle.isNotEmpty)
                                    Text(s.subtitle,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: s.isHistory ? _kGreen : _kMuted(context))),
                                ]),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Dose & Route ───────────────────────────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Dose',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: _kSlate(context))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _doseCtrl,
                        style: TextStyle(fontSize: 14, color: _kNavy(context),
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: '500mg',
                          hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
                          filled: true, fillColor: _kBg(context),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBorder(context))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBorder(context))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBlue, width: 1.5)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Route',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: _kSlate(context))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _routeCtrl,
                        style: TextStyle(fontSize: 14, color: _kNavy(context),
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Oral / IV / IM…',
                          hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
                          filled: true, fillColor: _kBg(context),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBorder(context))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBorder(context))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBlue, width: 1.5)),
                        ),
                      ),
                    ]),
                  ),
                ]),

                const SizedBox(height: 12),

                // ── Frequency & Duration ───────────────────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Frequency',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: _kSlate(context))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _freqCtrl,
                        style: TextStyle(fontSize: 14, color: _kNavy(context),
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'e.g. 1-0-1',
                          hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
                          filled: true, fillColor: _kBg(context),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBorder(context))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBorder(context))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBlue, width: 1.5)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Duration',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: _kSlate(context))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _durCtrl,
                        style: TextStyle(fontSize: 14, color: _kNavy(context),
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: '5 days',
                          hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
                          filled: true, fillColor: _kBg(context),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBorder(context))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBorder(context))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _kBlue, width: 1.5)),
                        ),
                      ),
                    ]),
                  ),
                ]),

                const SizedBox(height: 12),

                // ── Special Instruction ────────────────────────────────────────
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Special Instruction',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: _kSlate(context))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _specialCtrl,
                    maxLines: 2,
                    style: TextStyle(fontSize: 14, color: _kNavy(context),
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'e.g. Take after food, avoid alcohol…',
                      hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
                      prefixIcon: Icon(Icons.info_outline_rounded,
                          size: 17, color: _kMuted(context)),
                      filled: true, fillColor: _kBg(context),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _kBorder(context))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _kBorder(context))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _kBlue, width: 1.5)),
                    ),
                  ),
                ]),

                const SizedBox(height: 18),

                // ── Add button ─────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: Icon(Icons.add_rounded, size: 18),
                    label: Text('Add Medicine',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Wizard card ───────────────────────────────────────────────────────────────
class _WizardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final String? badge;

  const _WizardCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      decoration: BoxDecoration(
        color: _kCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ],
          ]),
        ),
        Divider(height: 1, color: Color(0xFFE2E8F0)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: child,
        ),
      ]),
    ),
  );
}
