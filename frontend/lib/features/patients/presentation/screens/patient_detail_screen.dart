import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/patient_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../photos/domain/entities/photo_entity.dart';
import '../../../photos/presentation/widgets/photo_gallery_widget.dart';
import '../../../photos/presentation/providers/photo_provider.dart';
import '../../../print_configuration/presentation/providers/print_config_provider.dart';
import '../../../surgeries/domain/entities/surgery_entity.dart';
import '../../../surgeries/presentation/providers/surgery_provider.dart';
import '../../../visits/domain/entities/visit_entity.dart';
import '../../../visits/presentation/providers/visit_provider.dart';
import '../providers/patient_provider.dart';
import '../../../audit/audit_provider.dart';
import 'package:medical_patient_management/core/theme/theme_extensions.dart';
import 'package:medical_patient_management/core/widgets/sync_status_badge.dart';

// ── Fixed accent colours (same in both modes) ─────────────────────────────────
const _kAccent = Color(0xFF4B55CC);
const _kRed    = Color(0xFF8A4430);

// ── Print data builder ────────────────────────────────────────────────────────
Map<String, String> _buildVisitPrintMap(
    PatientEntity patient, VisitEntity visit,
    {List<PhotoEntity> photos = const []}) {
  Map<String, String> pNotes = {};
  if (patient.notes?.isNotEmpty == true) {
    try {
      pNotes = (jsonDecode(patient.notes!) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {}
  }
  Map<String, String> exam = {};
  if (visit.examination?.isNotEmpty == true) {
    try {
      exam = (jsonDecode(visit.examination!) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {}
  }
  // Rebuild medications from structured prescriptions JSON (covers existing data)
  if (exam.containsKey('prescriptions')) {
    try {
      final presJson = jsonDecode(exam['prescriptions']!) as List;
      final rebuilt = presJson.map((p) {
        final m = p as Map<String, dynamic>;
        final medicine           = m['medicine']           as String? ?? '';
        final dose               = m['dose']               as String? ?? '';
        final route              = m['route']              as String? ?? '';
        final frequency          = m['frequency']          as String? ?? '';
        final duration           = m['duration']           as String? ?? '';
        final specialInstruction = m['specialInstruction'] as String? ?? '';
        return '$medicine${dose.isNotEmpty ? " [$dose]" : ""}${route.isNotEmpty ? " ($route)" : ""}${frequency.isNotEmpty ? " - $frequency" : ""}${duration.isNotEmpty ? " × $duration" : ""}${specialInstruction.isNotEmpty ? " | $specialInstruction" : ""}';
      }).where((l) => l.isNotEmpty).join('\n');
      if (rebuilt.isNotEmpty) exam['medications'] = rebuilt;
    } catch (_) {}
  }
  String pn(String k) => pNotes[k]?.isNotEmpty == true ? pNotes[k]! : '';
  String ex(String k) => exam[k]?.isNotEmpty == true ? exam[k]! : '';
  // Prefer visit entity field, fall back to examination blob, then patient notes.
  String vex(String? visitField, String examKey) =>
      (visitField?.isNotEmpty == true) ? visitField! : ex(examKey);
  final dob = patient.dateOfBirth != null
      ? DateFormat('dd MMMM yyyy').format(patient.dateOfBirth!) : '—';
  final gender = patient.sex?.isNotEmpty == true
      ? '${patient.sex![0].toUpperCase()}${patient.sex!.substring(1)}' : '—';
  final ageStr = patient.computedAge > 0 ? '${patient.computedAge} yrs' : '—';
  return {
    'firstName':       patient.firstName,
    'lastName':        patient.lastName.isEmpty ? '—' : patient.lastName,
    'date':            DateFormat('dd/MM/yyyy').format(visit.visitDate),
    'age':             ageStr,
    'dob':             dob,
    'gender':          gender,
    'prn':             patient.prn,
    'phone':           patient.phone ?? '',
    'altPhone':        patient.altPhone ?? pn('altPhone'),
    'email':           patient.email ?? pn('email'),
    'address':         patient.address ?? '',
    'idProofType':     patient.idProofType ?? pn('idProofType'),
    'idProofNumber':   patient.idProofNumber ?? pn('idProofNumber'),
    'allergies':       patient.allergies ?? pn('allergies'),
    'medicalHistory':  patient.medicalHistory ?? pn('medicalHistory'),
    'weight':          _pick(vex(visit.weight, 'weight'),       _pick(patient.weight, pn('weight'))),
    'bloodPressure':   _pick(vex(visit.bp, 'bp'),               _pick(patient.bloodPressure, pn('bloodPressure'))),
    'temperature':     _pick(vex(visit.temperature, 'temperature'), _pick(patient.temperature, pn('temperature'))),
    'previousHistory':    _pick(ex('previousHistory'),    _pick(patient.previousHistory, pn('previousHistory'))),
    'chiefComplaint':     _pick(visit.complaints,          pn('chiefComplaint')),
    'examGeneral':        _pick(ex('examGeneral'),         pn('examGeneral')),
    'examNeurological':   _pick(ex('examNeurological'),    pn('examNeurological')),
    'clinicalDiagnosis':  _pick(ex('clinicalDiagnosis'),   pn('clinicalDiagnosis')),
    'imaging':            _pick(ex('imaging'),             pn('imaging')),
    'otherInvestigation': _pick(ex('otherInvestigation'),  pn('otherInvestigation')),
    'diagnosis':          _pick(visit.clinicalImpression,  pn('diagnosis')),
    'treatmentPlan':      _pick(visit.plan,                pn('treatmentPlan')),
    'medications':        _pick(vex(ex('medications'), 'medications'), pn('medications')),
    'crossConsultation':  _pick(ex('crossConsultation'),    pn('crossConsultation')),
    'advice':             _pick(ex('advice'),              pn('advice')),
    'visitType':          visit.visitType.label,
  }..removeWhere((_, v) => v.isEmpty);
}

String _pick(String? a, String b) => (a?.isNotEmpty == true) ? a! : b;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class PatientDashboardScreen extends ConsumerStatefulWidget {
  final String patientId;
  const PatientDashboardScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends ConsumerState<PatientDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(visitsProvider(widget.patientId).notifier).refresh();
      ref.read(surgeriesProvider(widget.patientId).notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientId      = widget.patientId;
    final patientAsync   = ref.watch(patientByIdProvider(patientId));
    final visits         = ref.watch(visitsProvider(patientId));
    final surgeries      = ref.watch(surgeriesProvider(patientId));
    final allPhotos      = ref.watch(photoProvider(patientId)).photos;
    final canWrite       = ref.watch(canWriteProvider);
    final canEditPatient = ref.watch(canEditPatientProvider);

    return patientAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.bgColor,
        body: const Center(child: CircularProgressIndicator(color: _kAccent)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (patient) {
        if (patient == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Patient not found')),
          );
        }

        final sortedVisits = visits.toList()
          ..sort((a, b) => b.visitDate.compareTo(a.visitDate));

        final timeline = <_TimelineItem>[
          ...sortedVisits.map((v) => _TimelineItem.fromVisit(v)),
          ...surgeries.map((s) => _TimelineItem.fromSurgery(s)),
        ]..sort((a, b) => b.date.compareTo(a.date));

        return Scaffold(
          backgroundColor: context.bgColor,
          appBar: _TimelineAppBar(
            patientId: patientId,
            onFilter: () {},
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _PatientHeaderCard(
                patient: patient,
                canEditPatient: canEditPatient,
                onEditPatient: canEditPatient ? () async {
                  await context.push('/patients/$patientId/edit');
                  ref.invalidate(patientByIdProvider(patientId));
                } : null,
                onDeletePatient: canWrite
                    ? () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Patient'),
                            content: const Text(
                                'Are you sure you want to delete this patient? All associated visits and surgeries will also be deleted. This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444)),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await ref
                              .read(patientsProvider.notifier)
                              .deletePatient(patientId);
                          if (context.mounted) context.go('/patients');
                        }
                      }
                    : null,
              ),
            ),

            _PatientReportsSection(
              patientId: patientId,
              allPhotos: allPhotos,
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => Future.wait([
                  ref.read(visitsProvider(patientId).notifier).refresh(),
                  ref.read(surgeriesProvider(patientId).notifier).refresh(),
                ]),
                child: timeline.isEmpty
                  ? LayoutBuilder(builder: (ctx, c) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(height: c.maxHeight, child: _EmptyTimeline()),
                    ))
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: timeline.length,
                      itemBuilder: (ctx, i) {
                        return _TimelineRow(
                          item: timeline[i],
                          patient: patient,
                          isLast: i == timeline.length - 1,
                          initiallyExpanded: i == 0,
                          canWrite: canWrite,
                          photos: allPhotos
                              .where((p) =>
                                  p.visitId == timeline[i].id ||
                                  p.surgeryId == timeline[i].id)
                              .toList(),
                          onDocTap: () {
                            if (timeline[i].type == 'visit') {
                              context.push(
                                  '/patients/$patientId/visits/${timeline[i].id}/view');
                            } else {
                              context.push(
                                  '/patients/$patientId/surgeries/${timeline[i].id}');
                            }
                          },
                          onEditTap: canWrite && timeline[i].type == 'visit'
                              ? () => context.push(
                                  '/patients/$patientId/visits/${timeline[i].id}')
                              : null,
                          onDelete: canWrite && timeline[i].type == 'visit'
                              ? () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Visit'),
                                      content: const Text(
                                          'Are you sure you want to delete this visit entry? This cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                              foregroundColor: const Color(0xFFEF4444)),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && context.mounted) {
                                    await ref
                                        .read(visitsProvider(patientId).notifier)
                                        .deleteVisit(timeline[i].id);
                                  }
                                }
                              : null,
                          onPrint: timeline[i].visit != null
                              ? () {
                                  final visitPhotos = allPhotos
                                      .where((p) =>
                                          p.visitId == timeline[i].id)
                                      .toList();
                                  ref
                                      .read(activePatientDataProvider.notifier)
                                      .state = _buildVisitPrintMap(
                                          patient, timeline[i].visit!,
                                          photos: visitPhotos);
                                  context.push('/print-config');
                                }
                              : null,
                        );
                      },
                    ),
              ),
            ),
          ]),

          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: canWrite
              ? _AddVisitBar(
                  patientId: patientId,
                  onTap: () => context.push('/patients/$patientId/new-visit'),
                )
              : null,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline item data class
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineItem {
  final String id;
  final String type;
  final DateTime date;
  final String title;
  final String subtitle;
  final bool isDraft;
  final String syncStatus;
  final VisitEntity? visit;

  const _TimelineItem({
    required this.id,
    required this.type,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.isDraft,
    this.syncStatus = 'synced',
    this.visit,
  });

  factory _TimelineItem.fromVisit(VisitEntity v) {
    final title = v.clinicalImpression?.trim().isNotEmpty == true
        ? v.clinicalImpression!
        : v.complaints?.trim().isNotEmpty == true
            ? v.complaints!
            : 'OPD Visit';

    String meds = '';
    if (v.examination?.isNotEmpty == true) {
      try {
        final m = jsonDecode(v.examination!) as Map<String, dynamic>;
        meds = (m['medications'] as String?) ?? '';
      } catch (_) {}
    }

    return _TimelineItem(
      id:         v.id,
      type:       'visit',
      date:       v.visitDate,
      title:      title,
      subtitle:   meds,
      isDraft:    v.isDraft,
      syncStatus: v.syncStatus,
      visit:      v,
    );
  }

  factory _TimelineItem.fromSurgery(SurgeryEntity s) => _TimelineItem(
    id:         s.id,
    type:       'surgery',
    date:       s.surgeryDate,
    title:      s.procedure ?? 'Surgery',
    subtitle:   s.preOpDiagnosis ?? '',
    isDraft:    s.status == 'draft',
    syncStatus: s.syncStatus,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String patientId;
  final VoidCallback onFilter;
  const _TimelineAppBar({required this.patientId, required this.onFilter});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: context.bgColor,
    elevation: 0,
    surfaceTintColor: context.bgColor,
    centerTitle: false,
    leading: IconButton(
      icon: Icon(Icons.arrow_back_ios_new, size: 18, color: context.textPrimary),
      onPressed: () => context.go('/patients'),
    ),
    title: Text(
      'Patient Profile',
      style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
          letterSpacing: -0.2),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: context.borderColor),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient header card — compact, view-only
// ─────────────────────────────────────────────────────────────────────────────
class _PatientHeaderCard extends StatelessWidget {
  final PatientEntity patient;
  final bool canEditPatient;
  final VoidCallback? onEditPatient;
  final VoidCallback? onDeletePatient;
  const _PatientHeaderCard({required this.patient, this.canEditPatient = false, this.onEditPatient, this.onDeletePatient});

  @override
  Widget build(BuildContext context) {
    final age    = patient.computedAge > 0 ? '${patient.computedAge} yrs' : null;
    final gender = patient.sex?.isNotEmpty == true
        ? (patient.sex!.toLowerCase().startsWith('m') ? 'Male'
           : patient.sex!.toLowerCase().startsWith('f') ? 'Female'
           : patient.sex!)
        : null;
    final dob = patient.dateOfBirth != null
        ? DateFormat('dd MMM yyyy').format(patient.dateOfBirth!)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Compact initials circle
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                patient.initials.isEmpty ? '?' : patient.initials,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: _kAccent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + ID + phone + demography
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: context.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    'ID: ${patient.prn}',
                    if (patient.phone?.isNotEmpty == true) patient.phone!,
                  ].join('  ·  '),
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                if (age != null || gender != null || dob != null) ...[
                  const SizedBox(height: 5),
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    if (gender != null) _DemoBadge(gender,
                        gender == 'Male' ? Icons.male_rounded : Icons.female_rounded),
                    if (age != null) _DemoBadge(age, Icons.cake_outlined),
                    if (dob != null) _DemoBadge(dob, Icons.calendar_today_outlined),
                  ]),
                ],
              ],
            ),
          ),
          // Edit button (admin only)
          if (onEditPatient != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEditPatient,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_outlined,
                    color: _kAccent, size: 17),
              ),
            ),
          ],
          // Delete button
          if (onDeletePatient != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDeletePatient,
              child: Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEB), shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFE53935), size: 18),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _DemoBadge(this.label, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _kAccent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: _kAccent),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: _kAccent)),
        ]),
      );
}

