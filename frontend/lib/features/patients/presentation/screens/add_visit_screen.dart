import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/medical_report_entity.dart';
import '../../domain/entities/patient_entity.dart';
import '../../domain/entities/treatment_entity.dart';
import '../../domain/entities/vitals_entity.dart';
import '../providers/patient_details_provider.dart';

const _kDoctors = [
  'Dr. Alice Morgan',
  'Dr. Benjamin Carter',
  'Dr. Clara Singh',
  'Dr. David Okafor',
  'Dr. Elena Petrov',
  'Dr. Faisal Rahman',
];

const _kDepartments = [
  'Cardiology', 'Neurology', 'Orthopedics', 'Pediatrics',
  'General Medicine', 'Oncology', 'Emergency', 'Radiology',
  'Dermatology', 'Psychiatry',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class AddVisitScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final TreatmentEntity? existingVisit;
  final bool readOnly;
  final PatientEntity? patientEntity;

  const AddVisitScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.existingVisit,
    this.readOnly = false,
    this.patientEntity,
  });

  @override
  ConsumerState<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends ConsumerState<AddVisitScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Clinical ─────────────────────────────────────────────────────────────
  final _chiefComplaintCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _treatmentPlanCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _existingConditionsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();

  // ── Vitals ────────────────────────────────────────────────────────────────
  final _weightCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();

  // ── Visit meta ────────────────────────────────────────────────────────────
  VisitType _visitType = VisitType.followUp;
  String? _doctorAssigned;
  String? _department;
  DateTime _visitDate = DateTime.now();
  TimeOfDay _visitTime = TimeOfDay.now();

  // ── Accordion state ───────────────────────────────────────────────────────
  final List<bool> _expanded = List.generate(6, (i) => i == 0);

  // ── Files ─────────────────────────────────────────────────────────────────
  final _uploadedFiles = <_PickedFile>[];
  bool _picking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.existingVisit;
    if (v != null) {
      _chiefComplaintCtrl.text = v.chiefComplaint;
      _diagnosisCtrl.text = v.diagnosis ?? '';
      _treatmentPlanCtrl.text = v.treatmentPlan ?? '';
      _medicationsCtrl.text = v.medications.join(', ');
      _existingConditionsCtrl.text = v.existingConditions.join(', ');
      _notesCtrl.text = v.notes ?? '';
      _visitType = v.visitType;
      _doctorAssigned = v.doctorAssigned;
      _department = v.department;
      if (v.appointmentDateTime != null) {
        _visitDate = v.appointmentDateTime!;
        _visitTime = TimeOfDay.fromDateTime(v.appointmentDateTime!);
      }
      // Pre-fill vitals and follow-up
      _weightCtrl.text = v.weightKg?.toString() ?? '';
      _bpCtrl.text = v.bloodPressure ?? '';
      _tempCtrl.text = v.temperature?.toString() ?? '';
      _followUpCtrl.text = v.followUpInstructions ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _chiefComplaintCtrl, _diagnosisCtrl, _treatmentPlanCtrl,
      _medicationsCtrl, _existingConditionsCtrl, _notesCtrl,
      _followUpCtrl, _weightCtrl, _bpCtrl, _tempCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    if (widget.readOnly) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _visitDate = picked);
  }

  Future<void> _pickTime() async {
    if (widget.readOnly) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _visitTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _visitTime = picked);
  }

  Future<void> _pickFiles() async {
    if (_picking || widget.readOnly) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted) return;
      setState(() {
        for (final f in result.files) {
          if (f.bytes == null || f.size > 10 * 1024 * 1024) continue;
          _uploadedFiles.add(_PickedFile(
            id: const Uuid().v4(),
            name: f.name,
            ext: (f.extension ?? 'bin').toLowerCase(),
            sizeBytes: f.size,
            bytes: f.bytes!,
          ));
        }
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    final apptDt = DateTime(
      _visitDate.year, _visitDate.month, _visitDate.day,
      _visitTime.hour, _visitTime.minute,
    );

    final visit = TreatmentEntity(
      patientId: widget.patientId,
      chiefComplaint: _chiefComplaintCtrl.text.trim(),
      diagnosis: _diagnosisCtrl.text.trim().isEmpty ? null : _diagnosisCtrl.text.trim(),
      treatmentPlan: _treatmentPlanCtrl.text.trim().isEmpty ? null : _treatmentPlanCtrl.text.trim(),
      medications: _split(_medicationsCtrl.text),
      existingConditions: _split(_existingConditionsCtrl.text),
      doctorAssigned: _doctorAssigned,
      department: _department,
      visitType: _visitType,
      appointmentDateTime: apptDt,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      weightKg: double.tryParse(_weightCtrl.text.trim()),
      bloodPressure: _bpCtrl.text.trim().isEmpty ? null : _bpCtrl.text.trim(),
      temperature: double.tryParse(_tempCtrl.text.trim()),
      followUpInstructions: _followUpCtrl.text.trim().isEmpty
          ? null
          : _followUpCtrl.text.trim(),
    );

    ref.read(patientDetailsProvider.notifier).addVisit(visit);

    // Also persist vitals globally so the profile tab shows the latest
    final hasVitals = [_weightCtrl, _bpCtrl, _tempCtrl]
        .any((c) => c.text.trim().isNotEmpty);
    if (hasVitals) {
      ref.read(patientDetailsProvider.notifier).saveVitals(VitalsEntity(
        patientId: widget.patientId,
        weightKg: double.tryParse(_weightCtrl.text),
        bloodPressure: _bpCtrl.text.trim().isEmpty ? null : _bpCtrl.text.trim(),
        temperature: double.tryParse(_tempCtrl.text),
        recordedAt: now,
      ));
    }

    if (_uploadedFiles.isNotEmpty) {
      final reports = _uploadedFiles.map((f) => MedicalReportEntity(
        id: const Uuid().v4(),
        patientId: widget.patientId,
        fileName: f.name,
        extension: f.ext,
        reportType: ReportType.medicalReport,
        fileSizeBytes: f.sizeBytes,
        bytes: f.bytes,
        uploadedAt: now,
      )).toList();
      ref.read(patientDetailsProvider.notifier).saveReports(widget.patientId, reports);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Visit recorded successfully.'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
    ));
    Navigator.of(context).pop();
  }

  List<String> _split(String text) =>
      text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Fetch patient reports for the read-only view
    final patientDetails = widget.readOnly
        ? ref.watch(patientDetailDataProvider(widget.patientId))
        : null;
    final patientReports = patientDetails?.reports ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _PatientHeaderCard(
              patientEntity: widget.patientEntity,
              patientId: widget.patientId,
              patientName: widget.patientName,
              visitType: _visitType,
              visitDate: _visitDate,
              visitTime: _visitTime,
              doctor: _doctorAssigned,
              department: _department,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth >= 860;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SectionsColumn(
                          expanded: _expanded,
                          onToggle: (i) =>
                              setState(() => _expanded[i] = !_expanded[i]),
                          readOnly: widget.readOnly,
                          // Section 1 – Visit Details
                          visitType: _visitType,
                          onVisitTypeChanged: widget.readOnly
                              ? null
                              : (t) => setState(() => _visitType = t),
                          visitDate: _visitDate,
                          visitTime: _visitTime,
                          onPickDate: _pickDate,
                          onPickTime: _pickTime,
                          doctorAssigned: _doctorAssigned,
                          onDoctorChanged: widget.readOnly
                              ? null
                              : (v) => setState(() => _doctorAssigned = v),
                          department: _department,
                          onDeptChanged: widget.readOnly
                              ? null
                              : (v) => setState(() => _department = v),
                          // Section 2 – Clinical Notes
                          chiefComplaintCtrl: _chiefComplaintCtrl,
                          diagnosisCtrl: _diagnosisCtrl,
                          treatmentPlanCtrl: _treatmentPlanCtrl,
                          medicationsCtrl: _medicationsCtrl,
                          existingConditionsCtrl: _existingConditionsCtrl,
                          notesCtrl: _notesCtrl,
                          // Section 3 – Vitals
                          weightCtrl: _weightCtrl,
                          bpCtrl: _bpCtrl,
                          tempCtrl: _tempCtrl,
                          // Section 5 – Reports
                          uploadedFiles: _uploadedFiles,
                          patientReports: patientReports,
                          picking: _picking,
                          onPickFiles: _pickFiles,
                          onRemoveFile: (id) => setState(
                              () => _uploadedFiles.removeWhere((f) => f.id == id)),
                          // Section 6 – Follow-up
                          followUpCtrl: _followUpCtrl,
                        ),
                      ),
                      if (isWide)
                        _Sidebar(
                          visitType: _visitType,
                          visitDate: _visitDate,
                          visitTime: _visitTime,
                          doctor: _doctorAssigned,
                          department: _department,
                        ),
                    ],
                  );
                },
              ),
            ),
            _BottomBar(
              readOnly: widget.readOnly,
              saving: _saving,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.readOnly ? 'Visit Details' : 'Add New Visit',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              const Text('Visits',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const Icon(Icons.chevron_right_rounded,
                  size: 13, color: AppColors.textSecondary),
              Text(
                widget.readOnly ? 'Visit Details' : 'Add New Visit',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.readOnly) ...[
          _AppBarAction(icon: Icons.ios_share_rounded, label: 'Share', onTap: () {}),
          const SizedBox(width: 4),
          _AppBarAction(icon: Icons.print_outlined, label: 'Print', onTap: () {}),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Edit Visit',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(width: 12),
        ],
      ],
    );
  }
}

