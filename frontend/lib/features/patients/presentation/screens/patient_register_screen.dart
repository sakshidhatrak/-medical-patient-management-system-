// ─────────────────────────────────────────────────────────────────────────────
// patient_register_screen.dart  –  Comprehensive Patient Registration
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/patient_entity.dart';
import '../providers/patient_provider.dart';
import '../../../photos/domain/entities/photo_entity.dart';
import '../../../photos/presentation/providers/photo_provider.dart';
import '../../../print_configuration/presentation/providers/print_config_provider.dart';
import '../../../visits/domain/entities/visit_entity.dart';
import '../../../visits/presentation/providers/visit_provider.dart';
import '../../../medicines/data/medicine_service.dart';

// ── Fixed accent colours ───────────────────────────────────────────────────────
const _kBlue  = Color(0xFF5B5ECC);
const _kBlue2 = Color(0xFF4B55CC);
const _kP1    = Color(0xFF5B5ECC);
const _kRed   = Color(0xFFE07878);
const _kAmber = Color(0xFFD4A855);
const _kGreen = Color(0xFF4EC080);

// ── Theme-aware surface / text colours ────────────────────────────────────────
bool  _isDarkCtx(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _kBg    (BuildContext c) => _isDarkCtx(c) ? const Color(0xFF171629) : const Color(0xFFF8F6F2);
Color _kCard  (BuildContext c) => _isDarkCtx(c) ? const Color(0xFF252545) : Colors.white;
Color _kInput (BuildContext c) => _isDarkCtx(c) ? const Color(0xFF1E1C35) : const Color(0xFFECEAE4);
Color _kNavy  (BuildContext c) => _isDarkCtx(c) ? const Color(0xFFEEECFF) : const Color(0xFF302D28);
Color _kSlate (BuildContext c) => _isDarkCtx(c) ? const Color(0xFFCCCAE8) : const Color(0xFF6E6A63);
Color _kMuted (BuildContext c) => _isDarkCtx(c) ? const Color(0xFF9896B8) : const Color(0xFF979088);
Color _kBorder(BuildContext c) => _isDarkCtx(c) ? const Color(0xFF3A3865) : const Color(0xFFE0DDD7);


class PatientRegisterScreen extends ConsumerStatefulWidget {
  const PatientRegisterScreen({super.key});
  @override
  ConsumerState<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends ConsumerState<PatientRegisterScreen> {
  // ── Basic Info ────────────────────────────────────────────────────────────
  final _firstCtrl  = TextEditingController();
  final _lastCtrl   = TextEditingController();
  final _ageCtrl    = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _altCtrl      = TextEditingController();
  final _idProofCtrl  = TextEditingController();
  String? _sex;
  String? _idProofType;

  // ── Address ───────────────────────────────────────────────────────────────
  final _addressCtrl = TextEditingController();

  // ── Vitals ────────────────────────────────────────────────────────────────
  final _weightCtrl = TextEditingController();
  final _bpCtrl     = TextEditingController();
  final _tempCtrl   = TextEditingController();

  // ── Treatment Information ─────────────────────────────────────────────────
  final _prevHistoryCtrl = TextEditingController();
  final _prevHistoryFiles = <({String name, Uint8List bytes})>[];

  final _complaintCtrl = TextEditingController();
  final _chiefComplaintFiles = <({String name, Uint8List bytes})>[];

  // Examination Finding
  String _examTab = 'general';
  final _examGeneralCtrl      = TextEditingController();
  final _examGeneralFiles     = <({String name, Uint8List bytes})>[];
  final _examNeurologicalCtrl = TextEditingController();
  final _examNeurologicalFiles = <({String name, Uint8List bytes})>[];

  // Diagnosis / Imaging / Other Investigation
  final _clinicalDiagnosisCtrl  = TextEditingController();
  final _clinicalDiagnosisFiles = <({String name, Uint8List bytes})>[];
  final _imagingCtrl            = TextEditingController();
  final _imagingFiles           = <({String name, Uint8List bytes})>[];
  final _otherInvestCtrl        = TextEditingController();
  final _otherInvestFiles       = <({String name, Uint8List bytes})>[];

  final _diagnosisCtrl   = TextEditingController();   // Impression
  final _impressionFiles = <({String name, Uint8List bytes})>[];
  final _treatmentCtrl   = TextEditingController();   // Plan
  final _planFiles       = <({String name, Uint8List bytes})>[];
  final _treatmentMedFiles = <({String name, Uint8List bytes})>[];
  final _prescriptionRows  = <_PrescriptionRow>[];   // Structured prescriptions
  final _treatNotesCtrl      = TextEditingController();
  final _adviceCtrl          = TextEditingController();
  final _crossConsultCtrl    = TextEditingController();
  final _crossConsultFiles   = <({String name, Uint8List bytes})>[];

  // ── Clinical Snapshot ─────────────────────────────────────────────────────
  final _allergyCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();

  // ── Wizard state ──────────────────────────────────────────────────────────
  int _step = 0;
  final _pageCtrl = PageController();
  final _step1Key = GlobalKey<FormState>();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _saving = false;
  List<PatientEntity> _duplicates = [];
  PatientEntity? _savedPatient;

  static const _sexOptions     = ['Male', 'Female', 'Other'];
  static const _idProofOptions = ['Aadhaar Card', 'PAN Card'];

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [
      _firstCtrl, _lastCtrl, _ageCtrl, _emailCtrl, _phoneCtrl, _altCtrl, _idProofCtrl,
      _addressCtrl,
      _weightCtrl, _bpCtrl, _tempCtrl,
      _prevHistoryCtrl,
      _complaintCtrl,
      _examGeneralCtrl, _examNeurologicalCtrl,
      _clinicalDiagnosisCtrl, _imagingCtrl, _otherInvestCtrl,
      _diagnosisCtrl, _treatmentCtrl,
      _treatNotesCtrl, _adviceCtrl, _crossConsultCtrl,
      _allergyCtrl, _historyCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _checkDuplicates() async {
    final name = _firstCtrl.text.trim();
    if (name.length < 3) { setState(() => _duplicates = []); return; }
    final dupes = await ref.read(patientsProvider.notifier)
        .searchDuplicates(name, _phoneCtrl.text.trim());
    setState(() => _duplicates = dupes);
  }

  bool _hasAnyTreatmentData() =>
      _prescriptionRows.isNotEmpty ||
      [
        _prevHistoryCtrl, _complaintCtrl, _examGeneralCtrl, _examNeurologicalCtrl,
        _clinicalDiagnosisCtrl, _imagingCtrl, _otherInvestCtrl,
        _diagnosisCtrl, _treatmentCtrl, _treatNotesCtrl, _adviceCtrl,
      ].any((c) => c.text.trim().isNotEmpty);

  String? _buildExaminationJson() {
    final m = <String, String>{};
    void add(String k, String v) { if (v.isNotEmpty) m[k] = v; }
    add('previousHistory',    _prevHistoryCtrl.text.trim());
    add('examGeneral',        _examGeneralCtrl.text.trim());
    add('examNeurological',   _examNeurologicalCtrl.text.trim());
    add('clinicalDiagnosis',  _clinicalDiagnosisCtrl.text.trim());
    add('imaging',            _imagingCtrl.text.trim());
    add('otherInvestigation', _otherInvestCtrl.text.trim());
    if (_prescriptionRows.isNotEmpty) {
      m['prescriptions'] = jsonEncode(_prescriptionRows.map((r) => r.toJson()).toList());
      add('medications', _prescriptionRows.map((r) =>
          '${r.medicine}${r.dose.isNotEmpty ? " [${r.dose}]" : ""}${r.route.isNotEmpty ? " (${r.route})" : ""}${r.frequency.isNotEmpty ? " - ${r.frequency}" : ""}${r.duration.isNotEmpty ? " × ${r.duration}" : ""}${r.specialInstruction.isNotEmpty ? " | ${r.specialInstruction}" : ""}').join('\n'));
    }
    add('advice',             _adviceCtrl.text.trim());
    add('crossConsultation',  _crossConsultCtrl.text.trim());
    add('weight',             _weightCtrl.text.trim());
    add('bp',                 _bpCtrl.text.trim());
    add('temperature',        _tempCtrl.text.trim());
    return m.isEmpty ? null : jsonEncode(m);
  }

  Future<void> _save() async {
    // Guard against double-tap or back-then-resubmit duplicates.
    if (_saving || _savedPatient != null) return;
    setState(() => _saving = true);

    try {
      // Timeout guards against a SQLite deadlock leaving the spinner frozen.
      // Patient stores only static demographic/contact/history info.
      // All treatment/clinical data is stored in the auto-created first OPD visit below.
      final patient = await ref.read(patientsProvider.notifier).createPatient(
        firstName:       _firstCtrl.text.trim(),
        lastName:        _lastCtrl.text.trim(),
        age:             _ageCtrl.text.isNotEmpty ? int.tryParse(_ageCtrl.text.trim()) : null,
        sex:             _sex?.toLowerCase(),
        phone:           _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address:         _fullAddress,
        altPhone:        _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
        email:           _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        idProofType:     _idProofType,
        idProofNumber:   _idProofCtrl.text.trim().isEmpty ? null : _idProofCtrl.text.trim(),
        weight:          _weightCtrl.text.trim().isEmpty ? null : _weightCtrl.text.trim(),
        bloodPressure:   _bpCtrl.text.trim().isEmpty ? null : _bpCtrl.text.trim(),
        temperature:     _tempCtrl.text.trim().isEmpty ? null : _tempCtrl.text.trim(),
        allergies:       _allergyCtrl.text.trim().isEmpty ? null : _allergyCtrl.text.trim(),
        medicalHistory:  _historyCtrl.text.trim().isEmpty ? null : _historyCtrl.text.trim(),
        previousHistory: _prevHistoryCtrl.text.trim().isEmpty ? null : _prevHistoryCtrl.text.trim(),
      ).timeout(const Duration(seconds: 12), onTimeout: () => null);

      if (!mounted) return;
      setState(() { _saving = false; _savedPatient = patient; });

      if (patient != null) {
        // ── Always create first OPD visit so it's visible on patient profile ──
        String? firstVisitId;
        {
          final visit = await ref
              .read(visitsProvider(patient.id).notifier)
              .createFullVisit(
                patientId:          patient.id,
                type:               VisitType.opd,
                visitDate:          DateTime.now(),
                complaints:         _complaintCtrl.text.trim().isEmpty ? null : _complaintCtrl.text.trim(),
                examination:        _buildExaminationJson(),
                clinicalImpression: _diagnosisCtrl.text.trim().isEmpty ? null : _diagnosisCtrl.text.trim(),
                plan:               _treatmentCtrl.text.trim().isEmpty ? null : _treatmentCtrl.text.trim(),
                // Default note ensures the visit is created even if clinical fields are blank.
                notes:              _treatNotesCtrl.text.trim().isNotEmpty
                                      ? _treatNotesCtrl.text.trim()
                                      : 'Patient registration',
              )
              .timeout(const Duration(seconds: 12), onTimeout: () => null);
          firstVisitId = visit?.id;
        }

        // Always persist medications to prescriptions cache so future visits can
        // suggest them. Use the auto-created visit ID if available; fall back to a
        // registration-scoped key so prescription is saved even when the API is
        // unreachable (visit returns null despite being stored locally).
        final medNames = _prescriptionRows.map((r) =>
            '${r.medicine}${r.dose.isNotEmpty ? " [${r.dose}]" : ""}${r.route.isNotEmpty ? " (${r.route})" : ""}${r.frequency.isNotEmpty ? " - ${r.frequency}" : ""}${r.duration.isNotEmpty ? " × ${r.duration}" : ""}').join('\n');
        if (medNames.isNotEmpty) {
          final presVisitId = firstVisitId ?? 'reg_${patient.id}';
          unawaited(ref.read(medicineServiceProvider).savePrescription(
            visitId: presVisitId,
            patientId: patient.id,
            visitDate: DateTime.now(),
            medicationsText: medNames,
          ));
        }

        // Upload all per-field files (link to first visit if created)
        final allFieldFiles = <({String name, Uint8List bytes, String caption, PhotoCategory cat})>[
          ..._prevHistoryFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'Previous History', cat: PhotoCategory.visit)),
          ..._chiefComplaintFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'Chief Complaint', cat: PhotoCategory.visit)),
          ..._examGeneralFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'General Examination', cat: PhotoCategory.examination)),
          ..._examNeurologicalFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'Neurological Examination', cat: PhotoCategory.examination)),
          ..._clinicalDiagnosisFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'Clinical Diagnosis', cat: PhotoCategory.visit)),
          ..._imagingFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'Imaging', cat: PhotoCategory.radiology)),
          ..._otherInvestFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'Other Investigations', cat: PhotoCategory.visit)),
          ..._impressionFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'Impression', cat: PhotoCategory.treatment)),
          ..._planFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'Plan', cat: PhotoCategory.treatment)),
          ..._treatmentMedFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'Treatment', cat: PhotoCategory.treatment)),
          ..._crossConsultFiles.map((f) => (name: f.name, bytes: f.bytes, caption: 'Cross Consultation', cat: PhotoCategory.visit)),
        ];
        if (allFieldFiles.isNotEmpty) {
          final photoNotifier = ref.read(photoProvider(patient.id).notifier);
          for (final f in allFieldFiles) {
            await photoNotifier.upload(
              bytes:    f.bytes,
              filename: f.name,
              category: f.cat,
              visitId:  firstVisitId,
              caption:  f.caption,
            );
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Patient registered  ·  UHID: ${patient.prn}',
                style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
        context.go('/patients/${patient.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Registration failed. Please try again.'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Registration failed. Please try again.'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      // Always clear the spinner — no exception can leave it stuck forever.
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  void _nextStep() {
    if (_step == 0) {
      if (!(_step1Key.currentState?.validate() ?? true)) return;
    }
    if (_step < 1) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevStep() {
    // Once saved, back arrow exits to patient list instead of re-entering the form.
    if (_savedPatient != null) {
      context.go('/patients');
      return;
    }
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  String? get _fullAddress {
    final v = _addressCtrl.text.trim();
    return v.isEmpty ? null : v;
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
            color: _kInput(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder(context)),
          ),
          child: Column(children: [
            Icon(Icons.medication_outlined, color: _kMuted(context), size: 28),
            const SizedBox(height: 6),
            Text('No medicines added',
                style: TextStyle(fontSize: 12, color: _kMuted(context))),
            const SizedBox(height: 2),
            Text('Tap "Add Medicine" to prescribe',
                style: TextStyle(fontSize: 11, color: _kMuted(context).withValues(alpha: 0.7))),
          ]),
        )
      else ...[
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
            color: _kInput(context),
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
                      Icon(Icons.info_outline_rounded, size: 11, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Expanded(child: Text(row.specialInstruction,
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade700,
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
        patientId: '',
        medicineService: ref.read(medicineServiceProvider),
      ),
    );
    if (result != null && result.medicine.isNotEmpty) {
      setState(() => _prescriptionRows.add(result));
    }
  }

  Widget _fileChip(String name, VoidCallback onClear) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _kGreen.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      Icon(Icons.insert_drive_file_rounded, color: _kGreen, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text(name,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy(context)),
          overflow: TextOverflow.ellipsis)),
      GestureDetector(onTap: onClear, child: Icon(Icons.close_rounded, size: 14, color: _kMuted(context))),
    ]),
  );

  Future<void> _pickFiles(
    void Function(List<({String name, Uint8List bytes})>) onPicked,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Upload from', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _mediaOptionTile(ctx, 'Camera', Icons.camera_alt_rounded, const Color(0xFF4B55CC), 'camera')),
            const SizedBox(width: 12),
            Expanded(child: _mediaOptionTile(ctx, 'Gallery / Files', Icons.photo_library_rounded, const Color(0xFF059669), 'gallery')),
          ]),
        ]),
      ),
    );
    if (choice == null) return;
    try {
      if (choice == 'camera') {
        final picker = ImagePicker();
        final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (img == null) return;
        final bytes = await img.readAsBytes();
        final name = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        onPicked([(name: name, bytes: bytes)]);
      } else {
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
      }
    } catch (_) {}
  }

  Widget _mediaOptionTile(BuildContext ctx, String label, IconData icon, Color color, String value) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
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
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate(context))),
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
                      color: files.isNotEmpty ? _kGreen : _kMuted(context)),
                  onPressed: () => _pickFiles((picked) =>
                      setState(() => onFilesChange([...files, ...picked]))),
                ),
                if (files.isNotEmpty)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      width: 15, height: 15,
                      decoration: BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${files.length}',
                          style: TextStyle(
                              color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
          filled: true,
          fillColor: _kInput(context),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBorder(context))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBorder(context))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kP1, width: 1.5)),
        ),
      ),
      if (files.isNotEmpty) ...[
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(files.length, (idx) {
            final f = files[idx];
            return _fileChip(f.name, () => setState(() {
              final updated = [...files];
              updated.removeAt(idx);
              onFilesChange(updated);
            }));
          }),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg(context),
      body: SafeArea(
        child: Column(children: [
          _buildWizardHeader(),
          _buildStepBar(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
          _buildBottomNav(),
        ]),
      ),
    );
  }

  static const _stepLabels = ['Patient Info', 'Treatment & Advice', 'Preview & Print'];
  static const _stepSubtitles = [
    'Identity, contact & vitals',
    'Treatment & clinical plan',
    'Review record & print options',
  ];
  static const _stepIcons = [
    Icons.person_outline_rounded,
    Icons.medical_services_outlined,
    Icons.preview_outlined,
  ];

  Widget _buildWizardHeader() => Container(
    color: _kCard(context),
    padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
    child: Row(children: [
      IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: _kNavy(context), size: 18),
        onPressed: _prevStep,
      ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New Patient Registration',
              style: TextStyle(color: _kNavy(context), fontWeight: FontWeight.w800, fontSize: 17)),
          Text(_stepSubtitles[_step],
              style: TextStyle(color: _kMuted(context), fontSize: 12)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Step ${_step + 1} of 3',
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ]),
  );

  Widget _buildStepBar() => Container(
    color: _kCard(context),
    padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: List.generate(_stepLabels.length * 2 - 1, (i) {
              if (i.isOdd) {
                final segIdx = i ~/ 2;
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 22),
                    color: segIdx < _step ? _kBlue : _kBorder(context),
                  ),
                );
              }
              final idx = i ~/ 2;
              final isDone    = idx < _step;
              final isCurrent = idx == _step;
              return GestureDetector(
                onTap: () {
                  setState(() => _step = idx);
                  _pageCtrl.animateToPage(idx,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                    child: Center(
                      child: isDone
                          ? Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : idx == 2
                              ? Icon(Icons.print_outlined,
                                    color: Colors.white, size: 16)
                              : Text('${idx + 1}',
                                  style: TextStyle(
                                    color: isCurrent ? Colors.white : _kMuted(context),
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                  )),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stepLabels[idx],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? _kBlue : (isDone ? _kSlate(context) : _kMuted(context)),
                    ),
                  ),
                ]),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),
        Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: _step == 2 ? _openPrint : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _step == 2 ? _kBlue.withValues(alpha: 0.15) : _kInput(context),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: _step == 2 ? _kBlue : _kBorder(context),
                ),
              ),
              child: Icon(Icons.print_outlined, size: 16,
                  color: _step == 2 ? _kBlue : _kMuted(context)),
            ),
          ),
          const SizedBox(height: 26),
        ]),
      ],
    ),
  );

  Widget _buildBottomNav() {
    final isLast    = _step == 1;   // Treatment → triggers save → goes to preview
    final isPreview = _step == 2;   // Preview & Print step
    return Container(
      color: _kCard(context),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: _kBorder(context),
            valueColor: const AlwaysStoppedAnimation<Color>(_kBlue),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 12),
        if (isPreview) ...[
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openPrint,
                icon: Icon(Icons.print_outlined, size: 15),
                label: Text('Print / Export',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kBlue,
                  side: BorderSide(color: _kBlue, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openPrint,
                icon: Icon(Icons.download_outlined, size: 15),
                label: Text('Download PDF',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kBlue,
                  side: BorderSide(color: _kBlue, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final p = _savedPatient;
                  if (p != null) context.go('/patients/${p.id}');
                },
                icon: Icon(Icons.person_outline_rounded, size: 15),
                label: Text('View Patient Profile',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  shadowColor: _kBlue.withValues(alpha: 0.4),
                ),
              ),
            ),
          ]),
        ] else ...[
          Row(children: [
            if (_step == 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kSlate(context),
                    side: BorderSide(color: _kBorder(context), width: 1.5),
                    backgroundColor: _kInput(context),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _prevStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kSlate(context),
                    side: BorderSide(color: _kBorder(context), width: 1.5),
                    backgroundColor: _kInput(context),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _saving ? null : (isLast ? _save : _nextStep),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 50,
                  decoration: BoxDecoration(
                    color: _saving ? _kBorder(context) : _kBlue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _saving
                        ? null
                        : [BoxShadow(color: _kBlue.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(isLast ? Icons.person_add_rounded : Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(isLast ? 'Register Patient' : 'Next',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        ]),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  void _openPrint() {
    final p = _savedPatient;
    if (p == null) return;
    // Build a map of ALL registration values; only pass non-empty ones
    // so the Report Generator hides any field the doctor didn't fill in.
    final raw = <String, String>{
      'firstName':          p.firstName,
      'lastName':           p.lastName ?? '',
      'date':               DateFormat('dd-MM-yyyy').format(DateTime.now()),
      'age':                _ageCtrl.text.trim().isEmpty
                              ? '' : '${_ageCtrl.text.trim()} yrs',
      'gender':             _sex ?? '',
      'phone':              p.phone ?? '',
      'email':              _emailCtrl.text.trim(),
      'address':            p.address ?? '',
      'altPhone':           _altCtrl.text.trim(),
      'idProofType':        _idProofType ?? '',
      'idProofNumber':      _idProofCtrl.text.trim(),
      'allergies':          _allergyCtrl.text.trim(),
      'medicalHistory':     _historyCtrl.text.trim(),
      'weight':             _weightCtrl.text.trim(),
      'bloodPressure':      _bpCtrl.text.trim(),
      'temperature':        _tempCtrl.text.trim(),
      'previousHistory':    _prevHistoryCtrl.text.trim(),
      'chiefComplaint':     _complaintCtrl.text.trim(),
      'examGeneral':        _examGeneralCtrl.text.trim(),
      'examNeurological':   _examNeurologicalCtrl.text.trim(),
      'clinicalDiagnosis':  _clinicalDiagnosisCtrl.text.trim(),
      'imaging':            _imagingCtrl.text.trim(),
      'otherInvestigation': _otherInvestCtrl.text.trim(),
      'diagnosis':          _diagnosisCtrl.text.trim(),
      'treatmentPlan':      _treatmentCtrl.text.trim(),
      'medications':        _prescriptionRows.map((r) =>
          '${r.medicine}${r.dose.isNotEmpty ? " [${r.dose}]" : ""}${r.route.isNotEmpty ? " (${r.route})" : ""}${r.frequency.isNotEmpty ? " - ${r.frequency}" : ""}${r.duration.isNotEmpty ? " × ${r.duration}" : ""}${r.specialInstruction.isNotEmpty ? " | ${r.specialInstruction}" : ""}').join('\n'),
      'advice':             _adviceCtrl.text.trim(),
      'crossConsultation':  _crossConsultCtrl.text.trim(),
    };
    // Exclude fields with empty values — Report Generator will skip them
    ref.read(activePatientDataProvider.notifier).state = Map.fromEntries(
      raw.entries.where((e) => e.value.isNotEmpty),
    );
    context.push('/print-config');
  }

  // ── Step 1 : Patient Info (Identity + Contact + Vitals) ────────────────────
  Widget _buildStep1() => Form(
    key: _step1Key,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_duplicates.isNotEmpty) ...[
          _DuplicateWarning(
            duplicates: _duplicates,
            onTap: (p) => context.go('/patients/${p.id}'),
          ),
          const SizedBox(height: 4),
        ],

        // ── Identity ───────────────────────────────────────────────────────
        _WizardCard(
          title: 'Full Name',
          icon: Icons.badge_outlined,
          color: _kBlue,
          child: Column(children: [
            Row(children: [
              Expanded(child: _RegField(
                label: 'First Name *',
                controller: _firstCtrl,
                textCapitalization: TextCapitalization.words,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                onEditingComplete: _checkDuplicates,
                prefixIcon: Icons.person_outline_rounded,
              )),
              const SizedBox(width: 12),
              Expanded(child: _RegField(
                label: 'Last Name',
                controller: _lastCtrl,
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.person_outline_rounded,
              )),
            ]),
          ]),
        ),
        _WizardCard(
          title: 'Demographics',
          icon: Icons.people_outline_rounded,
          color: _kBlue2,
          child: Column(children: [
            Row(children: [
              Expanded(
                child: _RegField(
                  label: 'Age',
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.cake_outlined,
                  validator: (v) {
                    if (v?.isEmpty == true) return null;
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 0 || n > 130) return 'Invalid age';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Gender',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate(context))),
                  const SizedBox(height: 6),
                  Row(children: _sexOptions.asMap().entries.map((e) {
                    final isFirst = e.key == 0;
                    final isLast  = e.key == _sexOptions.length - 1;
                    final selected = _sex == e.value;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _sex = e.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? _kBlue : _kInput(context),
                            borderRadius: BorderRadius.horizontal(
                              left: isFirst ? const Radius.circular(10) : Radius.zero,
                              right: isLast  ? const Radius.circular(10) : Radius.zero,
                            ),
                            border: Border.all(color: selected ? _kBlue : _kBorder(context)),
                          ),
                          alignment: Alignment.center,
                          child: Text(e.value,
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : _kSlate(context),
                              )),
                        ),
                      ),
                    );
                  }).toList()),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            _RegField(
              label: 'Email',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              hint: 'patient@email.com',
            ),
          ]),
        ),
        _WizardCard(
          title: 'ID Proof',
          icon: Icons.credit_card_outlined,
          color: _kGreen,
          child: Column(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ID Type',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate(context))),
              const SizedBox(height: 6),
              Row(children: _idProofOptions.asMap().entries.map((e) {
                final isFirst = e.key == 0;
                final isLast  = e.key == _idProofOptions.length - 1;
                final selected = _idProofType == e.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _idProofType = e.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? _kBlue : _kInput(context),
                        borderRadius: BorderRadius.horizontal(
                          left: isFirst ? const Radius.circular(10) : Radius.zero,
                          right: isLast  ? const Radius.circular(10) : Radius.zero,
                        ),
                        border: Border.all(color: selected ? _kBlue : _kBorder(context)),
                      ),
                      alignment: Alignment.center,
                      child: Text(e.value,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : _kSlate(context),
                          )),
                    ),
                  ),
                );
              }).toList()),
            ]),
            const SizedBox(height: 12),
            _RegField(
              label: 'ID Number',
              controller: _idProofCtrl,
              textCapitalization: TextCapitalization.characters,
              prefixIcon: Icons.pin_outlined,
              hint: _idProofType == 'PAN Card' ? 'ABCDE1234F' : 'ID number',
            ),
          ]),
        ),

        // ── Contact ────────────────────────────────────────────────────────
        _WizardCard(
          title: 'Contact',
          icon: Icons.phone_outlined,
          color: _kBlue,
          child: Column(children: [
            Row(children: [
              Expanded(child: _RegField(
                label: 'Phone Number *',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                onEditingComplete: _checkDuplicates,
                validator: (v) {
                  final val = v?.trim() ?? '';
                  if (val.isEmpty) return 'Phone number is required';
                  // Strip optional +91 or 0 prefix then check 10 digits
                  final digits = val.replaceFirst(RegExp(r'^(\+91|91|0)'), '');
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                    return 'Enter a valid 10-digit mobile number';
                  }
                  return null;
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _RegField(
                label: 'Alternate Phone',
                controller: _altCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_callback_outlined,
                validator: (v) {
                  final val = v?.trim() ?? '';
                  if (val.isEmpty) return null; // optional
                  final digits = val.replaceFirst(RegExp(r'^(\+91|91|0)'), '');
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                    return 'Enter a valid 10-digit number';
                  }
                  return null;
                },
              )),
            ]),
            const SizedBox(height: 12),
            _RegField(
              label: 'Full Address',
              controller: _addressCtrl,
              maxLines: 2,
              prefixIcon: Icons.location_on_outlined,
              hint: '123 Street Name, Area, City…',
            ),
          ]),
        ),

        // ── Vitals & Clinical Snapshot ─────────────────────────────────────
        _WizardCard(
          title: 'Patient Vitals',
          icon: Icons.monitor_heart_outlined,
          color: _kRed,
          child: Column(children: [
            Row(children: [
              Expanded(child: _RegField(
                label: 'Weight',
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.monitor_weight_outlined,
                hint: '65 kg',
              )),
              const SizedBox(width: 12),
              Expanded(child: _RegField(
                label: 'Blood Pressure',
                controller: _bpCtrl,
                keyboardType: TextInputType.text,
                prefixIcon: Icons.favorite_border_rounded,
                hint: '120/80 mmHg',
              )),
              const SizedBox(width: 12),
              Expanded(child: _RegField(
                label: 'Temperature',
                controller: _tempCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.thermostat_outlined,
                hint: '37.1 °C',
              )),
            ]),
          ]),
        ),
        _WizardCard(
          title: 'Clinical Snapshot',
          icon: Icons.note_alt_outlined,
          color: _kAmber,
          child: Column(children: [
            _RegField(
              label: 'Known Allergies',
              controller: _allergyCtrl,
              maxLines: 2,
              prefixIcon: Icons.warning_amber_outlined,
              hint: 'e.g. Penicillin, NSAIDs, Latex…',
            ),
          ]),
        ),
      ],
    ),
  );

  // ── Step 2 : Treatment ─────────────────────────────────────────────────────
  Widget _buildStep2() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [
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
      _WizardCard(
        title: 'Examination Finding',
        icon: Icons.person_search_outlined,
        color: _kBlue2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _examTab = 'general'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _examTab == 'general' ? _kBlue : _kInput(context),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                    border: Border.all(
                        color: _examTab == 'general' ? _kBlue : _kBorder(context)),
                  ),
                  alignment: Alignment.center,
                  child: Text('General',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: _examTab == 'general' ? Colors.white : _kSlate(context),
                      )),
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
                    color: _examTab == 'neurological' ? _kBlue : _kInput(context),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
                    border: Border.all(
                        color: _examTab == 'neurological' ? _kBlue : _kBorder(context)),
                  ),
                  alignment: Alignment.center,
                  child: Text('Neurological',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: _examTab == 'neurological' ? Colors.white : _kSlate(context),
                      )),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_examTab == 'general') ...[
            TextFormField(
              controller: _examGeneralCtrl,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: _kNavy(context), fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'General examination findings…',
                hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
                prefixIcon: Icon(Icons.person_search_outlined, size: 17, color: _kMuted(context)),
                suffixIcon: Tooltip(
                  message: 'Upload files',
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(Icons.upload_file_rounded, size: 20,
                            color: _examGeneralFiles.isNotEmpty ? _kGreen : _kMuted(context)),
                        onPressed: () => _pickFiles((picked) => setState(() =>
                            _examGeneralFiles.addAll(picked))),
                      ),
                      if (_examGeneralFiles.isNotEmpty)
                        Positioned(
                          right: 6, top: 6,
                          child: Container(
                            width: 15, height: 15,
                            decoration: BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text('${_examGeneralFiles.length}',
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                ),
                filled: true, fillColor: _kInput(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBorder(context))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBorder(context))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kP1, width: 1.5)),
              ),
            ),
            if (_examGeneralFiles.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: List.generate(_examGeneralFiles.length, (idx) =>
                  _fileChip(_examGeneralFiles[idx].name, () => setState(() =>
                      _examGeneralFiles.removeAt(idx)))),
              ),
            ],
          ] else ...[
            TextFormField(
              controller: _examNeurologicalCtrl,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: _kNavy(context), fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Neurological examination findings…',
                hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
                prefixIcon: Icon(Icons.psychology_outlined, size: 17, color: _kMuted(context)),
                suffixIcon: Tooltip(
                  message: 'Upload files',
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(Icons.upload_file_rounded, size: 20,
                            color: _examNeurologicalFiles.isNotEmpty ? _kGreen : _kMuted(context)),
                        onPressed: () => _pickFiles((picked) => setState(() =>
                            _examNeurologicalFiles.addAll(picked))),
                      ),
                      if (_examNeurologicalFiles.isNotEmpty)
                        Positioned(
                          right: 6, top: 6,
                          child: Container(
                            width: 15, height: 15,
                            decoration: BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text('${_examNeurologicalFiles.length}',
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                ),
                filled: true, fillColor: _kInput(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBorder(context))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kBorder(context))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kP1, width: 1.5)),
              ),
            ),
            if (_examNeurologicalFiles.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: List.generate(_examNeurologicalFiles.length, (idx) =>
                  _fileChip(_examNeurologicalFiles[idx].name, () => setState(() =>
                      _examNeurologicalFiles.removeAt(idx)))),
              ),
            ],
          ],
        ]),
      ),
      _WizardCard(
        title: 'Previous Investigations',
        icon: Icons.science_outlined,
        color: _kGreen,
        child: Column(children: [
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
      _WizardCard(
        title: 'Impression',
        icon: Icons.lightbulb_outline_rounded,
        color: const Color(0xFFF59E0B),
        child: _fieldWithUpload(
          label: 'Clinical Impression',
          controller: _diagnosisCtrl,
          files: _impressionFiles,
          onFilesChange: (f) => _impressionFiles..clear()..addAll(f),
          prefixIcon: Icons.rule_outlined,
          hint: 'Clinical impression / assessment…',
        ),
      ),
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
            prefixIcon: Icons.assignment_outlined,
            hint: 'Recommended plan…',
          ),
          const SizedBox(height: 12),
          _buildMedicationTable(),
          const SizedBox(height: 12),
          _RegField(
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
            prefixIcon: Icons.people_outline_rounded,
            hint: 'Referred to / consulted with…',
          ),
        ]),
      ),

      // ── Doctor's Notes (private — not printed) ─────────────────────────
      _WizardCard(
        title: "Doctor's Notes",
        icon: Icons.lock_outline_rounded,
        color: const Color(0xFF64748B),
        badge: 'Private · Not printed',
        child: _RegField(
          label: 'Notes (admin reference only)',
          controller: _treatNotesCtrl,
          maxLines: 4,
          prefixIcon: Icons.notes_rounded,
          hint: 'Private notes — will not appear on the patient sheet…',
        ),
      ),
    ],
  );

  // ── Step 3 : Preview & Print ───────────────────────────────────────────────
  Widget _buildStep3() {
    final p = _savedPatient;
    final fullName = '${_firstCtrl.text.trim()} ${_lastCtrl.text.trim()}'.trim();
    String fv(String s) => s.isEmpty ? '—' : s;

    // Stacked label-above-value field (compact, used in 2-col inner grids)
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

    // Horizontal label:value row (for sections with files)
    Widget eRow(String label, String value,
        List<({String name, Uint8List bytes})> files) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 124,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, color: _kMuted(context), fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (value.isNotEmpty)
              Text(value,
                  style: TextStyle(
                      fontSize: 12, color: _kNavy(context), fontWeight: FontWeight.w600))
            else if (files.isEmpty)
              Text('—',
                  style: TextStyle(
                      fontSize: 12, color: _kMuted(context), fontWeight: FontWeight.w500)),
            if (files.isNotEmpty) ...[
              if (value.isNotEmpty) const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4,
                  children: files.map((f) => _fileViewChip(f)).toList()),
            ],
          ]),
        ),
      ]),
    );

    // Simple horizontal label:value (no files)
    Widget pRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 124,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, color: _kMuted(context), fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12, color: _kNavy(context), fontWeight: FontWeight.w600)),
        ),
      ]),
    );

    // Card shell
    Widget sCard(String title, IconData icon, Color color, Widget body) =>
        Container(
          decoration: BoxDecoration(
            color: _kCard(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder(context)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 15),
                ),
                const SizedBox(width: 9),
                Text(title,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy(context))),
              ]),
            ),
            Divider(height: 1, color: _kBorder(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: body,
            ),
          ]),
        );

    // Two equal-height side-by-side cards
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

    // Thin vertical divider for inner 2-col
    final vDiv = SizedBox(
      width: 28,
      child: Center(child: VerticalDivider(thickness: 1, color: _kBorder(context), width: 1)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        // ── Success banner ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _kGreen, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Patient Registered Successfully!',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _kNavy(context), fontSize: 15)),
                if (p != null)
                  RichText(text: TextSpan(children: [
                    TextSpan(text: 'UHID: ',
                        style: TextStyle(color: _kMuted(context), fontSize: 11)),
                    TextSpan(text: p.prn,
                        style: TextStyle(
                            color: _kGreen, fontWeight: FontWeight.w700, fontSize: 11)),
                    TextSpan(text: '  ·  ',
                        style: TextStyle(color: _kMuted(context), fontSize: 11)),
                    TextSpan(text: fullName,
                        style: TextStyle(color: _kNavy(context), fontSize: 11)),
                  ])),
              ]),
            ),
            Stack(alignment: Alignment.bottomRight, children: [
              Icon(Icons.assignment_outlined, size: 44,
                  color: _kGreen.withValues(alpha: 0.3)),
              Container(
                width: 17, height: 17,
                decoration: BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 11),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Patient Information — full width, inner 2-column ──────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: sCard('Patient Information', Icons.person_outline_rounded, _kBlue,
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  iField('Full Name', fullName.isEmpty ? '—' : fullName),
                  iField('Age',
                      _ageCtrl.text.trim().isEmpty ? '—' : '${_ageCtrl.text.trim()} yrs'),
                  iField('Phone', fv(_phoneCtrl.text.trim())),
                  iField('Email', fv(_emailCtrl.text.trim())),
                  iField('ID Proof Type', fv(_idProofType ?? '')),
                ])),
                vDiv,
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  iField('UHID', p?.prn ?? '—'),
                  iField('Gender', fv(_sex ?? '')),
                  iField('Alt Phone', fv(_altCtrl.text.trim())),
                  iField('Address', fv(_addressCtrl.text.trim())),
                  iField('ID Number', fv(_idProofCtrl.text.trim())),
                ])),
              ]),
            ),
          ),
        ),

        // ── Vitals | Clinical Snapshot ────────────────────────────────────
        twoCol(
          sCard('Vitals', Icons.monitor_heart_outlined, _kRed,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              pRow('Weight', fv(_weightCtrl.text.trim())),
              pRow('Blood Pressure', fv(_bpCtrl.text.trim())),
              pRow('Temperature', fv(_tempCtrl.text.trim())),
            ]),
          ),
          sCard('Clinical Snapshot', Icons.health_and_safety_outlined, _kAmber,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              pRow('Known Allergies', fv(_allergyCtrl.text.trim())),
              pRow('Medical History', fv(_historyCtrl.text.trim())),
            ]),
          ),
        ),

        // ── History & Complaint | Examination Finding ─────────────────────
        twoCol(
          sCard('History & Complaint', Icons.history_edu_outlined,
              _kBlue,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('Previous History', _prevHistoryCtrl.text.trim(), _prevHistoryFiles),
              eRow('Chief Complaint', _complaintCtrl.text.trim(), _chiefComplaintFiles),
            ]),
          ),
          sCard('Examination Finding', Icons.search_outlined,
              _kBlue2,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('General', _examGeneralCtrl.text.trim(), _examGeneralFiles),
              eRow('Neurological', _examNeurologicalCtrl.text.trim(),
                  _examNeurologicalFiles),
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
              eRow('Other Investigation', _otherInvestCtrl.text.trim(),
                  _otherInvestFiles),
            ]),
          ),
        ),

        // ── Impression ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: sCard('Impression', Icons.lightbulb_outline_rounded,
              const Color(0xFFF59E0B),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('Clinical Impression', _diagnosisCtrl.text.trim(), _impressionFiles),
            ]),
          ),
        ),

        // ── Clinical Plan ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: sCard('Clinical Plan', Icons.assignment_outlined, _kBlue,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              eRow('Plan', _treatmentCtrl.text.trim(), _planFiles),
              if (_prescriptionRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Prescriptions',
                        style: TextStyle(fontSize: 11, color: _kMuted(context),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...List.generate(_prescriptionRows.length, (idx) {
                      final r = _prescriptionRows[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                  color: _kBlue.withValues(alpha: 0.12),
                                  shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text('${idx + 1}',
                                  style: TextStyle(fontSize: 8,
                                      fontWeight: FontWeight.w800, color: _kBlue)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                              '${r.medicine}${r.dose.isNotEmpty ? "  ${r.dose}" : ""}  ·  ${r.route}  ·  ${r.frequency}${r.duration.isNotEmpty ? "  ×  ${r.duration}" : ""}',
                              style: TextStyle(fontSize: 11, color: _kNavy(context),
                                  fontWeight: FontWeight.w600),
                            )),
                          ]),
                          if (r.specialInstruction.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(r.specialInstruction,
                                  style: TextStyle(fontSize: 10,
                                      color: Colors.amber.shade700,
                                      fontStyle: FontStyle.italic)),
                            ),
                          ],
                        ]),
                      );
                    }),
                  ]),
                ),
              ] else
                eRow('Treatment', '', _treatmentMedFiles),
              pRow('Advice', fv(_adviceCtrl.text.trim())),
              eRow('Cross Consultation', fv(_crossConsultCtrl.text.trim()), _crossConsultFiles),
            ]),
          ),
        ),

        // ── Doctor's Notes (private — not on patient sheet) ───────────────
        if (_treatNotesCtrl.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: sCard("Doctor's Notes", Icons.lock_outline_rounded,
                _kMuted(context),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 11, color: _kMuted(context)),
                  const SizedBox(width: 4),
                  Text('Private · Not on patient sheet',
                      style: TextStyle(fontSize: 10, color: _kMuted(context),
                          fontStyle: FontStyle.italic)),
                ]),
                const SizedBox(height: 6),
                Text(_treatNotesCtrl.text.trim(),
                    style: TextStyle(fontSize: 13, color: _kNavy(context),
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
      ],
    );
  }

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  color: _kCard(context),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(bottom: BorderSide(color: _kBorder(context))),
                ),
                child: Row(children: [
                  Icon(isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                      color: _kBlue, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(f.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: _kNavy(context), fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18),
                    color: _kMuted(context),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ]),
              ),
              Flexible(
                child: isImage
                    ? InteractiveViewer(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.memory(f.bytes),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.insert_drive_file_rounded, size: 72, color: _kMuted(context)),
                          const SizedBox(height: 16),
                          Text(f.name,
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700, color: _kNavy(context)),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text('${(f.bytes.length / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(fontSize: 12, color: _kMuted(context))),
                          const SizedBox(height: 16),
                          Text(
                            'Preview not available for this file type.\nThe file has been uploaded successfully.',
                            style: TextStyle(fontSize: 12, color: _kMuted(context)),
                            textAlign: TextAlign.center,
                          ),
                        ]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ── Prescription row model ────────────────────────────────────────────────────

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
}