class _HeaderInfoCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _HeaderInfoCell({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: _kAccent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: context.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: context.textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Single timeline row
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineRow extends ConsumerStatefulWidget {
  final _TimelineItem item;
  final PatientEntity patient;
  final bool isLast;
  final bool canWrite;
  final List<PhotoEntity> photos;
  final VoidCallback onDocTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onPrint;
  final VoidCallback? onDelete;
  final bool initiallyExpanded;
  const _TimelineRow({
    required this.item,
    required this.patient,
    required this.isLast,
    required this.canWrite,
    required this.photos,
    required this.onDocTap,
    this.onEditTap,
    this.onPrint,
    this.onDelete,
    this.initiallyExpanded = false,
  });

  @override
  ConsumerState<_TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends ConsumerState<_TimelineRow> {
  late bool _expanded;
  bool _showMeds = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  _TimelineItem get item => widget.item;
  List<PhotoEntity> get photos => widget.photos;

  void _showAuditSheet(BuildContext context, String visitId, String patientId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuditBottomSheet(
        visitId: visitId,
        patientId: patientId,
        title: 'Edit History',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = item.type == 'visit' ? _kAccent : _kRed;

    final examMap = <String, String>{};
    if (item.visit?.examination?.isNotEmpty == true) {
      try {
        (jsonDecode(item.visit!.examination!) as Map<String, dynamic>)
            .forEach((k, v) {
          if (v is String && v.isNotEmpty) examMap[k] = v;
        });
      } catch (_) {}
    }
    if (examMap.containsKey('prescriptions')) {
      try {
        final presJson = jsonDecode(examMap['prescriptions']!) as List;
        final rebuilt = presJson.map((p) {
          final m = p as Map<String, dynamic>;
          final medicine           = m['medicine']           as String? ?? '';
          final dose               = m['dose']               as String? ?? '';
          final route              = m['route']              as String? ?? '';
          final frequency          = m['frequency']          as String? ?? '';
          final duration           = m['duration']           as String? ?? '';
          final specialInstruction = m['specialInstruction'] as String? ?? '';
          return '$medicine${dose.isNotEmpty ? " [$dose]" : ""}${route.isNotEmpty ? " ($route)" : ""}${frequency.isNotEmpty ? " - $frequency" : ""}${duration.isNotEmpty ? " × $duration" : ""}${specialInstruction.isNotEmpty ? " | $specialInstruction" : ""}';
        }).where((l) => l.isNotEmpty).join('\n');
        if (rebuilt.isNotEmpty) examMap['medications'] = rebuilt;
      } catch (_) {}
    }
    String ex(String k) => examMap[k] ?? '';

    final dataRows = <({String label, String value, IconData icon})>[];
    void add(String label, String val, IconData icon) {
      if (val.trim().isNotEmpty) dataRows.add((label: label, value: val.trim(), icon: icon));
    }

    if (item.visit != null) {
      add('Chief Complaint',          item.visit!.complaints ?? '',         Icons.description_outlined);
      add('Previous History',         ex('previousHistory'),                Icons.history_edu_outlined);
      add('General Examination',      ex('examGeneral'),                    Icons.search_outlined);
      add('Neurological Examination', ex('examNeurological'),               Icons.psychology_outlined);
      add('Imaging',                  ex('imaging'),                        Icons.image_outlined);
      add('Other Investigation',      ex('otherInvestigation'),             Icons.science_outlined);
      add('Impression',               item.visit!.clinicalImpression ?? '', Icons.lightbulb_outline);
      add('Treatment Plan',           item.visit!.plan ?? '',               Icons.map_outlined);
      add('Advice',                   ex('advice'),                         Icons.chat_bubble_outline_rounded);
      add('Notes',                    item.visit!.notes ?? '',              Icons.lock_outline_rounded);
    } else {
      add('Procedure',        item.title,    Icons.medical_services_outlined);
      add('Pre-op Diagnosis', item.subtitle, Icons.assignment_outlined);
    }

    final bp   = (item.visit?.bp?.isNotEmpty == true)     ? item.visit!.bp!          : ex('bp');
    final wt   = (item.visit?.weight?.isNotEmpty == true)  ? item.visit!.weight!      : ex('weight');
    final temp = (item.visit?.temperature?.isNotEmpty == true) ? item.visit!.temperature! : ex('temperature');
    final hasVitals = bp.isNotEmpty || wt.isNotEmpty || temp.isNotEmpty;

    final medsRaw   = ex('medications');
    final hasMeds   = medsRaw.isNotEmpty;
    final medsCount = hasMeds
        ? medsRaw.split('\n').where((l) => l.trim().isNotEmpty).length
        : 0;

    // Summary line: impression or complaint (first 80 chars)
    final summaryLine = item.visit != null
        ? (item.visit!.clinicalImpression?.trim().isNotEmpty == true
            ? item.visit!.clinicalImpression!.trim()
            : item.visit!.complaints?.trim() ?? '')
        : item.subtitle.trim();

    final hasDetails = hasMeds;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10, offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Coloured header band ────────────────────────────────────
            Container(
              color: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(
                  item.type == 'visit'
                      ? Icons.event_note_outlined
                      : Icons.medical_services_outlined,
                  size: 15, color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd MMM yyyy').format(item.date),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.type == 'visit'
                        ? (item.visit?.visitType.label ?? 'OPD Visit')
                        : 'Surgery',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                const Spacer(),
                SyncStatusBadge(syncStatus: item.syncStatus),
              ]),
            ),

            const SizedBox(height: 10),
            Divider(height: 1, color: context.borderColor),

            // ── Action buttons ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(children: [
                _CardBtn(
                  icon: Icons.remove_red_eye_outlined,
                  label: 'View',
                  color: accentColor,
                  onTap: widget.onDocTap,
                ),
                if (widget.onPrint != null)
                  _CardBtn(
                    icon: Icons.print_outlined,
                    label: 'Print',
                    color: accentColor,
                    onTap: widget.onPrint!,
                  ),
                if (widget.canWrite) ...[
                  _CardBtn(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: accentColor,
                    onTap: widget.onEditTap ?? widget.onDocTap,
                  ),
                  if (widget.onDelete != null)
                    _CardBtn(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: const Color(0xFFEF4444),
                      onTap: widget.onDelete!,
                    ),
                ],
                // History button — only for server-synced visits with a numeric id
                if (item.visit != null &&
                    item.visit!.id.isNotEmpty &&
                    RegExp(r'^\d+$').hasMatch(item.visit!.id))
                  _CardBtn(
                    icon: Icons.history_rounded,
                    label: 'History',
                    color: const Color(0xFF6B7280),
                    onTap: () => _showAuditSheet(context, item.visit!.id, widget.patient.id),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card view helpers ─────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

class _CardBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardBtn({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );
}

// ── Unused legacy chips (kept for reference) ──────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      );
}

class _VitalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _VitalChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: context.textDisabled),
          const SizedBox(width: 4),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 11, color: context.textDisabled, fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 11, color: context.textPrimary, fontWeight: FontWeight.w700)),
        ]),
      );
}

