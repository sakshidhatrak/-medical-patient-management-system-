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
import 'package:intl/intl.dart';

import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../../../photos/domain/entities/photo_entity.dart';
import '../../../photos/presentation/providers/photo_provider.dart';
import '../../../print_configuration/presentation/providers/print_config_provider.dart';
import '../../domain/entities/visit_entity.dart';
import '../providers/visit_provider.dart';

// ── Design tokens (match patient_register_screen) ─────────────────────────────
const _kBlue   = Color(0xFF2563EB);
const _kBlue2  = Color(0xFF0EA5E9);
const _kGreen  = Color(0xFF10B981);
const _kRed    = Color(0xFFEF4444);
const _kAmber  = Color(0xFFF59E0B);
const _kP1     = Color(0xFF6C63FF);
const _kBg     = Color(0xFFF8FAFC);
const _kWiz    = Color(0xFFF1F5F9);
const _kNavy   = Color(0xFF0F172A);
const _kSlate  = Color(0xFF475569);
const _kMuted  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);

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
  bool _saving       = false;
  bool _visitLoaded  = false;
  bool _visitLoading = false; // true while async load is in progress
  bool _justSaved    = false; // true right after save/update
  PatientEntity? _patient;
  VisitEntity? _savedVisit;

  // ── Visit meta ─────────────────────────────────────────────────────────────
  DateTime  _visitDate = DateTime.now();
  VisitType _visitType = VisitType.opd; // overridden in initState for follow-ups

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
  final _medicationsCtrl    = TextEditingController(); // Medications
  final _treatmentMedFiles  = <({String name, Uint8List bytes})>[];
  final _treatNotesCtrl     = TextEditingController();
  final _adviceCtrl         = TextEditingController();

  // ── Vitals (per visit) ────────────────────────────────────────────────────
  final _weightCtrl = TextEditingController();
  final _bpCtrl     = TextEditingController();
  final _tempCtrl   = TextEditingController();

  static const _stepLabels = ['Patient Info', 'Treatment', 'Preview & Print'];
  static const _stepSubtitles = [
    'Auto-populated · Review & continue',
    'Enter treatment details',
    'Review & export visit record',
  ];
  static const _stepIcons = [
    Icons.person_outline_rounded,
    Icons.medical_services_outlined,
    Icons.print_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _step = widget.visitId != null ? 2 : 0;
    _pageCtrl = PageController(initialPage: _step);
    if (widget.visitId != null) {
      _visitLoading = true;
    } else {
      // Default to Follow-up if the patient already has at least one visit
      Future.microtask(() {
        if (!mounted) return;
        final existing = ref.read(visitsProvider(widget.patientId));
        if (existing.isNotEmpty) {
          setState(() => _visitType = VisitType.followUp);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [
      _prevHistoryCtrl, _complaintCtrl,
      _examGeneralCtrl, _examNeurologicalCtrl,
      _clinicalDiagnosisCtrl, _imagingCtrl, _otherInvestCtrl,
      _diagnosisCtrl, _treatmentCtrl, _medicationsCtrl,
      _treatNotesCtrl, _adviceCtrl,
      _weightCtrl, _bpCtrl, _tempCtrl,
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
        se(_medicationsCtrl,         'medications');
        se(_adviceCtrl,              'advice');
        se(_bpCtrl,                  'bp');
        se(_weightCtrl,              'weight');
        se(_tempCtrl,                'temperature');
      } catch (_) {}
    }
    setState(() {});
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
    add('medications',       _medicationsCtrl.text.trim());
    add('advice',            _adviceCtrl.text.trim());
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
      _diagnosisCtrl, _treatmentCtrl, _medicationsCtrl,
      _treatNotesCtrl, _adviceCtrl,
      _weightCtrl, _bpCtrl, _tempCtrl,
    ];
    return ctrls.any((c) => c.text.trim().isNotEmpty) ||
        _prevHistoryFiles.isNotEmpty    || _chiefComplaintFiles.isNotEmpty ||
        _examGeneralFiles.isNotEmpty    || _examNeurologicalFiles.isNotEmpty ||
        _clinicalDiagnosisFiles.isNotEmpty || _imagingFiles.isNotEmpty ||
        _otherInvestFiles.isNotEmpty    || _impressionFiles.isNotEmpty ||
        _planFiles.isNotEmpty           || _treatmentMedFiles.isNotEmpty;
  }

  // ── Upload all files picked in the wizard for a given visitId ────────────
  Future<void> _uploadVisitFiles(String visitId) async {
    final notifier = ref.read(photoProvider(widget.patientId).notifier);
    final batches = <(List<({String name, Uint8List bytes})>, PhotoCategory)>[
      (_prevHistoryFiles,       PhotoCategory.visit),
      (_chiefComplaintFiles,    PhotoCategory.visit),
      (_examGeneralFiles,       PhotoCategory.examination),
      (_examNeurologicalFiles,  PhotoCategory.examination),
      (_clinicalDiagnosisFiles, PhotoCategory.visit),
      (_imagingFiles,           PhotoCategory.radiology),
      (_otherInvestFiles,       PhotoCategory.visit),
      (_impressionFiles,        PhotoCategory.treatment),
      (_planFiles,              PhotoCategory.treatment),
      (_treatmentMedFiles,      PhotoCategory.treatment),
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
          caption:  f.name,
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
                style: const TextStyle(fontWeight: FontWeight.w700,
                    color: Colors.white, fontSize: 13)),
            const SizedBox(height: 4),
            ...failed.map((e) => Text(e,
                style: const TextStyle(color: Colors.white70, fontSize: 11))),
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
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── Save / Create visit ───────────────────────────────────────────────────
  Future<void> _save() async {
    if (_saving) return;
    _saving = true; // set synchronously before any await so rapid taps are blocked
    final isNew = widget.visitId == null;

    if (isNew && !_hasAnyTreatmentData()) {
      _saving = false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
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

    setState(() {});

    String? nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

    if (isNew) {
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
          );
      if (!mounted) return;
      setState(() { _saving = false; _savedVisit = visit; _justSaved = true; });
      if (visit != null) {
        // Upload any files attached in the form
        await _uploadVisitFiles(visit.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Visit saved  ·  ${DateFormat('dd MMM yyyy').format(_visitDate)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            )),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
        setState(() => _step = 2);
        unawaited(_pageCtrl.animateToPage(2,
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut));
      } else {
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
      if (current == null) { setState(() => _saving = false); return; }

      editNotifier.update(current.copyWith(
        visitDate:          _visitDate,
        visitType:          _visitType,
        complaints:         nullIfEmpty(_complaintCtrl.text),
        examination:        _buildExamination(),
        clinicalImpression: nullIfEmpty(_diagnosisCtrl.text),
        plan:               nullIfEmpty(_treatmentCtrl.text),
        notes:              nullIfEmpty(_treatNotesCtrl.text),
        status:             'completed',
      ));
      final ok = await editNotifier.save();
      if (!mounted) return;
      setState(() {
        _saving     = false;
        _justSaved  = true;
        _savedVisit = ref.read(visitEditProvider('${widget.patientId}/${widget.visitId!}'));
      });
      if (ok) {
        await _uploadVisitFiles(widget.visitId!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Visit updated  ·  ${DateFormat('dd MMM yyyy').format(_visitDate)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            )),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
        setState(() => _step = 2);
        unawaited(_pageCtrl.animateToPage(2,
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update visit. Please try again.'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _nextStep() {
    if (_step < 1) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevStep() {
    if (_step > 0 && _step < 2) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
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
      'gender':         gender,
      'phone':          _patient!.phone ?? '—',
      'age':            _patient!.age != null ? '${_patient!.age} yrs' : '—',
      'address':        _patient!.address ?? '—',
      'email':          pn('email'),
      'weight':         _weightCtrl.text.trim().isNotEmpty ? _weightCtrl.text.trim() : pn('weight'),
      'bloodPressure':  _bpCtrl.text.trim().isNotEmpty ? _bpCtrl.text.trim() : pn('bloodPressure'),
      'temperature':    _tempCtrl.text.trim().isNotEmpty ? _tempCtrl.text.trim() : pn('temperature'),
      'allergies':      pn('allergies'),
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
      'medications':    _medicationsCtrl.text.trim(),
      'notes':          _treatNotesCtrl.text.trim(),
      'advice':         _adviceCtrl.text.trim(),
      'visitType':      visit.visitType.label,
    };
    context.push('/print-config');
  }

  // ── File helpers ──────────────────────────────────────────────────────────
  Widget _fileChip(String name, VoidCallback onClear) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _kGreen.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.insert_drive_file_rounded, color: _kGreen, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text(name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy),
          overflow: TextOverflow.ellipsis)),
      GestureDetector(onTap: onClear,
          child: const Icon(Icons.close_rounded, size: 14, color: _kMuted)),
    ]),
  );

  Future<void> _pickFiles(
      void Function(List<({String name, Uint8List bytes})>) onPicked) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final picked = result.files
            .where((f) => f.bytes != null)
            .map((f) => (name: f.name, bytes: f.bytes!))
            .toList();
        if (picked.isNotEmpty) onPicked(picked);
      }
    } catch (_) {}
  }

  Widget _fieldWithUpload({
    required String label,
    required TextEditingController controller,
    required List<({String name, Uint8List bytes})> files,
    required void Function(List<({String name, Uint8List bytes})>) onFilesChange,
    int maxLines = 2,
    IconData prefixIcon = Icons.notes_rounded,
    String hint = '',
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: _kNavy, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
          prefixIcon: Icon(prefixIcon, size: 17, color: _kMuted),
          suffixIcon: Tooltip(
            message: 'Upload files',
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(Icons.upload_file_rounded, size: 20,
                      color: files.isNotEmpty ? _kGreen : _kMuted),
                  onPressed: () => _pickFiles((picked) =>
                      setState(() => onFilesChange([...files, ...picked]))),
                ),
                if (files.isNotEmpty)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      width: 15, height: 15,
                      decoration: const BoxDecoration(
                          color: _kGreen, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${files.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
          filled: true, fillColor: _kBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kP1, width: 1.5)),
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
    ]);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(patientByIdProvider(widget.patientId));
    patientAsync.whenData((p) { if (p != null && _patient == null) _patient = p; });

    if (widget.visitId != null) {
      final visit = ref.watch(visitEditProvider('${widget.patientId}/${widget.visitId!}'));
      if (visit != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _populateFromVisit(visit));
      }
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _buildWizardHeader(),
        _buildStepBar(),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(patientAsync),
              _buildStep2(),
              _buildStep3(),
            ],
          ),
        ),
        _buildBottomNav(),
      ]),
    );
  }

  // ── Wizard header ─────────────────────────────────────────────────────────
  Widget _buildWizardHeader() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(8, 44, 16, 10),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _kNavy),
        onPressed: () {
          if (_step == 2) {
            // On preview: always go back to patient timeline
            context.go('/patients/${widget.patientId}');
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
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: _kNavy, letterSpacing: -0.3),
          ),
          Text(_stepSubtitles[_step],
              style: const TextStyle(fontSize: 12, color: _kMuted)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _kBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Step ${_step + 1} of 3',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _kBlue)),
      ),
    ]),
  );

  // ── Step bar ──────────────────────────────────────────────────────────────
  Widget _buildStepBar() => Container(
    color: Colors.white,
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
                color: segIdx < _step ? _kBlue : _kBorder,
              ),
            );
          }
          final idx      = i ~/ 2;
          final isDone    = idx < _step;
          final isCurrent = idx == _step;
          return Column(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: isDone
                    ? _kBlue
                    : isCurrent
                        ? _kBlue.withValues(alpha: 0.1)
                        : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: (isDone || isCurrent) ? _kBlue : _kBorder,
                    width: 1.5),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : idx == 2
                      ? Icon(Icons.print_outlined, size: 15,
                            color: isCurrent ? _kBlue : _kMuted)
                      : Text('${idx + 1}',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800,
                              color: isCurrent ? _kBlue : _kMuted)),
            ),
            const SizedBox(height: 4),
            Text(_stepLabels[idx],
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w600,
                    color: isCurrent ? _kBlue : isDone ? _kSlate : _kMuted,
                    letterSpacing: 0.1)),
          ]);
        }),
        // Print icon shortcut (active only on step 3)
        GestureDetector(
          onTap: _step == 2 ? _openPrint : null,
          child: Container(
            margin: const EdgeInsets.only(left: 10),
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _step == 2
                  ? _kBlue.withValues(alpha: 0.1)
                  : _kBg,
              shape: BoxShape.circle,
              border: Border.all(
                  color: _step == 2 ? _kBlue : _kBorder, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.open_in_new_rounded, size: 14,
                color: _step == 2 ? _kBlue : _kMuted),
          ),
        ),
      ],
    ),
  );

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isLast    = _step == 1;
    final isPreview = _step == 2;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!isPreview) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / 3,
              minHeight: 3,
              backgroundColor: _kBorder,
              color: _kBlue,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (isPreview) ...[
          Row(children: [
            // Edit button — only for existing visits
            if (widget.visitId != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _step = 1);
                    _pageCtrl.jumpToPage(1);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kSlate,
                    side: const BorderSide(color: _kBorder, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openPrint,
                icon: const Icon(Icons.print_outlined, size: 17),
                label: const Text('Print'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kBlue,
                  side: const BorderSide(color: _kBlue, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.go('/patients/${widget.patientId}'),
                icon: const Icon(Icons.person_outlined, size: 17),
                label: const Text('Patient'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kBlue,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ]),
        ] else
          Row(children: [
            if (_step > 0) ...[
              OutlinedButton(
                onPressed: _saving ? null : _prevStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kSlate,
                  side: const BorderSide(color: _kBorder, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 16),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: GestureDetector(
                onTap: _saving ? null : (isLast ? _save : _nextStep),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _saving
                          ? [_kBlue.withValues(alpha: 0.5),
                             _kBlue.withValues(alpha: 0.5)]
                          : [_kBlue, const Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _saving ? [] : [
                      BoxShadow(
                        color: _kBlue.withValues(alpha: 0.3),
                        blurRadius: 8, offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast
                                  ? (widget.visitId == null
                                      ? 'Save Visit'
                                      : 'Update Visit')
                                  : 'Continue',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLast
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18,
                            ),
                          ]),
                ),
              ),
            ),
          ]),
      ]),
    );
  }

  // ── Step 1 : Patient Info (read-only) ─────────────────────────────────────
  Widget _buildStep1(AsyncValue<PatientEntity?> patientAsync) {
    return patientAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kBlue)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (patient) {
        if (patient == null) {
          return const Center(child: Text('Patient not found'));
        }

        // Parse patient notes JSON for extra fields
        final notes = <String, String>{};
        if (patient.notes?.isNotEmpty == true) {
          try {
            final decoded = jsonDecode(patient.notes!) as Map<String, dynamic>;
            notes.addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
          } catch (_) {}
        }
        String n(String k) => notes[k]?.isNotEmpty == true ? notes[k]! : '—';
        String fv(String? s) => (s?.isNotEmpty == true) ? s! : '—';
        final fullName = '${patient.firstName} ${patient.lastName}'.trim();
        final gender = patient.sex?.isNotEmpty == true
            ? '${patient.sex![0].toUpperCase()}${patient.sex!.substring(1)}'
            : '—';

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Read-only notice ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Icon(Icons.lock_outline_rounded, color: _kBlue, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Patient information is auto-populated and read-only. '
                  'Treatment fields are editable in the next step.',
                  style: TextStyle(
                      fontSize: 12, color: _kBlue,
                      fontWeight: FontWeight.w500),
                )),
              ]),
            ),
            const SizedBox(height: 14),

            // ── Visit Date & Type ────────────────────────────────────────
            _WizardCard(
              title: 'Visit Details',
              icon: Icons.calendar_today_outlined,
              color: _kBlue,
              child: Column(children: [
                // Visit Date
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _visitDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      builder: (c, w) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: _kBlue),
                        ),
                        child: w!,
                      ),
                    );
                    if (d != null) setState(() => _visitDate = d);
                  },
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Visit Date',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _kSlate)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 17, color: _kMuted),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('dd MMMM yyyy').format(_visitDate),
                          style: const TextStyle(
                              fontSize: 14, color: _kNavy,
                              fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_outlined, size: 15, color: _kMuted),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                // Visit Type
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Visit Type',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _kSlate)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _visitType.label,
                    items: _kVisitTypeLabels
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
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
                      prefixIcon: const Icon(
                          Icons.local_hospital_outlined, size: 17, color: _kMuted),
                      filled: true, fillColor: _kBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _kBlue, width: 1.5)),
                    ),
                    style: const TextStyle(
                        fontSize: 14, color: _kNavy, fontWeight: FontWeight.w500),
                  ),
                ]),
              ]),
            ),

            // ── Patient Basic Info ────────────────────────────────────────
            _WizardCard(
              title: 'Basic Information',
              icon: Icons.person_outline_rounded,
              color: _kBlue,
              badge: 'Read-only',
              child: Column(children: [
                _roRow('Full Name', fullName),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _roRow('Age',
                      patient.age != null ? '${patient.age} yrs' : '—')),
                  const SizedBox(width: 12),
                  Expanded(child: _roRow('Gender', gender)),
                ]),
                const SizedBox(height: 10),
                _roRow('UHID', patient.prn),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _roRow('Phone', fv(patient.phone))),
                  const SizedBox(width: 12),
                  Expanded(child: _roRow('Alt Phone', n('altPhone'))),
                ]),
                const SizedBox(height: 10),
                _roRow('Email', n('email')),
                const SizedBox(height: 10),
                _roRow('Address', fv(patient.address)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _roRow('ID Proof Type', n('idProofType'))),
                  const SizedBox(width: 12),
                  Expanded(child: _roRow('ID Number', n('idProofNumber'))),
                ]),
              ]),
            ),

            // ── Vitals reference (from registration) ──────────────────────
            _WizardCard(
              title: 'Vitals & Clinical Snapshot',
              icon: Icons.monitor_heart_outlined,
              color: _kRed,
              badge: 'Read-only',
              child: Column(children: [
                Row(children: [
                  Expanded(child: _roRow('Weight', n('weight'))),
                  const SizedBox(width: 12),
                  Expanded(child: _roRow('Blood Pressure', n('bloodPressure'))),
                  const SizedBox(width: 12),
                  Expanded(child: _roRow('Temperature', n('temperature'))),
                ]),
                const SizedBox(height: 10),
                _roRow('Known Allergies', n('allergies')),
                const SizedBox(height: 10),
                _roRow('Medical History', n('clinicalNotes')),
              ]),
            ),
          ],
        );
      },
    );
  }

  // Read-only field row for Step 1
  Widget _roRow(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: _kMuted)),
      const SizedBox(height: 4),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Text(value,
            style: const TextStyle(
                fontSize: 13, color: _kNavy, fontWeight: FontWeight.w500)),
      ),
    ],
  );

  // ── Step 2 : Treatment (exact same as patient registration) ───────────────
  Widget _buildStep2() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [
      // ── Vitals (editable per visit) ──────────────────────────────────
      _WizardCard(
        title: 'Vitals',
        icon: Icons.monitor_heart_outlined,
        color: _kRed,
        child: Column(children: [
          Row(children: [
            Expanded(child: _vField(
              label: 'Weight',
              controller: _weightCtrl,
              prefixIcon: Icons.monitor_weight_outlined,
              hint: '65 kg',
            )),
            const SizedBox(width: 12),
            Expanded(child: _vField(
              label: 'Blood Pressure',
              controller: _bpCtrl,
              prefixIcon: Icons.favorite_border_rounded,
              hint: '120/80',
            )),
            const SizedBox(width: 12),
            Expanded(child: _vField(
              label: 'Temperature',
              controller: _tempCtrl,
              prefixIcon: Icons.thermostat_outlined,
              hint: '37.1 °C',
            )),
          ]),
        ]),
      ),

      // ── History & Complaint ──────────────────────────────────────────
      _WizardCard(
        title: 'History & Complaint',
        icon: Icons.history_edu_outlined,
        color: _kBlue,
        child: Column(children: [
          _fieldWithUpload(
            label: 'Previous History',
            controller: _prevHistoryCtrl,
            files: _prevHistoryFiles,
            onFilesChange: (f) => _prevHistoryFiles..clear()..addAll(f),
            maxLines: 3,
            prefixIcon: Icons.history_edu_outlined,
            hint: 'Enter previous medical history…',
          ),
          const SizedBox(height: 12),
          _fieldWithUpload(
            label: 'Chief Complaint',
            controller: _complaintCtrl,
            files: _chiefComplaintFiles,
            onFilesChange: (f) => _chiefComplaintFiles..clear()..addAll(f),
            prefixIcon: Icons.report_problem_outlined,
            hint: 'Primary reason for visit…',
          ),
        ]),
      ),

      // ── Examination Finding ──────────────────────────────────────────
      _WizardCard(
        title: 'Examination Finding',
        icon: Icons.person_search_outlined,
        color: _kBlue2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Tab bar
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _examTab = 'general'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _examTab == 'general' ? _kBlue : Colors.white,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10)),
                    border: Border.all(
                        color: _examTab == 'general' ? _kBlue : _kBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text('General',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _examTab == 'general'
                              ? Colors.white
                              : _kSlate)),
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
                    color: _examTab == 'neurological' ? _kBlue : Colors.white,
                    borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(10),
                        bottomRight: Radius.circular(10)),
                    border: Border.all(
                        color: _examTab == 'neurological'
                            ? _kBlue
                            : _kBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text('Neurological',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _examTab == 'neurological'
                              ? Colors.white
                              : _kSlate)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_examTab == 'general') ...[
            TextFormField(
              controller: _examGeneralCtrl,
              maxLines: 3,
              style: const TextStyle(
                  fontSize: 14, color: _kNavy, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'General examination findings…',
                hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.person_search_outlined,
                    size: 17, color: _kMuted),
                suffixIcon: Tooltip(
                  message: 'Upload files',
                  child: Stack(alignment: Alignment.center,
                      clipBehavior: Clip.none, children: [
                    IconButton(
                      icon: Icon(Icons.upload_file_rounded, size: 20,
                          color: _examGeneralFiles.isNotEmpty
                              ? _kGreen
                              : _kMuted),
                      onPressed: () => _pickFiles((picked) =>
                          setState(() => _examGeneralFiles.addAll(picked))),
                    ),
                    if (_examGeneralFiles.isNotEmpty)
                      Positioned(right: 6, top: 6,
                        child: Container(
                          width: 15, height: 15,
                          decoration: const BoxDecoration(
                              color: _kGreen, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${_examGeneralFiles.length}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 8,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ]),
                ),
                filled: true, fillColor: _kBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _kP1, width: 1.5)),
              ),
            ),
            if (_examGeneralFiles.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6,
                  children: List.generate(_examGeneralFiles.length, (idx) =>
                    _fileChip(_examGeneralFiles[idx].name, () =>
                        setState(() => _examGeneralFiles.removeAt(idx))))),
            ],
          ] else ...[
            TextFormField(
              controller: _examNeurologicalCtrl,
              maxLines: 3,
              style: const TextStyle(
                  fontSize: 14, color: _kNavy, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Neurological examination findings…',
                hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.psychology_outlined,
                    size: 17, color: _kMuted),
                suffixIcon: Tooltip(
                  message: 'Upload files',
                  child: Stack(alignment: Alignment.center,
                      clipBehavior: Clip.none, children: [
                    IconButton(
                      icon: Icon(Icons.upload_file_rounded, size: 20,
                          color: _examNeurologicalFiles.isNotEmpty
                              ? _kGreen
                              : _kMuted),
                      onPressed: () => _pickFiles((picked) =>
                          setState(() =>
                              _examNeurologicalFiles.addAll(picked))),
                    ),
                    if (_examNeurologicalFiles.isNotEmpty)
                      Positioned(right: 6, top: 6,
                        child: Container(
                          width: 15, height: 15,
                          decoration: const BoxDecoration(
                              color: _kGreen, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${_examNeurologicalFiles.length}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 8,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ]),
                ),
                filled: true, fillColor: _kBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _kP1, width: 1.5)),
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
          ],
        ]),
      ),

      // ── Investigation ────────────────────────────────────────────────
      _WizardCard(
        title: 'Investigation',
        icon: Icons.science_outlined,
        color: _kGreen,
        child: Column(children: [
          _fieldWithUpload(
            label: 'Diagnosis',
            controller: _clinicalDiagnosisCtrl,
            files: _clinicalDiagnosisFiles,
            onFilesChange: (f) => _clinicalDiagnosisFiles..clear()..addAll(f),
            prefixIcon: Icons.local_hospital_outlined,
            hint: 'Clinical diagnosis…',
          ),
          const SizedBox(height: 12),
          _fieldWithUpload(
            label: 'Imaging',
            controller: _imagingCtrl,
            files: _imagingFiles,
            onFilesChange: (f) => _imagingFiles..clear()..addAll(f),
            prefixIcon: Icons.image_search_rounded,
            hint: 'Imaging findings (X-Ray, MRI, CT…)',
          ),
          const SizedBox(height: 12),
          _fieldWithUpload(
            label: 'Other Investigation',
            controller: _otherInvestCtrl,
            files: _otherInvestFiles,
            onFilesChange: (f) => _otherInvestFiles..clear()..addAll(f),
            prefixIcon: Icons.biotech_outlined,
            hint: 'Lab reports, other tests…',
          ),
        ]),
      ),

      // ── Clinical Plan ────────────────────────────────────────────────
      _WizardCard(
        title: 'Clinical Plan',
        icon: Icons.assignment_outlined,
        color: _kBlue,
        child: Column(children: [
          _fieldWithUpload(
            label: 'Impression',
            controller: _diagnosisCtrl,
            files: _impressionFiles,
            onFilesChange: (f) => _impressionFiles..clear()..addAll(f),
            prefixIcon: Icons.rule_outlined,
            hint: 'Clinical impression…',
          ),
          const SizedBox(height: 12),
          _fieldWithUpload(
            label: 'Plan',
            controller: _treatmentCtrl,
            files: _planFiles,
            onFilesChange: (f) => _planFiles..clear()..addAll(f),
            prefixIcon: Icons.assignment_outlined,
            hint: 'Recommended plan…',
          ),
          const SizedBox(height: 12),
          _fieldWithUpload(
            label: 'Treatment',
            controller: _medicationsCtrl,
            files: _treatmentMedFiles,
            onFilesChange: (f) => _treatmentMedFiles..clear()..addAll(f),
            prefixIcon: Icons.medication_outlined,
            hint: 'e.g. Aspirin 325 mg · Metoprolol 25 mg…',
          ),
          const SizedBox(height: 12),
          _vField(
            label: 'Notes',
            controller: _treatNotesCtrl,
            maxLines: 3,
            prefixIcon: Icons.notes_rounded,
            hint: 'Additional clinical notes…',
          ),
          const SizedBox(height: 12),
          _vField(
            label: 'Advice',
            controller: _adviceCtrl,
            maxLines: 3,
            prefixIcon: Icons.tips_and_updates_outlined,
            hint: 'Advice given to patient…',
          ),
        ]),
      ),
    ],
  );

  // Simple text field (no file upload) for Step 2
  Widget _vField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    IconData? prefixIcon,
    String? hint,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate)),
    const SizedBox(height: 6),
    TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
          fontSize: 14, color: _kNavy, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 17, color: _kMuted)
            : null,
        filled: true, fillColor: _kBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kP1, width: 1.5)),
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
            style: const TextStyle(
                fontSize: 9, color: _kMuted,
                fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontSize: 13, color: _kNavy, fontWeight: FontWeight.w600)),
      ]),
    );

    Widget eRow(String label, String value,
        List<({String name, Uint8List bytes})> files) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 124,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, color: _kMuted, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            if (value.isNotEmpty)
              Text(value,
                  style: const TextStyle(
                      fontSize: 12, color: _kNavy,
                      fontWeight: FontWeight.w600))
            else if (files.isEmpty)
              const Text('—',
                  style: TextStyle(
                      fontSize: 12, color: _kMuted,
                      fontWeight: FontWeight.w500)),
            if (files.isNotEmpty) ...[
              if (value.isNotEmpty) const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4,
                  children: files.map((f) => _fileViewChip(f)).toList()),
            ],
          ]),
        ),
      ]),
    );

    Widget pRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 124,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, color: _kMuted, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12, color: _kNavy,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );

    Widget sCard(String title, IconData icon, Color color, Widget body) =>
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2),
            )],
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
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: _kNavy)),
              ]),
            ),
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: body,
            ),
          ]),
        );

    Widget twoCol(Widget left, Widget right) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ]),
      ),
    );

    const vDiv = SizedBox(
      width: 28,
      child: Center(child: VerticalDivider(
          thickness: 1, color: _kBorder, width: 1)),
    );

    // ── Visit vitals: prefer this-visit values, fall back to patient registration
    final wt   = _weightCtrl.text.trim().isNotEmpty ? _weightCtrl.text.trim() : n('weight');
    final bp   = _bpCtrl.text.trim().isNotEmpty    ? _bpCtrl.text.trim()     : n('bloodPressure');
    final temp = _tempCtrl.text.trim().isNotEmpty   ? _tempCtrl.text.trim()   : n('temperature');

    // Loading overlay for edit mode while visit data is fetching
    if (_visitLoading) {
      return const Center(child: CircularProgressIndicator(color: _kBlue));
    }

    // Determine banner style: success (after save) vs info (viewing existing)
    final isViewMode = widget.visitId != null && !_justSaved;
    final bannerColor  = isViewMode ? _kBlue  : _kGreen;
    final bannerIcon   = isViewMode ? Icons.assignment_outlined : Icons.check_rounded;
    final bannerTitle  = isViewMode
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
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: _kNavy,
                        fontSize: 15)),
                RichText(text: TextSpan(children: [
                  const TextSpan(text: 'Date: ',
                      style: TextStyle(color: _kMuted, fontSize: 11)),
                  TextSpan(
                    text: DateFormat('dd MMM yyyy').format(_visitDate),
                    style: TextStyle(
                        color: bannerColor, fontWeight: FontWeight.w700,
                        fontSize: 11),
                  ),
                  const TextSpan(text: '  ·  ',
                      style: TextStyle(color: _kMuted, fontSize: 11)),
                  TextSpan(text: fullName,
                      style: const TextStyle(
                          color: _kNavy, fontSize: 11)),
                  const TextSpan(text: '  ·  ',
                      style: TextStyle(color: _kMuted, fontSize: 11)),
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
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 11),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Patient Information ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: sCard('Patient Information', Icons.person_outline_rounded,
              _kBlue,
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  iField('Full Name', fullName.isEmpty ? '—' : fullName),
                  iField('Age',
                      p?.age != null ? '${p!.age} yrs' : '—'),
                  iField('Phone', fv(p?.phone)),
                  iField('Email', n('email')),
                  iField('ID Proof Type', n('idProofType')),
                ])),
                vDiv,
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  iField('UHID', p?.prn ?? '—'),
                  iField('Gender', gender),
                  iField('Alt Phone', n('altPhone')),
                  iField('Address', fv(p?.address)),
                  iField('ID Number', n('idProofNumber')),
                ])),
              ]),
            ),
          ),
        ),

        // ── Vitals | Clinical Snapshot ────────────────────────────────────
        twoCol(
          sCard('Vitals', Icons.monitor_heart_outlined, _kRed,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              pRow('Weight', fv(wt)),
              pRow('Blood Pressure', fv(bp)),
              pRow('Temperature', fv(temp)),
            ]),
          ),
          sCard('Clinical Snapshot', Icons.health_and_safety_outlined,
              _kAmber,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              pRow('Known Allergies', n('allergies')),
              pRow('Medical History', n('clinicalNotes')),
            ]),
          ),
        ),

        // ── History & Complaint | Examination Finding ─────────────────────
        twoCol(
          sCard('History & Complaint', Icons.history_edu_outlined,
              const Color(0xFF6366F1),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('Previous History',
                  _prevHistoryCtrl.text.trim(), _prevHistoryFiles),
              eRow('Chief Complaint',
                  _complaintCtrl.text.trim(), _chiefComplaintFiles),
            ]),
          ),
          sCard('Examination Finding', Icons.search_outlined,
              const Color(0xFF0EA5E9),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('General',
                  _examGeneralCtrl.text.trim(), _examGeneralFiles),
              eRow('Neurological',
                  _examNeurologicalCtrl.text.trim(), _examNeurologicalFiles),
            ]),
          ),
        ),

        // ── Investigation | Clinical Plan ─────────────────────────────────
        twoCol(
          sCard('Investigation', Icons.science_outlined,
              const Color(0xFFF59E0B),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('Clinical Diagnosis',
                  _clinicalDiagnosisCtrl.text.trim(), _clinicalDiagnosisFiles),
              eRow('Imaging', _imagingCtrl.text.trim(), _imagingFiles),
              eRow('Other Investigation',
                  _otherInvestCtrl.text.trim(), _otherInvestFiles),
            ]),
          ),
          sCard('Clinical Plan', Icons.assignment_outlined, _kBlue,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('Impression',
                  _diagnosisCtrl.text.trim(), _impressionFiles),
              eRow('Plan', _treatmentCtrl.text.trim(), _planFiles),
              eRow('Treatment',
                  _medicationsCtrl.text.trim(), _treatmentMedFiles),
              pRow('Notes', fv(_treatNotesCtrl.text.trim())),
              pRow('Advice', fv(_adviceCtrl.text.trim())),
            ]),
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
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.visibility_outlined, color: _kBlue, size: 14),
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
              decoration: const BoxDecoration(
                color: _kWiz,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: _kBorder)),
              ),
              child: Row(children: [
                Icon(isImage
                    ? Icons.image_outlined
                    : Icons.insert_drive_file_outlined,
                    color: _kBlue, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(f.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: _kNavy,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: _kMuted,
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
                        const Icon(Icons.insert_drive_file_rounded,
                            size: 72, color: _kMuted),
                        const SizedBox(height: 16),
                        Text(f.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: _kNavy),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('${(f.bytes.length / 1024).toStringAsFixed(1)} KB',
                            style: const TextStyle(
                                fontSize: 12, color: _kMuted)),
                        const SizedBox(height: 16),
                        const Text(
                          'Preview not available for this file type.',
                          style: TextStyle(fontSize: 12, color: _kMuted),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                style: const TextStyle(
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
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: child,
        ),
      ]),
    ),
  );
}
