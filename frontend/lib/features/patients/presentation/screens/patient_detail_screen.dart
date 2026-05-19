import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/entities/medical_report_entity.dart';
import '../../domain/entities/patient_entity.dart';
import '../../domain/entities/treatment_entity.dart';
import '../providers/patient_details_provider.dart';
import '../providers/patient_provider.dart';
import 'add_visit_screen.dart';
import 'patient_create_screen.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class PatientDetailScreen extends ConsumerWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (patientId == 'new') return const PatientCreateScreen();

    final async = ref.watch(patientDetailProvider(patientId));
    return async.when(
      loading: () =>
          const Scaffold(backgroundColor: AppColors.background, body: AppLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(backgroundColor: AppColors.background),
        body: AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(patientDetailProvider(patientId)),
        ),
      ),
      data: (p) => _PatientDetailView(patient: p),
    );
  }
}

// ── Main view ─────────────────────────────────────────────────────────────────

class _PatientDetailView extends ConsumerStatefulWidget {
  final PatientEntity patient;

  const _PatientDetailView({required this.patient});

  @override
  ConsumerState<_PatientDetailView> createState() =>
      _PatientDetailViewState();
}

class _PatientDetailViewState extends ConsumerState<_PatientDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    // Load persisted visits, vitals, emergency contact and reports from SQLite.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(patientDetailsProvider.notifier)
          .loadDetailsForPatient(widget.patient.id);
    });
  }

  void _openAddVisit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddVisitScreen(
          patientId: widget.patient.id,
          patientName: widget.patient.fullName,
          patientEntity: widget.patient,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(patientDetailDataProvider(widget.patient.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ───────────────────────────────────────────────
            _AppBar(patient: widget.patient),

            // ── Profile header card ───────────────────────────────────
            _ProfileCard(patient: widget.patient),

            // ── Tab bar ───────────────────────────────────────────────
            _TabRow(controller: _tabs),

            // ── Tab content ───────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ProfileTab(patient: widget.patient, details: details),
                  _ReportsTab(
                    patient: widget.patient,
                    reports: details?.reports ?? [],
                  ),
                  _TimelineTab(
                    patient: widget.patient,
                    details: details,
                    onAddVisit: () => _openAddVisit(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddVisit(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Visit',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final PatientEntity patient;

  const _AppBar({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.textPrimary),
            ),
          ),
          const Expanded(
            child: Text(
              'Patient Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08), blurRadius: 8)
              ],
            ),
            child: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ── Profile card (dark) ───────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final PatientEntity patient;

  const _ProfileCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    const avatarColors = [
      Color(0xFF6C63FF),
      Color(0xFF00C48C),
      Color(0xFF0095FF),
      Color(0xFF9C27B0),
    ];
    final avatarColor =
        avatarColors[patient.id.hashCode.abs() % avatarColors.length];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: avatarColor.withOpacity(0.25),
            child: Text(
              patient.initials,
              style: TextStyle(
                color: avatarColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),

          // Name + demographics
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${patient.age} Y · ${_genderLabel(patient.gender)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.sidebarText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  patient.phone,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.sidebarText,
                  ),
                ),
              ],
            ),
          ),

          // Patient ID badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Patient ID',
                  style: TextStyle(fontSize: 9, color: AppColors.sidebarText),
                ),
                Text(
                  patient.id.substring(0, 8).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _genderLabel(Gender g) => switch (g) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
        Gender.preferNotToSay => 'Prefer not to say',
      };
}

// ── Tab row ───────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  final TabController controller;

  const _TabRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F5FA),
      child: TabBar(
        controller: controller,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Profile'),
          Tab(text: 'Reports'),
          Tab(text: 'Visit'),
        ],
      ),
    );
  }
}