// ── Action button (View / Print / Edit) in visit card header ─────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );
}

// ── Section list row inside an expanded visit card ───────────────────────────
class _SectionRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final bool isLast;
  final Widget? trailingWidget;
  const _SectionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.isLast = false,
    this.trailingWidget,
  });

  @override
  State<_SectionRow> createState() => _SectionRowState();
}

class _SectionRowState extends State<_SectionRow> {
  bool _expanded = false;

  // Text longer than ~70 chars OR with more than 2 newlines needs expand/collapse.
  bool get _isLong => widget.value.length > 70 || widget.value.split('\n').length > 2;
  bool get _canExpand => widget.trailingWidget == null && _isLong;

  @override
  Widget build(BuildContext context) {
    final cross = (_expanded && _canExpand)
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;

    return GestureDetector(
      onTap: _canExpand ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: widget.isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color: context.borderColor.withValues(alpha: 0.6))),
        ),
        child: Row(
          crossAxisAlignment: cross,
          children: [
            Padding(
              padding: (_expanded && _canExpand)
                  ? const EdgeInsets.only(top: 2)
                  : EdgeInsets.zero,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(widget.icon, size: 17, color: widget.iconColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary)),
                  if (widget.value.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topLeft,
                      child: Text(
                        widget.value,
                        style: TextStyle(
                            fontSize: 12, color: context.textSecondary),
                        maxLines: _expanded ? null : 2,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailingWidget != null) ...[
              const SizedBox(width: 8),
              widget.trailingWidget!,
            ],
            const SizedBox(width: 6),
            Icon(
              _canExpand
                  ? (_expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded)
                  : Icons.chevron_right_rounded,
              size: 18,
              color: context.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: context.textDisabled, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 12, color: context.textPrimary, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _DateStack extends StatelessWidget {
  final DateTime date;
  final Color accentColor;
  const _DateStack({required this.date, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final day   = date.day.toString().padLeft(2, '0');
    final month = _monthAbbr(date.month);
    final year  = date.year.toString();
    final hour  = date.hour.toString().padLeft(2, '0');
    final min   = date.minute.toString().padLeft(2, '0');
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(day,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: accentColor,
                  height: 1.0)),
          Text(month,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: accentColor.withValues(alpha: 0.8), height: 1.2)),
          Text(year,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w500,
                  color: context.textDisabled, height: 1.2)),
          const SizedBox(height: 3),
          Container(width: 28, height: 1, color: accentColor.withValues(alpha: 0.2)),
          const SizedBox(height: 3),
          Text('$hour:$min',
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: context.textDisabled, height: 1.0)),
        ],
      ),
    );
  }

  static String _monthAbbr(int m) {
    const abbrs = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return m >= 1 && m <= 12 ? abbrs[m] : '---';
  }
}

