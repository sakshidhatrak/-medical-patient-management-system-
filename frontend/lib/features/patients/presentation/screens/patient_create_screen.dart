import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/printable_field_wrapper.dart';
import '../../domain/entities/medical_report_entity.dart';
import '../../domain/entities/patient_entity.dart';
import '../../domain/entities/treatment_entity.dart';
import '../../domain/entities/vitals_entity.dart';
import '../../services/patient_print_service.dart';
import '../providers/patient_details_provider.dart';
import '../providers/patient_provider.dart';
import '../widgets/form_section_card.dart';
import '../widgets/treatment_form_section.dart';

const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

class PatientCreateScreen extends ConsumerStatefulWidget {
  const PatientCreateScreen({super.key});

  @override
  ConsumerState<PatientCreateScreen> createState() =>
      _PatientCreateScreenState();
}

class _PatientCreateScreenState extends ConsumerState<PatientCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Basic Info ──────────────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // ── Treatment ───────────────────────────────────────────────────────────────
  final _chiefComplaintCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _treatmentPlanCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _existingConditionsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // ── Vitals ──────────────────────────────────────────────────────────────────
  final _weightCtrl = TextEditingController();
  final _bloodPressureCtrl = TextEditingController();
  final _temperatureCtrl = TextEditingController();

  // ── Picker / dropdown state ─────────────────────────────────────────────────
  DateTime? _dob;
  Gender _gender = Gender.preferNotToSay;
  String? _bloodType;

  VisitType _visitType = VisitType.newVisit;

  bool _saving = false;
  bool _printing = false;
  bool _picking = false;

  // ── Upload ──────────────────────────────────────────────────────────────────
  final _uploadedFiles = <_UploadedFile>[];

  // ── Print selection ─────────────────────────────────────────────────────────
  final _printSelected = <String>{};

  void _togglePrint(String id) {
    setState(() {
      if (_printSelected.contains(id)) {
        _printSelected.remove(id);
      } else {
        _printSelected.add(id);
      }
    });
  }

  Future<void> _pickFiles() async {
    if (_picking) return;
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
          _uploadedFiles.add(_UploadedFile(
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

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl,
      _phoneCtrl, _emailCtrl, _addressCtrl,
      _chiefComplaintCtrl, _diagnosisCtrl, _treatmentPlanCtrl,
      _medicationsCtrl, _existingConditionsCtrl, _notesCtrl,
      _weightCtrl, _bloodPressureCtrl, _temperatureCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  List<String> _splitComma(String text) => text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  bool _anyFilled(List<TextEditingController> ctrls) =>
      ctrls.any((c) => c.text.trim().isNotEmpty);

  Widget _twoCol(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 580) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: AppDimensions.sm),
              Expanded(child: right),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            left,
            const SizedBox(height: AppDimensions.md),
            right,
          ],
        );
      },
    );
  }

  // ── Collect current form values for selected print fields ──────────────────

  String _genderLabel(Gender g) => switch (g) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
        Gender.preferNotToSay => 'Prefer not to say',
      };

  List<({String label, String value})> _collectPrintData() {
    final result = <({String label, String value})>[];

    void add(String id, String label, String value) {
      if (_printSelected.contains(id)) {
        result.add((label: label, value: value));
      }
    }

    // Basic Information
    add('firstName', 'First Name', _firstNameCtrl.text.trim());
    add('lastName', 'Last Name', _lastNameCtrl.text.trim());
    add('dob', 'Date of Birth',
        _dob != null ? DateFormat('MMMM d, yyyy').format(_dob!) : '');
    add('gender', 'Gender', _genderLabel(_gender));
    add('phone', 'Phone Number', _phoneCtrl.text.trim());
    add('email', 'Email', _emailCtrl.text.trim());
    add('address', 'Address', _addressCtrl.text.trim());
    add('bloodType', 'Blood Type', _bloodType ?? '');

    // Patient Vitals
    final w = _weightCtrl.text.trim();
    add('weight', 'Weight', w.isEmpty ? '' : '$w kg');
    add('bloodPressure', 'Blood Pressure', _bloodPressureCtrl.text.trim());
    final t = _temperatureCtrl.text.trim();
    add('temperature', 'Temperature', t.isEmpty ? '' : '$t °C');

    // Treatment Information
    add('chiefComplaint', 'Chief Complaint', _chiefComplaintCtrl.text.trim());
    add('diagnosis', 'Diagnosis', _diagnosisCtrl.text.trim());
    add('treatmentPlan', 'Treatment Plan', _treatmentPlanCtrl.text.trim());
    add('medications', 'Medications', _medicationsCtrl.text.trim());
    add('existingConditions', 'Existing Conditions',
        _existingConditionsCtrl.text.trim());
    add('notes', 'Notes', _notesCtrl.text.trim());

    return result;
  }

  String get _patientName {
    final fn = _firstNameCtrl.text.trim();
    final ln = _lastNameCtrl.text.trim();
    if (fn.isEmpty && ln.isEmpty) return 'Patient';
    return '$fn $ln'.trim();
  }

  // ── Print sheet ─────────────────────────────────────────────────────────────

  void _showPrintSheet() {
    final fields = _collectPrintData();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrintSheet(
        patientName: _patientName,
        fields: fields,
        onPrint: () async {
          setState(() => _printing = true);
          try {
            await PatientPrintService.printFields(
              patientName: _patientName,
              fields: fields,
            );
          } finally {
            if (mounted) setState(() => _printing = false);
          }
        },
        onExport: () async {
          setState(() => _printing = true);
          try {
            await PatientPrintService.exportPdf(
              patientName: _patientName,
              fields: fields,
            );
          } finally {
            if (mounted) setState(() => _printing = false);
          }
        },
      ),
    );
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date of birth.')),
      );
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final patientId = const Uuid().v4();

    final patient = PatientEntity(
      id: patientId,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      dateOfBirth: _dob!,
      gender: _gender,
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      bloodType: _bloodType,
      createdAt: now,
      updatedAt: now,
    );

    final ok =
        await ref.read(patientsProvider.notifier).createPatient(patient);
    if (!mounted) return;

    if (!ok) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save patient. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_chiefComplaintCtrl.text.trim().isNotEmpty) {
      ref.read(patientDetailsProvider.notifier).saveTreatment(
            TreatmentEntity(
              patientId: patientId,
              chiefComplaint: _chiefComplaintCtrl.text.trim(),
              diagnosis: _diagnosisCtrl.text.trim().isEmpty
                  ? null
                  : _diagnosisCtrl.text.trim(),
              treatmentPlan: _treatmentPlanCtrl.text.trim().isEmpty
                  ? null
                  : _treatmentPlanCtrl.text.trim(),
              medications: _splitComma(_medicationsCtrl.text),
              existingConditions: _splitComma(_existingConditionsCtrl.text),
              visitType: _visitType,
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
              weightKg: double.tryParse(_weightCtrl.text.trim()),
              bloodPressure: _bloodPressureCtrl.text.trim().isEmpty
                  ? null
                  : _bloodPressureCtrl.text.trim(),
              temperature: double.tryParse(_temperatureCtrl.text.trim()),
            ),
          );
    }

    if (_anyFilled([_weightCtrl, _bloodPressureCtrl, _temperatureCtrl])) {
      ref.read(patientDetailsProvider.notifier).saveVitals(
            VitalsEntity(
              patientId: patientId,
              weightKg: double.tryParse(_weightCtrl.text),
              bloodPressure: _bloodPressureCtrl.text.trim().isEmpty
                  ? null
                  : _bloodPressureCtrl.text.trim(),
              temperature: double.tryParse(_temperatureCtrl.text),
              recordedAt: now,
            ),
          );
    }

    if (_uploadedFiles.isNotEmpty) {
      final reports = _uploadedFiles.map((f) => MedicalReportEntity(
        id: const Uuid().v4(),
        patientId: patientId,
        fileName: f.name,
        extension: f.ext,
        reportType: ReportType.medicalReport,
        fileSizeBytes: f.sizeBytes,
        bytes: f.bytes,
        uploadedAt: now,
      )).toList();
      ref.read(patientDetailsProvider.notifier).saveReports(patientId, reports);
    }

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${patient.fullName} registered successfully.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),
    );
    context.pop();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasSelection = _printSelected.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'New Patient',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Print selection hint chip
          if (hasSelection)
            Padding(
              padding:
                  const EdgeInsets.only(right: AppDimensions.sm),
              child: _PrintHintChip(
                count: _printSelected.length,
                onTap: _showPrintSheet,
                onClear: () =>
                    setState(() => _printSelected.clear()),
              ),
            ),
        ],
      ),
      // Print FAB — appears as soon as a field is double-tapped
      floatingActionButton: hasSelection
          ? _PrintFab(
              count: _printSelected.length,
              isPrinting: _printing,
              onTap: _showPrintSheet,
            )
          : null,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.md,
            AppDimensions.sm,
            AppDimensions.md,
            100, // extra bottom space for FAB
          ),
          children: [
            // ── Tip banner (shown before any field selected) ────────────
            if (!hasSelection) const _PrintTipBanner(),

            // ── 1. Basic Information (includes vitals) ─────────────────
            const SizedBox(height: AppDimensions.sm),
            _BasicInfoSection(
              firstNameCtrl: _firstNameCtrl,
              lastNameCtrl: _lastNameCtrl,
              phoneCtrl: _phoneCtrl,
              emailCtrl: _emailCtrl,
              addressCtrl: _addressCtrl,
              dob: _dob,
              gender: _gender,
              bloodType: _bloodType,
              weightCtrl: _weightCtrl,
              bloodPressureCtrl: _bloodPressureCtrl,
              temperatureCtrl: _temperatureCtrl,
              onPickDob: _pickDob,
              onGenderChanged: (v) => setState(() => _gender = v!),
              onBloodTypeChanged: (v) => setState(() => _bloodType = v),
              twoCol: _twoCol,
              printSelected: _printSelected,
              onPrintToggle: _togglePrint,
            ),
            const SizedBox(height: AppDimensions.md),

            // ── 2. Treatment Information ────────────────────────────────
            TreatmentFormSection(
              chiefComplaintCtrl: _chiefComplaintCtrl,
              diagnosisCtrl: _diagnosisCtrl,
              treatmentPlanCtrl: _treatmentPlanCtrl,
              medicationsCtrl: _medicationsCtrl,
              existingConditionsCtrl: _existingConditionsCtrl,
              notesCtrl: _notesCtrl,
              visitType: _visitType,
              onVisitTypeChanged: (v) => setState(() => _visitType = v),
              printSelected: _printSelected,
              onPrintToggle: _togglePrint,
            ),
            const SizedBox(height: AppDimensions.md),

            // ── 4. Upload Documents ─────────────────────────────────────
            _UploadSection(
              uploadedFiles: _uploadedFiles,
              picking: _picking,
              onPickFiles: _pickFiles,
              onRemoveFile: (id) => setState(
                  () => _uploadedFiles.removeWhere((f) => f.id == id)),
            ),
            const SizedBox(height: AppDimensions.xl),

            // ── Save ────────────────────────────────────────────────────
            AppButton(
              label: 'Save Patient',
              onPressed: _saving ? null : _submit,
              isLoading: _saving,
              leadingIcon: Icons.save_rounded,
            ),
            const SizedBox(height: AppDimensions.md),
          ],
        ),
      ),
    );
  }
}

