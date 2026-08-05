// ─────────────────────────────────────────────────────────────────────────────
// visit_form_screen.dart  –  Single-scroll visit form
// Personal details auto-populated · Treatment Info · Vitals · Upload Reports
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../../../photos/domain/entities/photo_entity.dart';
import '../../../photos/presentation/providers/photo_provider.dart';
import '../../domain/entities/visit_entity.dart';
import '../providers/visit_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kP1    = Color(0xFF4B55CC);
const _kP2    = Color(0xFF3D47B4);
const _kRed   = Color(0xFF8A4430);
const _kGreen = Color(0xFF2D7A4E);
const _kBg    = Color(0xFFF8F6F2);
const _kNavy  = Color(0xFF302D28);
const _kSlate = Color(0xFF6E6A63);
const _kMuted = Color(0xFF979088);
const _kBorder= Color(0xFFE0DDD7);

const _kVisitTypeLabels = ['OPD', 'Emergency', 'Follow-up'];

// ── Report slot ───────────────────────────────────────────────────────────────
class _ReportSlot {
  final String label;
  final IconData icon;
  final Color color;
  final PhotoCategory category;
  ({String name, Uint8List bytes})? file;

  _ReportSlot(this.label, this.icon, this.color, this.category);
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class VisitFormScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String visitId;
  const VisitFormScreen({
    super.key,
    required this.patientId,
    required this.visitId,
  });

  @override
  ConsumerState<VisitFormScreen> createState() => _VisitFormState();
}

class _VisitFormState extends ConsumerState<VisitFormScreen> {
  bool _loaded          = false;
  bool _patientApplied  = false;   // guard for patient-data fallback
  bool _saving          = false;
  bool _uploadingFiles  = false;

  // Visit meta
  DateTime  _visitDate = DateTime.now();
  VisitType _visitType = VisitType.opd;

  // Treatment Information
  final _complaintCtrl   = TextEditingController();
  final _diagnosisCtrl   = TextEditingController();
  final _treatmentCtrl   = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _doctorCtrl      = TextEditingController();
  final _notesCtrl       = TextEditingController();

  // Clinical Snapshot
  final _bpCtrl     = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _tempCtrl   = TextEditingController();