class _FieldGrid extends StatelessWidget {
  final List<({String label, String value})> rows;
  const _FieldGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rows.map((r) {
        return Container(
          width: (MediaQuery.of(context).size.width - 80) / 2,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: context.bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.label,
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w600,
                    color: context.textDisabled,
                    letterSpacing: 0.3)),
            const SizedBox(height: 3),
            Text(r.value,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: context.textPrimary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Medicines table widget ────────────────────────────────────────────────────
class _ParsedMed {
  final String medicine;
  final String dose;
  final String route;
  final String frequency;
  final String duration;
  final String specialInstruction;
  const _ParsedMed({required this.medicine, required this.dose, required this.route, required this.frequency, required this.duration, this.specialInstruction = ''});
}

List<_ParsedMed> _parseMeds(String raw) {
  return raw.split('\n').where((l) => l.trim().isNotEmpty).map((line) {
    // Extract special instruction (anything after last " | ")
    final pipeIdx = line.lastIndexOf(' | ');
    final lineMain = pipeIdx >= 0 ? line.substring(0, pipeIdx).trim() : line;
    final specialInstruction = pipeIdx >= 0 ? line.substring(pipeIdx + 3).trim() : '';
    // Extract dose from [dose]
    final doseMatch  = RegExp(r'\[([^\]]+)\]').firstMatch(lineMain);
    final dose       = doseMatch?.group(1) ?? '';
    final withoutDose = lineMain.replaceFirst(doseMatch?.group(0) ?? '', '').trim();
    // Extract route from (route)
    final routeMatch  = RegExp(r'\(([^)]+)\)').firstMatch(withoutDose);
    final route       = routeMatch?.group(1) ?? '';
    final withoutRoute = withoutDose.replaceFirst(routeMatch?.group(0) ?? '', '').trim();
    // Split on " - " for frequency/duration
    final dashIdx   = withoutRoute.indexOf(' - ');
    final medicine  = dashIdx >= 0 ? withoutRoute.substring(0, dashIdx).trim() : withoutRoute;
    final right     = dashIdx >= 0 ? withoutRoute.substring(dashIdx + 3).trim() : '';
    final mulIdx    = right.indexOf(' × ');
    final frequency = mulIdx >= 0 ? right.substring(0, mulIdx).trim() : right;
    final duration  = mulIdx >= 0 ? right.substring(mulIdx + 3).trim() : '';
    return _ParsedMed(medicine: medicine, dose: dose, route: route, frequency: frequency, duration: duration, specialInstruction: specialInstruction);
  }).toList();
}

class _MedicinesTable extends StatelessWidget {
  final String raw;
  const _MedicinesTable({required this.raw});

  @override
  Widget build(BuildContext context) {
    final meds = _parseMeds(raw);
    if (meds.isEmpty) return const SizedBox.shrink();

    const cols = ['Medicine', 'Dose', 'Route', 'Freq', 'Duration'];
    const weights = [3, 2, 2, 2, 2];

    Widget headerCell(String t) => Expanded(
          flex: weights[cols.indexOf(t)],
          child: Text(t,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: context.textDisabled, letterSpacing: 0.3)),
        );

    Widget dataCell(String t, int flex) => Expanded(
          flex: flex,
          child: Text(t.isEmpty ? '—' : t,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: context.textPrimary)),
        );

    return Container(
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: context.borderColor.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.medication_outlined, size: 12, color: context.textDisabled),
              ),
              Text('Treatment / Medicines',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: context.textDisabled, letterSpacing: 0.3)),
            ]),
          ),
          // Column headers
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
            child: Row(children: cols.map(headerCell).toList()),
          ),
          Divider(height: 1, thickness: 1, color: context.borderColor),
          // Rows
          ...meds.asMap().entries.map((e) {
            final m = e.value;
            final isLast = e.key == meds.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        dataCell(m.medicine,  weights[0]),
                        dataCell(m.dose,      weights[1]),
                        dataCell(m.route,     weights[2]),
                        dataCell(m.frequency, weights[3]),
                        dataCell(m.duration,  weights[4]),
                      ]),
                      if (m.specialInstruction.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(children: [
                            Icon(Icons.info_outline_rounded,
                                size: 10, color: const Color(0xFFD4A855)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(m.specialInstruction,
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFFD4A855),
                                    fontStyle: FontStyle.italic))),
                          ]),
                        ),
                    ],
                  ),
                ),
                if (!isLast) Divider(height: 1, thickness: 1, color: context.borderColor),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared attachment helpers