// ── Basic Information section ─────────────────────────────────────────────────

typedef _TwoColBuilder = Widget Function(Widget left, Widget right);

class _BasicInfoSection extends StatelessWidget {
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController addressCtrl;
  final DateTime? dob;
  final Gender gender;
  final String? bloodType;
  // Vitals (now part of basic info)
  final TextEditingController weightCtrl;
  final TextEditingController bloodPressureCtrl;
  final TextEditingController temperatureCtrl;
  final VoidCallback onPickDob;
  final ValueChanged<Gender?> onGenderChanged;
  final ValueChanged<String?> onBloodTypeChanged;
  final _TwoColBuilder twoCol;
  final Set<String> printSelected;
  final ValueChanged<String> onPrintToggle;

  const _BasicInfoSection({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.addressCtrl,
    required this.dob,
    required this.gender,
    required this.bloodType,
    required this.weightCtrl,
    required this.bloodPressureCtrl,
    required this.temperatureCtrl,
    required this.onPickDob,
    required this.onGenderChanged,
    required this.onBloodTypeChanged,
    required this.twoCol,
    required this.printSelected,
    required this.onPrintToggle,
  });

  bool _sel(String id) => printSelected.contains(id);

  Widget _wrap(String id, Widget child) => PrintableFieldWrapper(
        fieldId: id,
        isSelected: _sel(id),
        onToggle: () => onPrintToggle(id),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return FormSectionCard(
      title: 'Basic Information',
      icon: Icons.person_outlined,
      iconColor: AppColors.primary,
      children: [
        // Row 1: First Name · Last Name
        twoCol(
          _wrap(
            'firstName',
            AppTextField(
              label: 'First Name',
              controller: firstNameCtrl,
              prefixIcon: const Icon(Icons.person_outline),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ),
          _wrap(
            'lastName',
            AppTextField(
              label: 'Last Name',
              controller: lastNameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ),
        ),

        // Row 2: Date of Birth · Gender
        twoCol(
          _wrap(
            'dob',
            GestureDetector(
              onTap: onPickDob,
              child: AbsorbPointer(
                child: AppTextField(
                  label: 'Date of Birth',
                  controller: TextEditingController(
                    text: dob != null
                        ? DateFormat('MMMM d, yyyy').format(dob!)
                        : '',
                  ),
                  hint: 'Select date',
                  readOnly: true,
                  prefixIcon: const Icon(Icons.cake_outlined),
                  validator: (_) =>
                      dob == null ? 'Date of birth is required' : null,
                ),
              ),
            ),
          ),
          _wrap(
            'gender',
            _DropdownField<Gender>(
              label: 'Gender',
              value: gender,
              icon: Icons.wc_rounded,
              items: const {
                Gender.male: 'Male',
                Gender.female: 'Female',
                Gender.other: 'Other',
                Gender.preferNotToSay: 'Prefer not to say',
              },
              onChanged: onGenderChanged,
            ),
          ),
        ),

        // Row 3: Phone · Email
        twoCol(
          _wrap(
            'phone',
            AppTextField(
              label: 'Phone Number',
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ),
          _wrap(
            'email',
            AppTextField(
              label: 'Email (optional)',
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
        ),

        // Row 4: Address — full width (multiline)
        _wrap(
          'address',
          AppTextField(
            label: 'Address (optional)',
            hint: 'Street, City, State ZIP',
            controller: addressCtrl,
            prefixIcon: const Icon(Icons.location_on_outlined),
            maxLines: 2,
          ),
        ),

        // Row 5: Blood Type — full width
        _wrap(
          'bloodType',
          _DropdownField<String?>(
            label: 'Blood Type (optional)',
            value: bloodType,
            icon: Icons.bloodtype_outlined,
            items: {
              null: '— Not specified —',
              for (final t in _bloodTypes) t: t,
            },
            onChanged: onBloodTypeChanged,
          ),
        ),

        // ── Patient Vitals (inline) ───────────────────────────────────
        const Divider(height: 24),
        const FieldGroupLabel('Patient Vitals'),
        const SizedBox(height: 8),
        twoCol(
          _wrap(
            'weight',
            AppTextField(
              label: 'Weight (kg)',
              hint: '70',
              controller: weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: const Icon(Icons.monitor_weight_outlined,
                  color: AppColors.success),
            ),
          ),
          _wrap(
            'bloodPressure',
            AppTextField(
              label: 'Blood Pressure',
              hint: '120/80',
              controller: bloodPressureCtrl,
              keyboardType: TextInputType.text,
              prefixIcon: const Icon(Icons.bloodtype_outlined),
            ),
          ),
        ),
        _wrap(
          'temperature',
          AppTextField(
            label: 'Temperature (°C)',
            hint: '37.0',
            controller: temperatureCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: const Icon(Icons.thermostat_outlined,
                color: AppColors.warning),
          ),
        ),
      ],
    );
  }
}

// ── Print tip banner ──────────────────────────────────────────────────────────

class _PrintTipBanner extends StatelessWidget {
  const _PrintTipBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: AppDimensions.sm),
          const Expanded(
            child: Text(
              'Double-click any field to add it to your print selection',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Print hint chip (in AppBar) ───────────────────────────────────────────────

class _PrintHintChip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _PrintHintChip({
    required this.count,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
          border:
              Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.print_rounded,
                size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              '$count selected',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded,
                  size: 12, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Print FAB ─────────────────────────────────────────────────────────────────

class _PrintFab extends StatelessWidget {
  final int count;
  final bool isPrinting;
  final VoidCallback onTap;

  const _PrintFab({
    required this.count,
    required this.isPrinting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: isPrinting ? null : onTap,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: isPrinting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.print_rounded),
      label: Text(
        isPrinting
            ? 'Generating…'
            : 'Print  $count field${count == 1 ? '' : 's'}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Print sheet ───────────────────────────────────────────────────────────────

class _PrintSheet extends StatelessWidget {
  final String patientName;
  final List<({String label, String value})> fields;
  final VoidCallback onPrint;
  final VoidCallback onExport;

  const _PrintSheet({
    required this.patientName,
    required this.fields,
    required this.onPrint,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: const Icon(Icons.print_rounded,
                      size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Print Selected Fields',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Patient: $patientName  ·  ${fields.length} field${fields.length == 1 ? '' : 's'} selected',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Field preview list
          if (fields.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppDimensions.lg),
              child: Text(
                'No fields selected. Double-click a field on the form to add it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                itemCount: fields.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (_, i) {
                  final f = fields[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            f.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            f.value.isEmpty ? '—' : f.value,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: fields.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onExport();
                          },
                    icon: const Icon(Icons.picture_as_pdf_rounded,
                        size: 16),
                    label: const Text('Export PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: fields.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onPrint();
                          },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ── Upload helpers ────────────────────────────────────────────────────────────

class _UploadedFile {
  final String id;
  final String name;
  final String ext;
  final int sizeBytes;
  final Uint8List bytes;

  const _UploadedFile({
    required this.id,
    required this.name,
    required this.ext,
    required this.sizeBytes,
    required this.bytes,
  });

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _UploadSection extends StatefulWidget {
  final List<_UploadedFile> uploadedFiles;
  final bool picking;
  final VoidCallback onPickFiles;
  final ValueChanged<String> onRemoveFile;

  const _UploadSection({
    required this.uploadedFiles,
    required this.picking,
    required this.onPickFiles,
    required this.onRemoveFile,
  });

  @override
  State<_UploadSection> createState() => _UploadSectionState();
}

class _UploadSectionState extends State<_UploadSection> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return FormSectionCard(
      title: 'Upload Documents',
      icon: Icons.upload_file_rounded,
      iconColor: AppColors.success,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.picking ? null : widget.onPickFiles,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 100,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppColors.primarySurface
                    : AppColors.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                  color: _hovered ? AppColors.primary : AppColors.border,
                  width: _hovered ? 1.5 : 1,
                ),
              ),
              child: widget.picking
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 28,
                            color: _hovered
                                ? AppColors.primary
                                : AppColors.textSecondary),
                        const SizedBox(height: 8),
                        Text(
                          'Click to upload reports, images or documents',
                          style: TextStyle(
                            fontSize: 13,
                            color: _hovered
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'PDF · JPG · PNG  —  Max 10 MB each',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textDisabled),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (widget.uploadedFiles.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.sm),
          ...widget.uploadedFiles.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.sm, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      f.ext == 'pdf'
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                      size: 18,
                      color: f.ext == 'pdf'
                          ? AppColors.error
                          : AppColors.info,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(f.name,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(f.sizeLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                    const SizedBox(width: AppDimensions.sm),
                    GestureDetector(
                      onTap: () => widget.onRemoveFile(f.id),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.errorSurface,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSm),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final IconData icon;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: items.entries
          .map((e) =>
              DropdownMenuItem<T>(value: e.key, child: Text(e.value)))
          .toList(),
    );
  }
}