  late final List<_ReportSlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = [
      _ReportSlot('Prescription',  Icons.receipt_long_rounded,  const Color(0xFF4B55CC), PhotoCategory.patientReport),
      _ReportSlot('Lab Report',    Icons.science_rounded,       const Color(0xFF3D6E7A), PhotoCategory.patientReport),
      _ReportSlot('X-Ray',         Icons.image_search_rounded,  const Color(0xFF2D7A4E), PhotoCategory.radiology),
      _ReportSlot('MRI / CT Scan', Icons.biotech_rounded,       const Color(0xFF8A4430), PhotoCategory.radiology),
    ];
  }

  @override
  void dispose() {
    for (final c in [
      _complaintCtrl, _diagnosisCtrl, _treatmentCtrl,
      _medicationsCtrl, _doctorCtrl, _notesCtrl,
      _bpCtrl, _weightCtrl, _tempCtrl,
    ]) c.dispose();
    super.dispose();
  }

  void _populateFrom(VisitEntity v) {
    if (_loaded) return;
    _loaded = true;
    _visitDate = v.visitDate;
    _visitType = v.visitType;
    // Only overwrite a controller if the visit actually has non-empty data
    // so patient-registration fallbacks already applied are preserved.
    void set(TextEditingController c, String? val) {
      if (val?.isNotEmpty == true) c.text = val!;
    }
    set(_complaintCtrl,   v.complaints);
    set(_diagnosisCtrl,   v.clinicalImpression);
    set(_treatmentCtrl,   v.plan);
    set(_notesCtrl,       v.notes);
    if (v.examination?.isNotEmpty == true) {
      try {
        final m = jsonDecode(v.examination!) as Map<String, dynamic>;
        set(_bpCtrl,          m['bp']            as String?);
        set(_weightCtrl,      m['weight']         as String?);
        set(_tempCtrl,        m['temperature']    as String?);
        set(_medicationsCtrl, m['medications']    as String?);
        set(_doctorCtrl,      m['doctorAssigned'] as String?);
      } catch (_) {}
    }
    setState(() {});
  }

  /// Called once after patient loads: fills empty treatment fields from the
  /// patient's registration data so the form is pre-populated for new visits.
  void _applyPatientFallbacks(PatientEntity patient) {
    if (_patientApplied) return;
    _patientApplied = true;

    Map<String, String> notes = {};
    if (patient.notes?.isNotEmpty == true) {
      try {
        notes = (jsonDecode(patient.notes!) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    void fill(TextEditingController ctrl, String key) {
      if (ctrl.text.isEmpty && notes[key]?.isNotEmpty == true) {
        ctrl.text = notes[key]!;
      }
    }

    fill(_complaintCtrl,   'chiefComplaint');
    fill(_diagnosisCtrl,   'diagnosis');
    fill(_treatmentCtrl,   'treatmentPlan');
    fill(_medicationsCtrl, 'medications');
    fill(_notesCtrl,       'treatmentNotes');
    fill(_bpCtrl,          'bloodPressure');
    fill(_weightCtrl,      'weight');
    fill(_tempCtrl,        'temperature');

    setState(() {});
  }

  String? _buildExamination() {
    final m = <String, String>{};
    void add(String k, TextEditingController c) {
      if (c.text.trim().isNotEmpty) m[k] = c.text.trim();
    }
    add('bp',            _bpCtrl);
    add('weight',        _weightCtrl);
    add('temperature',   _tempCtrl);
    add('medications',   _medicationsCtrl);
    add('doctorAssigned', _doctorCtrl);
    return m.isEmpty ? null : jsonEncode(m);
  }

  Future<void> _save({bool complete = true}) async {
    if (_saving || _uploadingFiles) return;
    _saving = true; // set synchronously before any await so rapid taps are blocked
    setState(() {});

    final current = ref.read(visitEditProvider('${widget.patientId}/${widget.visitId}'));
    if (current == null) {
      setState(() => _saving = false);
      return;
    }

    final updated = current.copyWith(
      visitDate:          _visitDate,
      visitType:          _visitType,
      complaints:         _complaintCtrl.text.trim().isNotEmpty ? _complaintCtrl.text.trim() : null,
      clinicalImpression: _diagnosisCtrl.text.trim().isNotEmpty ? _diagnosisCtrl.text.trim() : null,
      plan:               _treatmentCtrl.text.trim().isNotEmpty ? _treatmentCtrl.text.trim() : null,
      notes:              _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      examination:        _buildExamination(),
      status:             complete ? 'completed' : 'draft',
    );

    ref.read(visitEditProvider('${widget.patientId}/${widget.visitId}').notifier).update(updated);
    final ok = await ref.read(visitEditProvider('${widget.patientId}/${widget.visitId}').notifier).save();

    final filledSlots = _slots.where((s) => s.file != null).toList();
    if (ok && filledSlots.isNotEmpty) {
      setState(() { _saving = false; _uploadingFiles = true; });
      final notifier = ref.read(photoProvider(widget.patientId).notifier);
      for (final slot in filledSlots) {
        await notifier.upload(
          bytes:    slot.file!.bytes,
          filename: slot.file!.name,
          category: slot.category,
          visitId:  widget.visitId,
          caption:  slot.label,
        );
      }
      if (mounted) setState(() => _uploadingFiles = false);
    } else {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Visit saved successfully',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to save visit. Please try again.'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientAsync  = ref.watch(patientByIdProvider(widget.patientId));
    final visit         = ref.watch(visitEditProvider('${widget.patientId}/${widget.visitId}'));
    final photoState    = ref.watch(photoProvider(widget.patientId));
    final existingPhotos = photoState.photos
        .where((p) => p.visitId == widget.visitId || p.visitId == null)
        .toList();

    if (visit != null && !_loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _populateFrom(visit));
    }

    // Once both patient & visit are ready, fill any still-empty fields from
    // the patient's registration data (treatment info, vitals).
    patientAsync.whenData((patient) {
      if (patient != null && !_patientApplied) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _applyPatientFallbacks(patient));
      }
    });

    final busy = _saving || _uploadingFiles;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _GradientHeader(
          title: 'New Visit',
          subtitle: busy
              ? (_uploadingFiles ? 'Uploading files…' : 'Saving…')
              : null,
          onBack: () => context.pop(),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [

              // ── Patient card (auto-populated, read-only) ──────────
              const SizedBox(height: 16),
              patientAsync.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator(color: _kP1)),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (p) => p == null
                    ? const SizedBox.shrink()
                    : _PatientSummaryCard(patient: p),
              ),

              // ── Visit Details ─────────────────────────────────────
              _SectionCard(
                title: 'Visit Details',
                icon: Icons.calendar_today_outlined,
                color: _kP2,
                child: Column(children: [
                  _DateField(
                    label: 'Visit Date',
                    value: _visitDate,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _visitDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        builder: (c, w) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(primary: _kP1),
                          ),
                          child: w!,
                        ),
                      );
                      if (d != null) setState(() => _visitDate = d);
                    },
                  ),
                  const SizedBox(height: 12),
                  _DropdownField(
                    label: 'Visit Type',
                    value: _visitType.label,
                    options: _kVisitTypeLabels,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _visitType = switch (v) {
                        'Emergency' => VisitType.emergency,
                        'Follow-up' => VisitType.followUp,
                        _           => VisitType.opd,
                      });
                    },
                  ),
                ]),
              ),

              // ── Treatment Information ─────────────────────────────
              _SectionCard(
                title: 'Treatment Information',
                icon: Icons.medical_services_outlined,
                color: _kGreen,
                child: Column(children: [
                  _VField(
                    label: 'Chief Complaint',
                    controller: _complaintCtrl,
                    maxLines: 2,
                    prefixIcon: Icons.report_problem_outlined,
                    hint: 'Primary reason for visit…',
                  ),
                  const SizedBox(height: 12),
                  _VField(
                    label: 'Diagnosis',
                    controller: _diagnosisCtrl,
                    maxLines: 2,
                    prefixIcon: Icons.local_hospital_outlined,
                    hint: 'Clinical diagnosis…',
                  ),
                  const SizedBox(height: 12),
                  _VField(
                    label: 'Treatment Plan',
                    controller: _treatmentCtrl,
                    maxLines: 2,
                    prefixIcon: Icons.assignment_outlined,
                    hint: 'Recommended treatment…',
                  ),
                  const SizedBox(height: 12),
                  _VField(
                    label: 'Medications',
                    controller: _medicationsCtrl,
                    maxLines: 2,
                    prefixIcon: Icons.medication_outlined,
                    hint: 'e.g. Paracetamol 650mg · Cetirizine 10mg…',
                  ),
                  const SizedBox(height: 12),
                  _VField(
                    label: 'Doctor Assigned',
                    controller: _doctorCtrl,
                    prefixIcon: Icons.person_outlined,
                    hint: 'e.g. Dr. Harshal Chaudhari',
                  ),
                  const SizedBox(height: 12),
                  _VField(
                    label: 'Notes',
                    controller: _notesCtrl,
                    maxLines: 3,
                    prefixIcon: Icons.notes_rounded,
                    hint: 'Additional clinical notes…',
                  ),
                ]),
              ),

              // ── Clinical Snapshot (vitals) ────────────────────────
              _SectionCard(
                title: 'Clinical Snapshot',
                icon: Icons.monitor_heart_outlined,
                color: _kRed,
                badge: 'Optional',
                child: Row(children: [
                  Expanded(child: _VField(
                    label: 'Blood Pressure',
                    controller: _bpCtrl,
                    prefixIcon: Icons.favorite_border_rounded,
                    hint: '120/80',
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _VField(
                    label: 'Weight',
                    controller: _weightCtrl,
                    prefixIcon: Icons.monitor_weight_outlined,
                    hint: '65 kg',
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _VField(
                    label: 'Temperature',
                    controller: _tempCtrl,
                    prefixIcon: Icons.thermostat_outlined,
                    hint: '37.1 °C',
                  )),
                ]),
              ),

              // ── Upload Reports ────────────────────────────────────
              _SectionCard(
                title: 'Upload Reports',
                icon: Icons.folder_open_rounded,
                color: const Color(0xFF3D6E7A),
                badge: 'Optional',
                child: _UploadSection(
                  slots: _slots,
                  uploading: _uploadingFiles,
                  existingPhotos: existingPhotos,
                  onFileSelected: (i, name, bytes) =>
                      setState(() => _slots[i].file = (name: name, bytes: bytes)),
                  onDeletePhoto: (photo) =>
                      ref.read(photoProvider(widget.patientId).notifier).delete(photo),
                ),
              ),

              // ── Save buttons ──────────────────────────────────────
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _save(complete: false),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save Draft'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSlate,
                      side: const BorderSide(color: _kBorder, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _save(complete: true),
                    icon: busy
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text(busy ? 'Saving…' : 'Save Visit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kP1,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient header (same style as patient registration)
// ─────────────────────────────────────────────────────────────────────────────
class _GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  const _GradientHeader({
    required this.title,
    this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B55CC), Color(0xFF3D47B4)],
        ),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3)),
            if (subtitle != null)
              Text(subtitle!,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: const Text('Visit',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient summary card (auto-populated, read-only)
// ─────────────────────────────────────────────────────────────────────────────
class _PatientSummaryCard extends StatelessWidget {
  final PatientEntity patient;
  const _PatientSummaryCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    Map<String, String> meta = {};
    if (patient.notes?.isNotEmpty == true) {
      try {
        meta = (jsonDecode(patient.notes!) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }
    final blood    = meta['bloodGroup'];
    final dob      = patient.dateOfBirth != null
        ? DateFormat('dd MMM yyyy').format(patient.dateOfBirth!) : null;
    final email    = meta['email'];
    final occ      = meta['occupation'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: [
        // Header bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kP1.withValues(alpha: 0.06), _kP2.withValues(alpha: 0.06)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kP1, _kP2]),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.person_pin_outlined,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text('Patient Details',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kNavy)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
              ),
              child: const Text('Auto-filled',
                  style: TextStyle(
                      fontSize: 10,
                      color: _kGreen,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        // Fields grid
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Expanded(child: _ReadField('Full Name',
                  patient.fullName, Icons.badge_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _ReadField('Age / Sex',
                  patient.ageSex.isEmpty ? '—' : patient.ageSex,
                  Icons.person_outline)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _ReadField('Phone',
                  patient.phone ?? '—', Icons.phone_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _ReadField('UHID',
                  patient.prn, Icons.badge_outlined)),
            ]),
            if (dob != null || blood != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (dob != null)
                  Expanded(child: _ReadField(
                      'Date of Birth', dob, Icons.cake_outlined)),
                if (dob != null && blood != null) const SizedBox(width: 12),
                if (blood != null)
                  Expanded(child: _ReadField(
                      'Blood Group', blood, Icons.bloodtype_outlined)),
              ]),
            ],
            if (email != null || occ != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (email != null)
                  Expanded(child: _ReadField(
                      'Email', email, Icons.mail_outline_rounded)),
                if (email != null && occ != null) const SizedBox(width: 12),
                if (occ != null)
                  Expanded(child: _ReadField(
                      'Occupation', occ, Icons.work_outline_rounded)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _ReadField extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _ReadField(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _kBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kBorder),
    ),
    child: Row(children: [
      Icon(icon, size: 14, color: _kMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: _kMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, color: _kNavy, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? badge;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    this.badge,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          border: Border(bottom: BorderSide(color: _kBorder)),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      fontSize: 10,
                      color: _kMuted,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      ),
      // Content
      Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Text field
// ─────────────────────────────────────────────────────────────────────────────
class _VField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _VField({
    required this.label,
    required this.controller,
    this.prefixIcon,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kSlate)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 17, color: _kMuted)
              : null,
          filled: true,
          fillColor: _kBg,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kP1, width: 1.5),
          ),
        ),
        style: const TextStyle(fontSize: 14, color: _kNavy),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Date field
// ─────────────────────────────────────────────────────────────────────────────
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
              value != null
                  ? DateFormat('dd MMM yyyy').format(value!)
                  : 'Select date',
              style: TextStyle(
                  fontSize: 14,
                  color: value != null ? _kNavy : _kMuted,
                  fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down_rounded,
                color: _kMuted, size: 20),
          ]),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown field
// ─────────────────────────────────────────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String? hint;
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            hint: Text(hint ?? 'Select',
                style: const TextStyle(color: _kMuted, fontSize: 13)),
            icon: const Icon(Icons.arrow_drop_down_rounded,
                color: _kMuted, size: 20),
            style: const TextStyle(fontSize: 14, color: _kNavy),
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload section — new uploads + existing saved photos
// ─────────────────────────────────────────────────────────────────────────────
class _UploadSection extends StatelessWidget {
  final List<_ReportSlot> slots;
  final bool uploading;
  final List<PhotoEntity> existingPhotos;
  final void Function(int index, String name, Uint8List bytes) onFileSelected;
  final void Function(PhotoEntity photo) onDeletePhoto;

  const _UploadSection({
    required this.slots,
    required this.uploading,
    required this.existingPhotos,
    required this.onFileSelected,
    required this.onDeletePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── New upload tiles ──────────────────────────────────────
        if (uploading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(children: [
                CircularProgressIndicator(color: _kP1),
                SizedBox(height: 10),
                Text('Uploading files…',
                    style: TextStyle(color: _kMuted, fontSize: 13)),
              ]),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
              slots.length,
              (i) => _UploadTile(
                slot: slots[i],
                onTap: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                    withData: true,
                  );
                  if (result?.files.firstOrNull?.bytes != null) {
                    final f = result!.files.first;
                    onFileSelected(i, f.name, f.bytes!);
                  }
                },
              ),
            ),
          ),

        // ── Previously saved documents ────────────────────────────
        if (existingPhotos.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Saved Documents',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kSlate,
                  letterSpacing: 0.2)),
          const SizedBox(height: 8),
          ...existingPhotos.map((p) => _SavedDocTile(
                photo: p,
                onDelete: () => onDeletePhoto(p),
              )),
        ],
      ],
    );
  }
}