// ─────────────────────────────────────────────────────────────────────────────
String _attachFilename(PhotoEntity p) {
  if (p.caption?.isNotEmpty == true) return p.caption!;
  final parts = p.storagePath.split('/');
  return parts.isNotEmpty ? parts.last : 'Attachment';
}

String _attachTypeLabel(PhotoEntity p) {
  final s = _attachFilename(p).toLowerCase();
  if (s.endsWith('.pdf'))  return 'PDF';
  if (s.endsWith('.png') || s.endsWith('.jpg') ||
      s.endsWith('.jpeg') || s.endsWith('.webp')) return 'Image';
  if (s.endsWith('.xls') || s.endsWith('.xlsx')) return 'Excel';
  if (s.endsWith('.doc') || s.endsWith('.docx')) return 'Word';
  return 'File';
}

Color _attachIconBg(PhotoEntity p) {
  final t = _attachTypeLabel(p);
  if (t == 'PDF')   return const Color(0xFFEF4444);
  if (t == 'Image') return const Color(0xFF4B55CC);
  if (t == 'Excel') return const Color(0xFF16A34A);
  if (t == 'Word')  return const Color(0xFF2563EB);
  return const Color(0xFF6E6A63);
}

IconData _attachIconData(PhotoEntity p) {
  final t = _attachTypeLabel(p);
  if (t == 'PDF')   return Icons.picture_as_pdf_rounded;
  if (t == 'Image') return Icons.image_rounded;
  if (t == 'Excel') return Icons.table_chart_rounded;
  if (t == 'Word')  return Icons.description_rounded;
  return Icons.insert_drive_file_rounded;
}

bool _isImageFile(PhotoEntity p) {
  final s = _attachFilename(p).toLowerCase();
  if (s.endsWith('.jpg') || s.endsWith('.jpeg') ||
      s.endsWith('.png') || s.endsWith('.webp') || s.endsWith('.gif')) {
    return true;
  }
  if (p.localPath != null) {
    final lp = p.localPath!.toLowerCase();
    return lp.endsWith('.jpg') || lp.endsWith('.jpeg') ||
        lp.endsWith('.png') || lp.endsWith('.webp') || lp.endsWith('.gif');
  }
  return p.url?.contains('res.cloudinary.com') == true &&
      !s.endsWith('.pdf') && !s.endsWith('.doc') &&
      !s.endsWith('.docx') && !s.endsWith('.xls') && !s.endsWith('.xlsx');
}