// ── Add Medicine bottom sheet ─────────────────────────────────────────────────

const _kRegRoutes = ['Oral', 'IV', 'IM', 'SC', 'Topical', 'SL', 'Inhalation', 'Rectal', 'Nasal'];
const _kRegFreqs  = ['OD', 'BD', 'TDS', 'QID', 'SOS', 'PRN', 'HS', 'Weekly', 'Fortnightly', 'Monthly'];

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

class _AddMedicineSheetState extends State<_AddMedicineSheet> {
  final _nameCtrl    = TextEditingController();
  final _doseCtrl    = TextEditingController();
  final _routeCtrl   = TextEditingController();
  final _freqCtrl    = TextEditingController();
  final _durCtrl     = TextEditingController();
  final _specialCtrl = TextEditingController();

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

  InputDecoration _dec({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
    filled: true, fillColor: _kInput(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kBorder(context))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kBorder(context))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kBlue, width: 1.5)),
  );

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
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: _kBorder(context), borderRadius: BorderRadius.circular(2)),
          ),
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
                // Medicine name
                Text('Medicine Name *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _kSlate(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  style: TextStyle(fontSize: 14, color: _kNavy(context),
                      fontWeight: FontWeight.w500),
                  decoration: _dec(hint: 'Type medicine name…').copyWith(
                    prefixIcon: Icon(Icons.medication_outlined,
                        size: 17, color: _kMuted(context)),
                    suffixIcon: _nameCtrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _nameCtrl.clear();
                              setState(() { _suggestions = []; _showSugg = false; }); },
                            child: Icon(Icons.close_rounded,
                                size: 16, color: _kMuted(context)))
                        : null,
                  ),
                ),
                if (_showSugg && _suggestions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: _kInput(context),
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
                              Icon(s.isHistory
                                  ? Icons.history_rounded
                                  : Icons.medication_rounded,
                                size: 15,
                                color: s.isHistory ? _kGreen : _kBlue),
                              const SizedBox(width: 10),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name,
                                      style: TextStyle(fontSize: 13,
                                          fontWeight: FontWeight.w600, color: _kNavy(context))),
                                  if (s.subtitle.isNotEmpty)
                                    Text(s.subtitle,
                                        style: TextStyle(fontSize: 11,
                                            color: s.isHistory ? _kGreen : _kMuted(context))),
                                ],
                              )),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dose', style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: _kSlate(context))),
                      const SizedBox(height: 6),
                      TextField(controller: _doseCtrl,
                          style: TextStyle(fontSize: 14, color: _kNavy(context),
                              fontWeight: FontWeight.w500),
                          decoration: _dec(hint: '500mg')),
                    ])),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Route', style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: _kSlate(context))),
                      const SizedBox(height: 6),
                      TextField(controller: _routeCtrl,
                          style: TextStyle(fontSize: 14, color: _kNavy(context),
                              fontWeight: FontWeight.w500),
                          decoration: _dec(hint: 'Oral / IV / IM…')),
                    ])),
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Frequency', style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: _kSlate(context))),
                      const SizedBox(height: 6),
                      TextField(controller: _freqCtrl,
                          style: TextStyle(fontSize: 14, color: _kNavy(context),
                              fontWeight: FontWeight.w500),
                          decoration: _dec(hint: 'e.g. 1-0-1')),
                    ])),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duration', style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: _kSlate(context))),
                      const SizedBox(height: 6),
                      TextField(controller: _durCtrl,
                          style: TextStyle(fontSize: 14, color: _kNavy(context),
                              fontWeight: FontWeight.w500),
                          decoration: _dec(hint: '5 days')),
                    ])),
                ]),
                const SizedBox(height: 12),
                // ── Special Instruction ────────────────────────────────────
                Text('Special Instruction',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _kSlate(context))),
                const SizedBox(height: 6),
                TextField(
                  controller: _specialCtrl,
                  style: TextStyle(fontSize: 14, color: _kNavy(context),
                      fontWeight: FontWeight.w500),
                  decoration: _dec(hint: 'e.g. Take after food, avoid sunlight…').copyWith(
                    prefixIcon: Icon(Icons.info_outline_rounded,
                        size: 17, color: _kMuted(context)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity, height: 50,
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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy(context)))),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 10, color: const Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(badge!,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),
        Divider(height: 1, color: _kBorder(context)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ]),
    ),
  );
}