// ── App bar action button ─────────────────────────────────────────────────────

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AppBarAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textPrimary),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

// ── Patient header card ───────────────────────────────────────────────────────

class _PatientHeaderCard extends StatelessWidget {
  final PatientEntity? patientEntity;
  final String patientId;
  final String patientName;
  final VisitType visitType;
  final DateTime visitDate;
  final TimeOfDay visitTime;
  final String? doctor;
  final String? department;

  const _PatientHeaderCard({
    required this.patientEntity,
    required this.patientId,
    required this.patientName,
    required this.visitType,
    required this.visitDate,
    required this.visitTime,
    required this.doctor,
    required this.department,
  });

  Color _visitTypeColor(VisitType t) => switch (t) {
        VisitType.newVisit => AppColors.primary,
        VisitType.followUp => AppColors.success,
        VisitType.emergency => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final p = patientEntity;
    final pid = 'PT-${patientId.substring(0, 8).toUpperCase()}';
    final typeColor = _visitTypeColor(visitType);

    const avatarColors = [
      Color(0xFF6C63FF), Color(0xFF00C48C),
      Color(0xFF0095FF), Color(0xFF9C27B0),
    ];
    final avatarColor = avatarColors[patientId.hashCode.abs() % avatarColors.length];
    final initials = p?.initials ??
        patientName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: LayoutBuilder(builder: (ctx, cons) {
        final isNarrow = cons.maxWidth < 700;
        return isNarrow
            ? _buildNarrow(p, pid, initials, avatarColor, typeColor)
            : _buildWide(ctx, p, pid, initials, avatarColor, typeColor);
      }),
    );
  }

  Widget _buildWide(BuildContext context, PatientEntity? p, String pid,
      String initials, Color avatarColor, Color typeColor) {
    return Row(
      children: [
        // Avatar
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
                color: avatarColor,
                fontWeight: FontWeight.w800,
                fontSize: 18),
          ),
        ),
        const SizedBox(width: 14),

        // Name + meta
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  p?.fullName ?? patientName,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(width: 6),
                Icon(
                  (p?.gender == Gender.female)
                      ? Icons.female_rounded
                      : Icons.male_rounded,
                  size: 16,
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.badge_outlined, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(pid,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            if (p != null) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${p.age} Years, ${p.gender == Gender.male ? 'Male' : p.gender == Gender.female ? 'Female' : 'Other'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.phone_outlined,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(p.phone,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ],
        ),

        const Spacer(),

        // Meta chips
        Row(
          children: [
            _MetaChip(
              icon: Icons.event_note_outlined,
              iconColor: AppColors.primary,
              label: 'Visit Type',
              value: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: typeColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(visitType.label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MetaChip(
              icon: Icons.calendar_month_outlined,
              iconColor: const Color(0xFF00C48C),
              label: 'Visit Date',
              value: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(visitDate),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    visitTime.format(context),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MetaChip(
              icon: Icons.person_pin_rounded,
              iconColor: AppColors.info,
              label: 'Doctor',
              value: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    doctor ?? '—',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    department ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MetaChip(
              icon: Icons.business_outlined,
              iconColor: const Color(0xFFFF9800),
              label: 'Department',
              value: Text(
                department ?? '—',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNarrow(PatientEntity? p, String pid, String initials,
      Color avatarColor, Color typeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(initials,
                  style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p?.fullName ?? patientName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(pid,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _SmallChip(label: visitType.label, color: typeColor),
            _SmallChip(
                label: DateFormat('MMM d, yyyy').format(visitDate),
                color: AppColors.success),
            if (doctor != null) _SmallChip(label: doctor!, color: AppColors.info),
            if (department != null)
              _SmallChip(label: department!, color: const Color(0xFFFF9800)),
          ],
        ),
      ],
    );
  }

}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget value;

  const _MetaChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              value,
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

// ── Sections column ───────────────────────────────────────────────────────────

class _SectionsColumn extends StatelessWidget {
  final List<bool> expanded;
  final ValueChanged<int> onToggle;
  final bool readOnly;

  // Section 1
  final VisitType visitType;
  final ValueChanged<VisitType>? onVisitTypeChanged;
  final DateTime visitDate;
  final TimeOfDay visitTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final String? doctorAssigned;
  final ValueChanged<String?>? onDoctorChanged;
  final String? department;
  final ValueChanged<String?>? onDeptChanged;

  // Section 2
  final TextEditingController chiefComplaintCtrl;
  final TextEditingController diagnosisCtrl;
  final TextEditingController treatmentPlanCtrl;
  final TextEditingController medicationsCtrl;
  final TextEditingController existingConditionsCtrl;
  final TextEditingController notesCtrl;

  // Section 3
  final TextEditingController weightCtrl;
  final TextEditingController bpCtrl;
  final TextEditingController tempCtrl;

  // Section 5
  final List<_PickedFile> uploadedFiles;
  final List<MedicalReportEntity> patientReports;
  final bool picking;
  final VoidCallback onPickFiles;
  final ValueChanged<String> onRemoveFile;

  // Section 6
  final TextEditingController followUpCtrl;

  const _SectionsColumn({
    required this.expanded,
    required this.onToggle,
    required this.readOnly,
    required this.visitType,
    required this.onVisitTypeChanged,
    required this.visitDate,
    required this.visitTime,
    required this.onPickDate,
    required this.onPickTime,
    required this.doctorAssigned,
    required this.onDoctorChanged,
    required this.department,
    required this.onDeptChanged,
    required this.chiefComplaintCtrl,
    required this.diagnosisCtrl,
    required this.treatmentPlanCtrl,
    required this.medicationsCtrl,
    required this.existingConditionsCtrl,
    required this.notesCtrl,
    required this.weightCtrl,
    required this.bpCtrl,
    required this.tempCtrl,
    required this.uploadedFiles,
    required this.patientReports,
    required this.picking,
    required this.onPickFiles,
    required this.onRemoveFile,
    required this.followUpCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Visit Details
        _AccordionSection(
          index: 0,
          number: '1',
          title: 'Visit Details',
          icon: Icons.event_note_outlined,
          iconColor: AppColors.primary,
          isExpanded: expanded[0],
          onToggle: () => onToggle(0),
          child: _VisitDetailsContent(
            readOnly: readOnly,
            visitType: visitType,
            onVisitTypeChanged: onVisitTypeChanged,
            visitDate: visitDate,
            visitTime: visitTime,
            onPickDate: onPickDate,
            onPickTime: onPickTime,
            doctorAssigned: doctorAssigned,
            onDoctorChanged: onDoctorChanged,
            department: department,
            onDeptChanged: onDeptChanged,
          ),
        ),
        const SizedBox(height: 10),

        // 2. Clinical Notes
        _AccordionSection(
          index: 1,
          number: '2',
          title: 'Clinical Notes',
          icon: Icons.medical_services_outlined,
          iconColor: AppColors.info,
          isExpanded: expanded[1],
          onToggle: () => onToggle(1),
          child: Column(
            children: [
              AppTextField(
                label: 'Chief Complaint',
                hint: 'Primary reason for this visit…',
                controller: chiefComplaintCtrl,
                prefixIcon: const Icon(Icons.assignment_outlined),
                maxLines: 2,
                readOnly: readOnly,
                validator: readOnly
                    ? null
                    : (v) => (v == null || v.trim().isEmpty)
                        ? 'Chief complaint is required'
                        : null,
              ),
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                label: 'Diagnosis',
                hint: 'Clinical diagnosis…',
                controller: diagnosisCtrl,
                prefixIcon: const Icon(Icons.local_hospital_outlined),
                readOnly: readOnly,
              ),
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                label: 'Existing Conditions',
                hint: 'Comma-separated — e.g. Diabetes, Hypertension',
                controller: existingConditionsCtrl,
                prefixIcon: const Icon(Icons.history_edu_outlined),
                readOnly: readOnly,
              ),
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                label: 'Notes',
                hint: 'Additional clinical notes…',
                controller: notesCtrl,
                prefixIcon: const Icon(Icons.notes_rounded),
                maxLines: 3,
                readOnly: readOnly,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Patient Vitals
        _VitalsSection(
          isExpanded: expanded[2],
          onToggle: () => onToggle(2),
          weightCtrl: weightCtrl,
          bpCtrl: bpCtrl,
          tempCtrl: tempCtrl,
          readOnly: readOnly,
        ),
        const SizedBox(height: 10),

        // 4. Treatment & Prescription
        _AccordionSection(
          index: 3,
          number: '4',
          title: 'Treatment & Prescription',
          icon: Icons.medication_outlined,
          iconColor: const Color(0xFF9C27B0),
          isExpanded: expanded[3],
          onToggle: () => onToggle(3),
          child: Column(
            children: [
              AppTextField(
                label: 'Treatment Plan',
                hint: 'Describe the treatment plan…',
                controller: treatmentPlanCtrl,
                prefixIcon: const Icon(Icons.playlist_add_check_rounded),
                maxLines: 3,
                readOnly: readOnly,
              ),
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                label: 'Medications Prescribed',
                hint: 'Comma-separated — e.g. Paracetamol 500mg, Ibuprofen',
                controller: medicationsCtrl,
                prefixIcon: const Icon(Icons.medication_outlined),
                readOnly: readOnly,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 5. Reports & Documents
        _AccordionSection(
          index: 4,
          number: '5',
          title: 'Reports & Documents',
          icon: Icons.folder_outlined,
          iconColor: AppColors.success,
          isExpanded: expanded[4],
          onToggle: () => onToggle(4),
          child: _ReportsContent(
            readOnly: readOnly,
            uploadedFiles: uploadedFiles,
            patientReports: patientReports,
            picking: picking,
            onPickFiles: onPickFiles,
            onRemoveFile: onRemoveFile,
          ),
        ),
        const SizedBox(height: 10),

        // 6. Follow-up & Instructions
        _AccordionSection(
          index: 5,
          number: '6',
          title: 'Follow-up & Instructions',
          icon: Icons.chat_bubble_outline_rounded,
          iconColor: const Color(0xFFFF9800),
          isExpanded: expanded[5],
          onToggle: () => onToggle(5),
          child: AppTextField(
            label: 'Follow-up Instructions',
            hint: 'Describe follow-up plan, next appointment, patient instructions…',
            controller: followUpCtrl,
            prefixIcon: const Icon(Icons.event_repeat_outlined),
            maxLines: 4,
            readOnly: readOnly,
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Accordion section ─────────────────────────────────────────────────────────

class _AccordionSection extends StatelessWidget {
  final int index;
  final String number;
  final String title;
  final IconData icon;
  final Color iconColor;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  const _AccordionSection({
    required this.index,
    required this.number,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      number,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? iconColor : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 1, color: iconColor.withValues(alpha: 0.15)),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: child,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Visit Details content ─────────────────────────────────────────────────────

class _VisitDetailsContent extends StatelessWidget {
  final bool readOnly;
  final VisitType visitType;
  final ValueChanged<VisitType>? onVisitTypeChanged;
  final DateTime visitDate;
  final TimeOfDay visitTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final String? doctorAssigned;
  final ValueChanged<String?>? onDoctorChanged;
  final String? department;
  final ValueChanged<String?>? onDeptChanged;

  const _VisitDetailsContent({
    required this.readOnly,
    required this.visitType,
    required this.onVisitTypeChanged,
    required this.visitDate,
    required this.visitTime,
    required this.onPickDate,
    required this.onPickTime,
    required this.doctorAssigned,
    required this.onDoctorChanged,
    required this.department,
    required this.onDeptChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Visit type
        const Text('VISIT TYPE',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [VisitType.followUp, VisitType.emergency].map((t) {
            final sel = visitType == t;
            Color tc = t == VisitType.followUp ? AppColors.success : AppColors.error;
            return GestureDetector(
              onTap: onVisitTypeChanged == null ? null : () => onVisitTypeChanged!(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? tc : Colors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
                  border: Border.all(color: sel ? tc : AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: sel ? Colors.white : tc,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Date + Time
        LayoutBuilder(builder: (ctx, cons) {
          final side = (cons.maxWidth - 12) / 2;
          return Row(
            children: [
              SizedBox(
                width: side,
                child: GestureDetector(
                  onTap: readOnly ? null : onPickDate,
                  child: AbsorbPointer(
                    child: AppTextField(
                      label: 'Visit Date',
                      controller: TextEditingController(
                          text: DateFormat('MMM d, yyyy').format(visitDate)),
                      readOnly: true,
                      enabled: !readOnly,
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: side,
                child: GestureDetector(
                  onTap: readOnly ? null : onPickTime,
                  child: AbsorbPointer(
                    child: AppTextField(
                      label: 'Time',
                      controller: TextEditingController(
                          text: visitTime.format(context)),
                      readOnly: true,
                      enabled: !readOnly,
                      prefixIcon: const Icon(Icons.access_time_rounded),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ── Patient Vitals section (special) ─────────────────────────────────────────

class _VitalsSection extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final TextEditingController weightCtrl;
  final TextEditingController bpCtrl;
  final TextEditingController tempCtrl;
  final bool readOnly;

  const _VitalsSection({
    required this.isExpanded,
    required this.onToggle,
    required this.weightCtrl,
    required this.bpCtrl,
    required this.tempCtrl,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    const iconColor = AppColors.error;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isExpanded ? iconColor.withValues(alpha: 0.25) : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isExpanded
                    ? const Color(0xFFFFF5F5)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: const Text('3',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: iconColor)),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.favorite_outline_rounded,
                      size: 18, color: iconColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Patient Vitals',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? iconColor : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(
                          height: 1,
                          color: iconColor.withValues(alpha: 0.15)),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _VitalsCards(
                          weightCtrl: weightCtrl,
                          bpCtrl: bpCtrl,
                          tempCtrl: tempCtrl,
                          readOnly: readOnly,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _VitalsCards extends StatefulWidget {
  final TextEditingController weightCtrl;
  final TextEditingController bpCtrl;
  final TextEditingController tempCtrl;
  final bool readOnly;

  const _VitalsCards({
    required this.weightCtrl,
    required this.bpCtrl,
    required this.tempCtrl,
    required this.readOnly,
  });

  @override
  State<_VitalsCards> createState() => _VitalsCardsState();
}

class _VitalsCardsState extends State<_VitalsCards> {
  @override
  void initState() {
    super.initState();
    widget.weightCtrl.addListener(_rebuild);
    widget.bpCtrl.addListener(_rebuild);
    widget.tempCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.weightCtrl.removeListener(_rebuild);
    widget.bpCtrl.removeListener(_rebuild);
    widget.tempCtrl.removeListener(_rebuild);
    super.dispose();
  }

  _VitalStatus _weightStatus() {
    final v = widget.weightCtrl.text.trim();
    if (v.isEmpty) return _VitalStatus.empty;
    return double.tryParse(v) != null
        ? _VitalStatus.normal
        : _VitalStatus.abnormal;
  }

  _VitalStatus _bpStatus() {
    final v = widget.bpCtrl.text.trim();
    if (v.isEmpty) return _VitalStatus.empty;
    final parts = v.split('/');
    if (parts.length != 2) return _VitalStatus.abnormal;
    final sys = int.tryParse(parts[0]);
    final dia = int.tryParse(parts[1]);
    if (sys == null || dia == null) return _VitalStatus.abnormal;
    if (sys >= 90 && sys <= 120 && dia >= 60 && dia <= 80) {
      return _VitalStatus.normal;
    }
    return _VitalStatus.abnormal;
  }

  _VitalStatus _tempStatus() {
    final v = widget.tempCtrl.text.trim();
    if (v.isEmpty) return _VitalStatus.empty;
    final t = double.tryParse(v);
    if (t == null) return _VitalStatus.abnormal;
    return (t >= 36.1 && t <= 37.2) ? _VitalStatus.normal : _VitalStatus.abnormal;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cons) {
      final isNarrow = cons.maxWidth < 500;
      if (isNarrow) {
        return Column(
          children: [
            _VitalCard(
              icon: Icons.monitor_weight_outlined,
              iconColor: AppColors.success,
              label: 'Weight',
              unit: 'kg',
              ctrl: widget.weightCtrl,
              readOnly: widget.readOnly,
              status: _weightStatus(),
            ),
            const SizedBox(height: 10),
            _VitalCard(
              icon: Icons.bloodtype_outlined,
              iconColor: AppColors.error,
              label: 'Blood Pressure',
              unit: 'mmHg',
              ctrl: widget.bpCtrl,
              readOnly: widget.readOnly,
              status: _bpStatus(),
              keyboardType: TextInputType.text,
              hint: '120/80',
            ),
            const SizedBox(height: 10),
            _VitalCard(
              icon: Icons.thermostat_outlined,
              iconColor: const Color(0xFFFF9800),
              label: 'Temperature',
              unit: '°C',
              ctrl: widget.tempCtrl,
              readOnly: widget.readOnly,
              status: _tempStatus(),
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(
            child: _VitalCard(
              icon: Icons.monitor_weight_outlined,
              iconColor: AppColors.success,
              label: 'Weight',
              unit: 'kg',
              ctrl: widget.weightCtrl,
              readOnly: widget.readOnly,
              status: _weightStatus(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _VitalCard(
              icon: Icons.bloodtype_outlined,
              iconColor: AppColors.error,
              label: 'Blood Pressure',
              unit: 'mmHg',
              ctrl: widget.bpCtrl,
              readOnly: widget.readOnly,
              status: _bpStatus(),
              keyboardType: TextInputType.text,
              hint: '120/80',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _VitalCard(
              icon: Icons.thermostat_outlined,
              iconColor: const Color(0xFFFF9800),
              label: 'Temperature',
              unit: '°C',
              ctrl: widget.tempCtrl,
              readOnly: widget.readOnly,
              status: _tempStatus(),
            ),
          ),
        ],
      );
    });
  }
}

enum _VitalStatus { empty, normal, abnormal }

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String unit;
  final TextEditingController ctrl;
  final bool readOnly;
  final _VitalStatus status;
  final TextInputType keyboardType;
  final String? hint;

  const _VitalCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.unit,
    required this.ctrl,
    required this.readOnly,
    required this.status,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = status == _VitalStatus.normal
        ? AppColors.success
        : status == _VitalStatus.abnormal
            ? AppColors.error
            : AppColors.textDisabled;
    final statusLabel = status == _VitalStatus.normal
        ? 'Normal'
        : status == _VitalStatus.abnormal
            ? 'Abnormal'
            : '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextFormField(
                  controller: ctrl,
                  readOnly: readOnly,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: hint ?? '—',
                    hintStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textDisabled),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }
}

// ── Reports content ───────────────────────────────────────────────────────────

class _ReportsContent extends StatelessWidget {
  final bool readOnly;
  final List<_PickedFile> uploadedFiles;
  final List<MedicalReportEntity> patientReports;
  final bool picking;
  final VoidCallback onPickFiles;
  final ValueChanged<String> onRemoveFile;

  const _ReportsContent({
    required this.readOnly,
    required this.uploadedFiles,
    required this.patientReports,
    required this.picking,
    required this.onPickFiles,
    required this.onRemoveFile,
  });

  @override
  Widget build(BuildContext context) {
    // In read-only mode, show the patient's stored reports
    if (readOnly) {
      if (patientReports.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No documents attached to this visit.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: patientReports
            .map((r) => _PatientReportTile(report: r))
            .toList(),
      );
    }

    // Edit mode: upload zone + already-picked files
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DropZone(picking: picking, onTap: onPickFiles),
        if (uploadedFiles.isNotEmpty) const SizedBox(height: 10),
        ...uploadedFiles.map((f) => _FileChip(
              file: f,
              readOnly: false,
              onRemove: () => onRemoveFile(f.id),
            )),
      ],
    );
  }
}

class _PatientReportTile extends StatelessWidget {
  final MedicalReportEntity report;
  const _PatientReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: report.isImage
                  ? AppColors.info.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              report.isImage
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_rounded,
              color: report.isImage ? AppColors.info : AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.fileName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${report.extension.toUpperCase()}  ·  ${report.sizeLabel}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final VisitType visitType;
  final DateTime visitDate;
  final TimeOfDay visitTime;
  final String? doctor;
  final String? department;

  const _Sidebar({
    required this.visitType,
    required this.visitDate,
    required this.visitTime,
    required this.doctor,
    required this.department,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      margin: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Visit Summary
            _SidebarCard(
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.primary,
              title: 'Visit Summary',
              child: Column(
                children: [
                  _SummaryRow(
                      icon: Icons.event_note_outlined,
                      label: 'Visit Type',
                      value: visitType.label),
                  _SummaryRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'Visit Date',
                      value: DateFormat('MMM d, yyyy').format(visitDate)),
                  _SummaryRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: visitTime.format(context)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick Actions
            _SidebarCard(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFFF9800),
              title: 'Quick Actions',
              child: Column(
                children: [
                  _QuickAction(
                      icon: Icons.medication_outlined,
                      iconColor: AppColors.primary,
                      label: 'Add Prescription'),
                  _QuickAction(
                      icon: Icons.upload_file_rounded,
                      iconColor: AppColors.info,
                      label: 'Upload Document'),
                  _QuickAction(
                      icon: Icons.event_repeat_outlined,
                      iconColor: AppColors.success,
                      label: 'Add Follow-up'),
                  _QuickAction(
                      icon: Icons.summarize_outlined,
                      iconColor: const Color(0xFFFF9800),
                      label: 'Generate Report'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SidebarCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 7),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          Container(height: 2, color: AppColors.primary, width: 30,
              margin: const EdgeInsets.only(left: 14, bottom: 8)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 7),
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _QuickAction({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label — coming soon'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final String time;
  final String label;
  final Color color;

  const _TimelineEntry({
    required this.time,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(time,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool readOnly;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  const _BottomBar({
    required this.readOnly,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: readOnly ? onCancel : onSave,
              icon: Icon(
                readOnly ? Icons.close_rounded : Icons.check_rounded,
                size: 18,
              ),
              label: Text(
                readOnly ? 'Close' : saving ? 'Saving…' : 'Save Visit',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── File upload helpers ───────────────────────────────────────────────────────

class _PickedFile {
  final String id;
  final String name;
  final String ext;
  final int sizeBytes;
  final Uint8List bytes;

  const _PickedFile({
    required this.id,
    required this.name,
    required this.ext,
    required this.sizeBytes,
    required this.bytes,
  });

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DropZone extends StatefulWidget {
  final bool picking;
  final VoidCallback onTap;
  const _DropZone({required this.picking, required this.onTap});

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.picking ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 90,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.primarySurface : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: _hovered ? AppColors.primary : AppColors.border,
              width: _hovered ? 1.5 : 1,
            ),
          ),
          child: widget.picking
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 24,
                        color: _hovered
                            ? AppColors.primary
                            : AppColors.textSecondary),
                    const SizedBox(height: 6),
                    Text(
                      'Click to upload  ·  PDF · JPG · PNG',
                      style: TextStyle(
                        fontSize: 12,
                        color: _hovered
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final _PickedFile file;
  final bool readOnly;
  final VoidCallback onRemove;

  const _FileChip({
    required this.file,
    required this.readOnly,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            file.ext == 'pdf'
                ? Icons.picture_as_pdf_outlined
                : Icons.image_outlined,
            size: 18,
            color: file.ext == 'pdf' ? AppColors.error : AppColors.info,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(file.name,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          Text(file.sizeLabel,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          if (!readOnly) ...[
            const SizedBox(width: AppDimensions.sm),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 12, color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