Future<void> _openAttachment(PhotoEntity p) async {
  if (p.url != null && p.url!.isNotEmpty) {
    try {
      final ok = await launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication);
      if (!ok) await launchUrl(Uri.parse(p.url!), mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      try { await launchUrl(Uri.parse(p.url!), mode: LaunchMode.inAppBrowserView); } catch (_) {}
    }
  } else if (p.localPath != null) {
    try {
      await launchUrl(Uri.file(p.localPath!), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

Future<void> _downloadAttachment(BuildContext ctx, PhotoEntity p) async {
  if (p.url == null || p.url!.isEmpty) {
    if (p.localPath != null) {
      await Share.shareXFiles([XFile(p.localPath!)], text: _attachFilename(p));
    }
    return;
  }

  final messenger = ScaffoldMessenger.of(ctx);
  messenger.showSnackBar(SnackBar(
    content: Row(children: [
      const SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
      const SizedBox(width: 12),
      const Text('Downloading…', style: TextStyle(fontWeight: FontWeight.w600)),
    ]),
    duration: const Duration(seconds: 60),
    backgroundColor: const Color(0xFF4B55CC),
    behavior: SnackBarBehavior.floating,
  ));

  try {
    // Save to the public Downloads folder on Android, documents dir on iOS
    final Directory saveDir;
    if (Platform.isAndroid) {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      saveDir = await downloadsDir.exists() ? downloadsDir : await getApplicationDocumentsDirectory();
    } else {
      saveDir = await getApplicationDocumentsDirectory();
    }

    final filename = _attachFilename(p);
    final savePath = '${saveDir.path}/$filename';

    await Dio().download(p.url!, savePath,
        onReceiveProgress: (_, __) {});

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text('Saved: $filename',
            style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: const Color(0xFF4EC080),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ));
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: const Text('Download failed — opening in browser'),
      backgroundColor: const Color(0xFFE07878),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Open',
        textColor: Colors.white,
        onPressed: () => launchUrl(Uri.parse(p.url!),
            mode: LaunchMode.externalApplication),
      ),
    ));
  }
}

void _viewImageInApp(BuildContext context, PhotoEntity p) {
  if (p.url == null && p.localPath == null) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => _ImageViewerDialog(photo: p),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Attachments table
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentsSection extends StatefulWidget {
  final List<PhotoEntity> photos;
  final int initialShow;
  const _AttachmentsSection({required this.photos, this.initialShow = 5});

  @override
  State<_AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends State<_AttachmentsSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final visible = _showAll
        ? widget.photos
        : widget.photos.take(widget.initialShow).toList();
    final hiddenCount = widget.photos.length - widget.initialShow;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Attachments (${widget.photos.length})',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary)),
          if (widget.photos.length > widget.initialShow)
            GestureDetector(
              onTap: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll ? 'Show Less' : 'View All',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kAccent),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),

      // Table header row
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: context.bgColor,
          border: Border.all(color: context.borderColor),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8), topRight: Radius.circular(8)),
        ),
        child: Row(children: [
          Expanded(
              child: Text('File Name',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: context.textDisabled, letterSpacing: 0.3))),
          Text('Actions',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: context.textDisabled, letterSpacing: 0.3)),
        ]),
      ),

      // Data rows
      Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: context.borderColor),
            right: BorderSide(color: context.borderColor),
            bottom: BorderSide(color: context.borderColor),
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8)),
        ),
        child: Column(
          children: visible.asMap().entries.map((e) =>
              _AttachmentRow(photo: e.value, isLast: e.key == visible.length - 1)).toList(),
        ),
      ),

      if (!_showAll && hiddenCount > 0)
        GestureDetector(
          onTap: () => setState(() => _showAll = true),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.add_circle_outline_rounded,
                  size: 14, color: _kAccent),
              const SizedBox(width: 4),
              Text('+ $hiddenCount more attachment${hiddenCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: _kAccent, fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: _kAccent),
            ]),
          ),
        ),

      if (_showAll && hiddenCount > 0)
        GestureDetector(
          onTap: () => setState(() => _showAll = false),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(Icons.remove_circle_outline_rounded,
                  size: 14, color: context.textDisabled),
              const SizedBox(width: 4),
              Text('Show less',
                  style: TextStyle(
                      fontSize: 12, color: context.textDisabled, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
    ]);
  }
}