// ── Duplicate warning ─────────────────────────────────────────────────────────
class _DuplicateWarning extends StatelessWidget {
  final List<PatientEntity> duplicates;
  final void Function(PatientEntity) onTap;
  const _DuplicateWarning({required this.duplicates, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kAmber.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.warning_amber_rounded, color: _kAmber, size: 18),
        SizedBox(width: 8),
        Text('Similar patients found',
            style: TextStyle(fontWeight: FontWeight.w700, color: _kAmber, fontSize: 13)),
      ]),
      const SizedBox(height: 10),
      ...duplicates.map((p) => GestureDetector(
        onTap: () => onTap(p),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _kCard(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(p.initials,
                  style: TextStyle(
                      color: _kAmber, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13, color: _kNavy(context))),
                Text('${p.ageSex}  ·  UHID: ${p.prn}',
                    style: TextStyle(fontSize: 11, color: _kMuted(context))),
              ]),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: _kMuted(context)),
          ]),
        ),
      )),
      const SizedBox(height: 4),
      Text('You can still continue registering a new patient.',
          style: TextStyle(fontSize: 11, color: _kMuted(context))),
    ]),
  );
}

// ── Generic text field ────────────────────────────────────────────────────────
class _RegField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onEditingComplete;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;
  final String? hint;

  const _RegField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
    this.onEditingComplete,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate(context))),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onEditingComplete: onEditingComplete,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        style: TextStyle(
            fontSize: 14, color: _kNavy(context), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _kMuted(context), fontSize: 13),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 17, color: _kMuted(context))
              : null,
          filled: true,
          fillColor: _kInput(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kBorder(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kBorder(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kP1, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kRed),
          ),
        ),
      ),
    ],
  );
}

// ── Reusable dropdown field ───────────────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String hint;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate(context))),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _kInput(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder(context)),
        ),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          dropdownColor: _kCard(context),
          hint: Text(hint,
              style: TextStyle(fontSize: 14, color: _kMuted(context))),
          icon: Icon(Icons.keyboard_arrow_down, color: _kMuted(context)),
          style: TextStyle(
              fontSize: 14, color: _kNavy(context), fontWeight: FontWeight.w500),
          items: options
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