class _UploadTile extends StatelessWidget {
  final _ReportSlot slot;
  final VoidCallback onTap;
  const _UploadTile({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasFile = slot.file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 60) / 2,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasFile
              ? slot.color.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? slot.color.withValues(alpha: 0.4) : _kBorder,
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: slot.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(slot.icon, size: 16, color: slot.color),
              ),
              const Spacer(),
              if (hasFile)
                Icon(Icons.check_circle_rounded,
                    size: 16, color: _kGreen)
              else
                Icon(Icons.add_circle_outline,
                    size: 16, color: _kMuted),
            ]),
            const SizedBox(height: 8),
            Text(slot.label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: hasFile ? slot.color : _kSlate)),
            const SizedBox(height: 2),
            Text(
              hasFile ? slot.file!.name : 'Tap to upload',
              style: TextStyle(
                  fontSize: 10,
                  color: hasFile ? slot.color.withValues(alpha: 0.7) : _kMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved document tile — shows an uploaded photo with View & Download actions
// ─────────────────────────────────────────────────────────────────────────────
class _SavedDocTile extends StatelessWidget {
  final PhotoEntity photo;
  final VoidCallback onDelete;
  const _SavedDocTile({required this.photo, required this.onDelete});

  static const _kDocBlue  = Color(0xFF4B55CC);
  static const _kDocGreen = Color(0xFF2D7A4E);

  IconData get _icon => switch (photo.category) {
    PhotoCategory.radiology    => Icons.image_search_rounded,
    PhotoCategory.patientReport => Icons.receipt_long_rounded,
    _                          => Icons.insert_drive_file_outlined,
  };

  Future<void> _open(BuildContext context) async {
    final url = photo.url;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL not available')),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open this file')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = photo.caption ?? photo.storagePath.split('/').last;
    final dateStr = DateFormat('dd MMM yyyy').format(photo.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kDocBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(_icon, size: 18, color: _kDocBlue),
        ),
        const SizedBox(width: 10),

        // Name + date
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kNavy),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${photo.category.label} · $dateStr',
                style: const TextStyle(fontSize: 10, color: _kMuted)),
          ]),
        ),

        // View button
        _DocActionBtn(
          label: 'View',
          icon: Icons.open_in_new_rounded,
          color: _kDocBlue,
          onTap: () => _open(context),
        ),
        const SizedBox(width: 6),

        // Download button (opens in browser which triggers download for PDFs)
        _DocActionBtn(
          label: 'Download',
          icon: Icons.download_rounded,
          color: _kDocGreen,
          onTap: () => _open(context),
        ),
        const SizedBox(width: 6),

        // Delete
        GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete document?'),
              content: Text('Remove "$name" from this visit?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                  child: const Text('Delete',
                      style: TextStyle(color: _kRed)),
                ),
              ],
            ),
          ),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                size: 15, color: _kRed),
          ),
        ),
      ]),
    );
  }
}

class _DocActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _DocActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    ),
  );
}