class _AttachmentRow extends StatelessWidget {
  final PhotoEntity photo;
  final bool isLast;
  const _AttachmentRow({required this.photo, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final name     = _attachFilename(photo);
    final iconBg   = _attachIconBg(photo);
    final iconData = _attachIconData(photo);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(iconData, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (photo.caption != null && !photo.caption!.contains('.'))
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(photo.caption!,
                          style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w700,
                              color: _kAccent, letterSpacing: 0.2)),
                    ),
                ],
              ),
            ),
          ]),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: (photo.url != null || photo.localPath != null)
                  ? () {
                      if (_isImageFile(photo)) {
                        _viewImageInApp(context, photo);
                      } else {
                        _openAttachment(photo);
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.remove_red_eye_outlined,
                    size: 18,
                    color: (photo.url != null || photo.localPath != null)
                        ? _kAccent
                        : context.textDisabled),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: (photo.url != null || photo.localPath != null)
                  ? () => _downloadAttachment(context, photo)
                  : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.download_rounded,
                    size: 18,
                    color: (photo.url != null || photo.localPath != null)
                        ? _kAccent
                        : context.textDisabled),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty timeline placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyTimeline extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timeline_outlined,
                size: 36, color: _kAccent.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 18),
          Text('No visits yet',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
          const SizedBox(height: 8),
          Text('Tap "+ Add New Visit" below to get started',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.textDisabled)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient Details Card
// ─────────────────────────────────────────────────────────────────────────────
class _PatientDetailsCard extends StatefulWidget {
  final PatientEntity patient;
  final List<PhotoEntity> photos;
  const _PatientDetailsCard({required this.patient, this.photos = const []});

  @override
  State<_PatientDetailsCard> createState() => _PatientDetailsCardState();
}

class _PatientDetailsCardState extends State<_PatientDetailsCard> {
  bool _expanded = false;

  PatientEntity get p => widget.patient;

  bool get _hasAnyData =>
      _nonEmpty(p.weight) || _nonEmpty(p.bloodPressure) || _nonEmpty(p.temperature) ||
      _nonEmpty(p.allergies) || _nonEmpty(p.medicalHistory) || _nonEmpty(p.previousHistory) ||
      _nonEmpty(p.altPhone) || _nonEmpty(p.email) || _nonEmpty(p.address) ||
      _nonEmpty(p.idProofType) || _nonEmpty(p.idProofNumber) ||
      widget.photos.isNotEmpty;

  static bool _nonEmpty(String? v) => v != null && v.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyData) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_ind_outlined,
                      color: _kAccent, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Patient Information',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
                ),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: context.textDisabled, size: 20),
              ]),
            ),
          ),

          if (_expanded) ...[
            Divider(height: 1, color: context.borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_nonEmpty(p.email) || _nonEmpty(p.altPhone) ||
                      _nonEmpty(p.address) || _nonEmpty(p.idProofType))
                    _Section(
                      title: 'Contact & Identity',
                      icon: Icons.contact_page_outlined,
                      color: const Color(0xFF0EA5E9),
                      rows: [
                        if (_nonEmpty(p.email)) _Row('Email', p.email!),
                        if (_nonEmpty(p.altPhone)) _Row('Alt. Phone', p.altPhone!),
                        if (_nonEmpty(p.address)) _Row('Address', p.address!),
                        if (_nonEmpty(p.idProofType)) _Row('ID Type', p.idProofType!),
                        if (_nonEmpty(p.idProofNumber)) _Row('ID Number', p.idProofNumber!),
                      ],
                    ),

                  if (_nonEmpty(p.weight) || _nonEmpty(p.bloodPressure) || _nonEmpty(p.temperature))
                    _Section(
                      title: 'Vitals',
                      icon: Icons.monitor_heart_outlined,
                      color: const Color(0xFFEF4444),
                      rows: [
                        if (_nonEmpty(p.weight)) _Row('Weight', p.weight!),
                        if (_nonEmpty(p.bloodPressure)) _Row('Blood Pressure', p.bloodPressure!),
                        if (_nonEmpty(p.temperature)) _Row('Temperature', p.temperature!),
                      ],
                    ),

                  if (_nonEmpty(p.allergies) || _nonEmpty(p.medicalHistory) || _nonEmpty(p.previousHistory))
                    _Section(
                      title: 'Medical History',
                      icon: Icons.history_edu_outlined,
                      color: const Color(0xFFF59E0B),
                      rows: [
                        if (_nonEmpty(p.allergies)) _Row('Allergies', p.allergies!),
                        if (_nonEmpty(p.medicalHistory)) _Row('Medical History', p.medicalHistory!),
                        if (_nonEmpty(p.previousHistory)) _Row('Previous History', p.previousHistory!),
                      ],
                    ),

                  if (widget.photos.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _AttachmentsSection(photos: widget.photos),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_Row> rows;
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 8),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 140,
              child: Text(r.label,
                  style: TextStyle(
                      fontSize: 11, color: context.textDisabled, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(r.value,
                  style: TextStyle(
                      fontSize: 12, color: context.textPrimary, fontWeight: FontWeight.w600)),
            ),
          ]),
        )),
        Divider(height: 1, color: context.borderColor),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient Reports Section
// ─────────────────────────────────────────────────────────────────────────────
class _PatientReportsSection extends StatelessWidget {
  final String patientId;
  final List<PhotoEntity> allPhotos;

  const _PatientReportsSection({
    required this.patientId,
    required this.allPhotos,
  });

  bool _isPdf(PhotoEntity p) =>
      p.storagePath.toLowerCase().endsWith('.pdf') ||
      (p.caption?.toLowerCase().endsWith('.pdf') ?? false) ||
      (p.url?.toLowerCase().contains('.pdf') ?? false);

  @override
  Widget build(BuildContext context) {
    final reports = allPhotos
        .where((p) => p.category == PhotoCategory.patientReport)
        .toList();

    if (reports.isEmpty) return const SizedBox.shrink();

    final pdfs   = reports.where(_isPdf).toList();
    final images = reports.where((p) => !_isPdf(p)).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_outlined,
                size: 15, color: _kAccent),
          ),
          const SizedBox(width: 8),
          Text(
            'Patient Reports',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${reports.length} file${reports.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 11,
                  color: _kAccent,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),

        if (pdfs.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...pdfs.map((p) => _PdfReportTile(photo: p)),
        ],

        if (images.isNotEmpty) ...[
          const SizedBox(height: 10),
          PhotoGalleryWidget(photos: images),
        ],
      ]),
    );
  }
}

class _PdfReportTile extends StatelessWidget {
  final PhotoEntity photo;
  const _PdfReportTile({required this.photo});

  String get _filename {
    if (photo.caption?.isNotEmpty == true) return photo.caption!;
    final parts = photo.storagePath.split('/');
    return parts.isNotEmpty ? parts.last : 'Report';
  }