// ── PROFILE TAB ───────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final PatientEntity patient;
  final PatientDetails? details;

  const _ProfileTab({required this.patient, required this.details});

  static String _genderLabel(Gender g) => switch (g) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
        Gender.preferNotToSay => 'Prefer not to say',
      };

  @override
  Widget build(BuildContext context) {
    final treatment = details?.treatment;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        // ── Personal Information ──────────────────────────────────────
        _SectionCard(
          title: 'Personal Information',
          rows: [
            _Row('Full Name', patient.fullName),
            _Row('Date of Birth',
                DateFormat('d MMMM yyyy').format(patient.dateOfBirth)),
            _Row('Age', '${patient.age} Years'),
            _Row('Gender', _genderLabel(patient.gender)),
            _Row('Mobile Number', patient.phone),
            if (patient.email != null && patient.email!.isNotEmpty)
              _Row('Email', patient.email!),
            if (patient.address != null && patient.address!.isNotEmpty)
              _Row('Address', patient.address!),
            if (patient.bloodType != null)
              _Row('Blood Group', patient.bloodType!),
          ],
        ),
        const SizedBox(height: AppDimensions.md),

        // ── Medical Information ───────────────────────────────────────
        _SectionCard(
          title: 'Medical Information',
          rows: [
            _Row(
              'Allergies',
              patient.allergies.isEmpty
                  ? 'None'
                  : patient.allergies.join(', '),
            ),
            _Row(
              'Chronic Diseases',
              treatment?.existingConditions.isEmpty ?? true
                  ? 'None'
                  : treatment!.existingConditions.join(', '),
            ),
            if (details?.emergencyContact != null) ...[
              _Row(
                'Emergency Contact',
                '${details!.emergencyContact!.name ?? '—'}'
                '${details!.emergencyContact!.relationship != null ? ' (${details!.emergencyContact!.relationship})' : ''}'
                '\n${details!.emergencyContact!.phone ?? ''}',
              ),
            ],
          ],
        ),
        const SizedBox(height: AppDimensions.md),

        // ── Vitals (if recorded) ──────────────────────────────────────
        if (details?.vitals != null) ...[
          _SectionCard(
            title: 'Patient Vitals',
            rows: [
              if (details!.vitals!.weightKg != null)
                _Row('Weight',
                    '${details!.vitals!.weightKg!.toStringAsFixed(1)} kg'),
              if (details!.vitals!.bloodPressure != null)
                _Row('Blood Pressure', details!.vitals!.bloodPressure!),
              if (details!.vitals!.temperature != null)
                _Row('Temperature',
                    '${details!.vitals!.temperature!.toStringAsFixed(1)} °C'),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
        ],

        // ── Treatment (if recorded) ───────────────────────────────────
        if (details?.treatment != null) ...[
          _SectionCard(
            title: 'Treatment Information',
            rows: [
              _Row('Chief Complaint',
                  details!.treatment!.chiefComplaint),
              if (details!.treatment!.diagnosis != null)
                _Row('Diagnosis', details!.treatment!.diagnosis!),
              if (details!.treatment!.doctorAssigned != null)
                _Row('Doctor', details!.treatment!.doctorAssigned!),
              if (details!.treatment!.medications.isNotEmpty)
                _Row('Medications',
                    details!.treatment!.medications.join('\n')),
              if (details!.treatment!.visitType != null)
                _Row('Visit Type', details!.treatment!.visitType.label),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
        ],

        const SizedBox(height: 80), // FAB clearance
      ],
    );
  }
}


// ── REPORTS TAB ───────────────────────────────────────────────────────────────

class _ReportsTab extends ConsumerStatefulWidget {
  final PatientEntity patient;
  final List<MedicalReportEntity> reports;

  const _ReportsTab({required this.patient, required this.reports});

  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  int _filterIndex = 0;
  static const _filters = ['All', 'Images', 'PDF', 'Lab Reports'];

  List<MedicalReportEntity> get _filtered {
    if (_filterIndex == 0) return widget.reports;
    if (_filterIndex == 1) return widget.reports.where((r) => r.isImage).toList();
    if (_filterIndex == 2) return widget.reports.where((r) => !r.isImage).toList();
    return widget.reports.where((r) => r.reportType == ReportType.labReport).toList();
  }

  Future<void> _uploadReport(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !mounted) return;
    final reports = <MedicalReportEntity>[];
    for (final f in result.files) {
      if (f.bytes == null) continue;
      reports.add(MedicalReportEntity(
        id: const Uuid().v4(),
        patientId: widget.patient.id,
        fileName: f.name,
        extension: (f.extension ?? 'bin').toLowerCase(),
        reportType: ReportType.medicalReport,
        fileSizeBytes: f.size,
        bytes: f.bytes!,
        uploadedAt: DateTime.now(),
      ));
    }
    if (reports.isNotEmpty) {
      ref.read(patientDetailsProvider.notifier)
          .saveReports(widget.patient.id, reports);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${reports.length} file(s) uploaded.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayReports = _filtered;

    return Column(
      children: [
        // Filter chips
        Container(
          height: 44,
          color: const Color(0xFFF4F5FA),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: 6),
            itemCount: _filters.length,
            itemBuilder: (_, i) {
              final selected = _filterIndex == i;
              return Padding(
                padding: const EdgeInsets.only(right: AppDimensions.sm),
                child: GestureDetector(
                  onTap: () => setState(() => _filterIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(
                          AppDimensions.radiusRound),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      _filters[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Report list
        Expanded(
          child: displayReports.isEmpty
              ? _EmptyState(
                  icon: Icons.folder_open_outlined,
                  message: _filterIndex == 0
                      ? 'No reports uploaded yet'
                      : 'No ${_filters[_filterIndex].toLowerCase()} found',
                  hint: 'Tap "Upload Report" to add a file',
                )
              : ListView(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  children: [
                    ...displayReports.map((r) => _ReportTile(report: r)),
                    const SizedBox(height: 80),
                  ],
                ),
        ),

        // Upload button
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _uploadReport(context, ref),
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Upload Report',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusLg),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class _ReportTile extends StatelessWidget {
  final MedicalReportEntity report;

  const _ReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: report.isImage
                  ? AppColors.info.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(
              report.isImage
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_rounded,
              color: report.isImage ? AppColors.info : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateFormat('d MMM yyyy').format(report.uploadedAt)}  ·  '
                  '${report.extension.toUpperCase()}  ·  ${report.sizeLabel}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded,
                size: 18, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── VISIT TAB (formerly Timeline) ─────────────────────────────────────────────

class _TimelineTab extends StatelessWidget {
  final PatientDetails? details;
  final PatientEntity patient;
  final VoidCallback onAddVisit;

  const _TimelineTab({
    required this.patient,
    required this.details,
    required this.onAddVisit,
  });

  @override
  Widget build(BuildContext context) {
    final visits = (details?.visits ?? []).reversed.toList();

    return Column(
      children: [
        Expanded(
          child: visits.isEmpty
              ? _EmptyState(
                  icon: Icons.timeline_outlined,
                  message: 'No visits recorded yet',
                  hint: 'Tap "Add Visit" to record the first visit',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  itemCount: visits.length,
                  itemBuilder: (_, i) => _TimelineItem(
                    visit: visits[i],
                    patient: patient,
                    isLast: i == visits.length - 1,
                  ),
                ),
        ),
        _AddVisitButton(onTap: onAddVisit),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final TreatmentEntity visit;
  final PatientEntity patient;
  final bool isLast;

  const _TimelineItem({
    required this.visit,
    required this.patient,
    required this.isLast,
  });

  Color _visitTypeColor(VisitType t) => switch (t) {
        VisitType.newVisit => AppColors.primary,
        VisitType.followUp => AppColors.success,
        VisitType.emergency => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final date = visit.appointmentDateTime ?? patient.createdAt;
    final title = visit.chiefComplaint.isNotEmpty
        ? visit.chiefComplaint
        : visit.diagnosis ?? 'Visit';
    final subtitle = visit.medications.isEmpty
        ? (visit.diagnosis ?? (visit.notes ?? ''))
        : visit.medications.join(', ');
    final typeColor = _visitTypeColor(visit.visitType);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column: dot + line
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: typeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),

          // Event content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: isLast ? 0 : AppDimensions.md),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date + visit type badge
                          Row(
                            children: [
                              Text(
                                DateFormat('d MMM yyyy').format(date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusRound),
                                ),
                                child: Text(
                                  visit.visitType.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (visit.doctorAssigned != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              visit.doctorAssigned!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AddVisitScreen(
                            patientId: patient.id,
                            patientName: patient.fullName,
                            patientEntity: patient,
                            existingVisit: visit,
                            readOnly: true,
                          ),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared utility widgets ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddVisitButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddVisitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add New Visit',
              style: TextStyle(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusLg),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared card widgets ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> rows;

  const _SectionCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.md, AppDimensions.md,
                AppDimensions.md, AppDimensions.sm),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...rows,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