  Future<void> _open() async {
    final url = photo.url;
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.primarySurf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _kAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded,
              color: _kAccent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _filename,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd MMM yyyy').format(photo.createdAt),
              style: TextStyle(fontSize: 11, color: context.textDisabled),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: photo.url != null ? _open : null,
          icon: const Icon(Icons.open_in_new_rounded, size: 14),
          label: const Text('Open', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: _kAccent,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen in-app image viewer
// ─────────────────────────────────────────────────────────────────────────────
class _ImageViewerDialog extends StatelessWidget {
  final PhotoEntity photo;
  const _ImageViewerDialog({required this.photo});

  @override
  Widget build(BuildContext context) {
    final name = _attachFilename(photo);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          name,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Open / Download',
            onPressed: () => _downloadAttachment(context, photo),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: photo.url != null
              ? Image.network(
                  photo.url!,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (ctx, _, __) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_rounded,
                          size: 64, color: Colors.white54),
                      const SizedBox(height: 12),
                      const Text('Could not load image',
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => _openAttachment(photo),
                        icon: const Icon(Icons.open_in_new, color: Colors.white70),
                        label: const Text('Open in browser',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                )
              : Image.file(
                  File(photo.localPath!),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, _, __) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_rounded,
                          size: 64, color: Colors.white54),
                      const SizedBox(height: 12),
                      const Text('Could not load image',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Bottom "Add New Visit" bar
// ─────────────────────────────────────────────────────────────────────────────
class _AddVisitBar extends StatelessWidget {
  final String patientId;
  final VoidCallback onTap;
  const _AddVisitBar({required this.patientId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      color: context.cardColor,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text(
            'Add New Visit',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ── Audit history bottom sheet ────────────────────────────────────────────────

class _AuditBottomSheet extends ConsumerWidget {
  final String visitId;
  final String patientId;
  final String title;

  const _AuditBottomSheet({
    required this.visitId,
    required this.patientId,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A3A) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF1A2D5A);
    final textSub = isDark ? const Color(0xFFB8B5DC) : const Color(0xFF6B7280);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.withValues(alpha: 0.12);

    // Fetch both visit-level and patient-level audit entries
    final visitAuditAsync = ref.watch(auditLogProvider(
        (entityType: 'visit', entityId: visitId)));
    final patientAuditAsync = ref.watch(auditLogProvider(
        (entityType: 'patient', entityId: patientId)));

    // Merge: loading if either is loading, error if either errors, else combine + sort
    final auditAsync = visitAuditAsync.when(
      loading: () => const AsyncLoading<List<AuditEntry>>(),
      error: (e, s) => AsyncError<List<AuditEntry>>(e, s),
      data: (visitEntries) => patientAuditAsync.when(
        loading: () => const AsyncLoading<List<AuditEntry>>(),
        error: (e, s) => AsyncError<List<AuditEntry>>(e, s),
        data: (patientEntries) {
          final merged = [...visitEntries, ...patientEntries]
            ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
          return AsyncData<List<AuditEntry>>(merged);
        },
      ),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.history_rounded,
                        size: 20, color: _kAccent),
                    const SizedBox(width: 8),
                    Text(title,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textMain)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close_rounded,
                          size: 20, color: textSub),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: divider),
                ],
              ),
            ),

            // Content
            Expanded(
              child: auditAsync.when(
                loading: () => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: _kAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Loading history…\nThis may take up to 90 s if the server is waking up.',
                      style: TextStyle(fontSize: 12, color: textSub),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                error: (e, _) {
                  final isTimeout = e.toString().contains('TIMEOUT') ||
                      e.toString().contains('timed out');
                  final isNoNet = e.toString().contains('NO_CONNECTION') ||
                      e.toString().contains('internet');
                  final msg = isTimeout
                      ? 'The server is still waking up.\nPlease wait a moment and retry.'
                      : isNoNet
                          ? 'No internet connection.\nPlease check your network and retry.'
                          : 'Could not load history.\nPlease retry.';
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isNoNet
                                ? Icons.wifi_off_rounded
                                : Icons.cloud_off_rounded,
                            size: 48,
                            color: textSub.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 14),
                          Text(msg,
                              style: TextStyle(fontSize: 13, color: textSub),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () {
                              ref.invalidate(auditLogProvider(
                                  (entityType: 'visit', entityId: visitId)));
                              ref.invalidate(auditLogProvider(
                                  (entityType: 'patient', entityId: patientId)));
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            style: FilledButton.styleFrom(
                              backgroundColor: _kAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_toggle_off_rounded,
                              size: 48,
                              color: textSub.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No edit history yet',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textSub)),
                          const SizedBox(height: 6),
                          Text('Changes will appear here after the first edit',
                              style: TextStyle(
                                  fontSize: 12, color: textSub),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }

                  // Group entries by date
                  final grouped = <String, List<AuditEntry>>{};
                  for (final e in entries) {
                    final key = DateFormat('dd MMM yyyy').format(
                        e.changedAt.toLocal());
                    grouped.putIfAbsent(key, () => []).add(e);
                  }

                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: grouped.length,
                    itemBuilder: (_, gi) {
                      final dateKey = grouped.keys.elementAt(gi);
                      final dayEntries = grouped[dateKey]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _kAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(dateKey,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _kAccent)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Divider(
                                      height: 1, color: divider)),
                            ]),
                          ),

                          // Entries for that day
                          ...dayEntries.map((entry) =>
                              _AuditEntryTile(
                                entry: entry,
                                isDark: isDark,
                                textMain: textMain,
                                textSub: textSub,
                                divider: divider,
                              )),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditEntryTile extends StatefulWidget {
  final AuditEntry entry;
  final bool isDark;
  final Color textMain;
  final Color textSub;
  final Color divider;
  const _AuditEntryTile({
    required this.entry,
    required this.isDark,
    required this.textMain,
    required this.textSub,
    required this.divider,
  });
  @override
  State<_AuditEntryTile> createState() => _AuditEntryTileState();
}

class _AuditEntryTileState extends State<_AuditEntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final time = DateFormat('hh:mm a').format(e.changedAt.toLocal());
    final hasOld = e.oldValue != null && e.oldValue!.isNotEmpty;
    final hasNew = e.newValue != null && e.newValue!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.divider),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      size: 16, color: _kAccent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.displayLabel,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.textMain)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.access_time_rounded,
                            size: 11, color: widget.textSub),
                        const SizedBox(width: 3),
                        Text(time,
                            style: TextStyle(
                                fontSize: 11, color: widget.textSub)),
                        if (e.changedByName != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.person_outline_rounded,
                              size: 11, color: widget.textSub),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(e.changedByName!,
                                style: TextStyle(
                                    fontSize: 11, color: widget.textSub),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: widget.textSub,
                ),
              ]),
            ),
          ),

          // Expanded diff view
          if (_expanded) ...[
            Divider(height: 1, color: widget.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasOld) ...[
                    _DiffBox(
                      label: 'Previous',
                      value: e.oldValue!,
                      color: const Color(0xFFDC2626),
                      bg: const Color(0xFFFEF2F2),
                      isDark: widget.isDark,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (hasNew)
                    _DiffBox(
                      label: 'Updated to',
                      value: e.newValue!,
                      color: const Color(0xFF16A34A),
                      bg: const Color(0xFFF0FDF4),
                      isDark: widget.isDark,
                    ),
                  if (!hasOld && !hasNew)
                    Text('(no change details)',
                        style: TextStyle(
                            fontSize: 12, color: widget.textSub)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiffBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final bool isDark;
  const _DiffBox({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? color.withValues(alpha: 0.12) : bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF374151))),
          ],
        ),
      );
}
