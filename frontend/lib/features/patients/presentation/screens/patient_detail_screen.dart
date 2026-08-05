// ─────────────────────────────────────────────────────────────────────────────
// patient_detail_screen.dart  –  Patient Timeline
// Clean vertical timeline · patient header card · Add New Visit CTA
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

// ── Print data builder ────────────────────────────────────────────────────────
Map<String, String> _buildVisitPrintMap(
    PatientEntity patient, VisitEntity visit,
    {List<PhotoEntity> photos = const []}) {
  // Parse patient notes JSON
  Map<String, String> pNotes = {};
  if (patient.notes?.isNotEmpty == true) {
    try {
      pNotes = (jsonDecode(patient.notes!) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {}
  }
  // Parse visit examination JSON
  Map<String, String> exam = {};
  if (visit.examination?.isNotEmpty == true) {
    try {
      exam = (jsonDecode(visit.examination!) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {}
  }
  String pn(String k) => pNotes[k]?.isNotEmpty == true ? pNotes[k]! : '';
  String ex(String k) => exam[k]?.isNotEmpty == true ? exam[k]! : '';
  final dob = patient.dateOfBirth != null
      ? DateFormat('dd MMMM yyyy').format(patient.dateOfBirth!) : '—';
  final gender = patient.sex?.isNotEmpty == true
      ? '${patient.sex![0].toUpperCase()}${patient.sex!.substring(1)}' : '—';
  final ageStr = patient.computedAge > 0 ? '${patient.computedAge} yrs' : '—';
  return {
    // ── Basic Information ──────────────────────────────────────────────────
    'firstName':       patient.firstName,
    'lastName':        patient.lastName.isEmpty ? '—' : patient.lastName,
    'age':             ageStr,
    'dob':             dob,
    'gender':          gender,
    'phone':           patient.phone ?? '—',
    'altPhone':        pn('altPhone'),
    'email':           pn('email'),
    'address':         patient.address ?? '—',
    'idProofType':     pn('idProofType'),
    'idProofNumber':   pn('idProofNumber'),
    'allergies':       pn('allergies'),
    'medicalHistory':  pn('medicalHistory'),
    // ── Vitals — visit overrides patient-level ─────────────────────────────
    'weight':          _pick(ex('weight'),       pn('weight')),
    'bloodPressure':   _pick(ex('bp'),           pn('bloodPressure')),
    'temperature':     _pick(ex('temperature'),  pn('temperature')),
    // ── Treatment — visit data first, patient registration fallback ─────────
    'previousHistory':    _pick(ex('previousHistory'),    pn('previousHistory')),
    'chiefComplaint':     _pick(visit.complaints,          pn('chiefComplaint')),
    'examGeneral':        _pick(ex('examGeneral'),         pn('examGeneral')),
    'examNeurological':   _pick(ex('examNeurological'),    pn('examNeurological')),
    'clinicalDiagnosis':  _pick(ex('clinicalDiagnosis'),   pn('clinicalDiagnosis')),
    'imaging':            _pick(ex('imaging'),             pn('imaging')),
    'otherInvestigation': _pick(ex('otherInvestigation'),  pn('otherInvestigation')),
    'diagnosis':          _pick(visit.clinicalImpression,  pn('diagnosis')),
    'treatmentPlan':      _pick(visit.plan,                pn('treatmentPlan')),
    'medications':        _pick(ex('medications'),         pn('medications')),
    'notes':              _pick(visit.notes,               pn('notes')),
    'advice':             _pick(ex('advice'),              pn('advice')),
    'visitType':          visit.visitType.label,
  }..removeWhere((_, v) => v.isEmpty);
}

/// Returns [a] when non-null and non-empty, otherwise [b].
String _pick(String? a, String b) =>
    (a?.isNotEmpty == true) ? a! : b;


// ── Design tokens ─────────────────────────────────────────────────────────────
const _kAccent  = Color(0xFF3D3BF3);   // blue-purple dot & accents
const _kRed     = Color(0xFFEF4444);   // surgery colour
const _kBg      = Color(0xFFF5F5F5);
const _kCard    = Colors.white;
const _kNavy    = Color(0xFF0F172A);
const _kSlate   = Color(0xFF475569);
const _kMuted   = Color(0xFF94A3B8);
const _kBorder  = Color(0xFFE8ECF0);
const _kLine    = Color(0xFFDDE2EA);   // timeline connecting line

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
    final patientId    = widget.patientId;
    final patientAsync = ref.watch(patientByIdProvider(patientId));
    final visits       = ref.watch(visitsProvider(patientId));
    final surgeries    = ref.watch(surgeriesProvider(patientId));
    final allPhotos    = ref.watch(photoProvider(patientId)).photos;
    final canWrite     = ref.watch(canWriteProvider);

    return patientAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kAccent)),
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

        // Show all visits sorted newest-first
        final sortedVisits = visits.toList()
          ..sort((a, b) => b.visitDate.compareTo(a.visitDate));

        // Build unified timeline sorted newest-first
        final timeline = <_TimelineItem>[
          ...sortedVisits.map((v) => _TimelineItem.fromVisit(v)),
          ...surgeries.map((s) => _TimelineItem.fromSurgery(s)),
        ]..sort((a, b) => b.date.compareTo(a.date));

        return Scaffold(
          backgroundColor: _kBg,
          appBar: _TimelineAppBar(
            patientId: patientId,
            onFilter: () {},
          ),
          body: Column(children: [
            // Patient header card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _PatientHeaderCard(patient: patient),
            ),

            // Patient reports (PDFs / files uploaded at patient level)
            _PatientReportsSection(
              patientId: patientId,
              allPhotos: allPhotos,
            ),

            // Timeline
            Expanded(
              child: timeline.isEmpty
                  ? _EmptyTimeline()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: timeline.length,
                      itemBuilder: (ctx, i) => _TimelineRow(
                        item: timeline[i],
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
                                '/patients/$patientId/visits/${timeline[i].id}');
                          } else if (canWrite) {
                            context.push(
                                '/patients/$patientId/surgeries/${timeline[i].id}');
                          }
                        },
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
                      ),
                    ),
            ),
          ]),

          // ── Fixed bottom CTA (admin only) ─────────────────────────
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
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
  final String type;         // 'visit' | 'surgery'
  final DateTime date;
  final String title;        // diagnosis or procedure
  final String subtitle;     // medications or pre-op diagnosis
  final bool isDraft;
  final VisitEntity? visit;  // full visit entity for print

  const _TimelineItem({
    required this.id,
    required this.type,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.isDraft,
    this.visit,
  });

  factory _TimelineItem.fromVisit(VisitEntity v) {
    // Title: diagnosis > complaint > 'OPD Visit'
    final title = v.clinicalImpression?.trim().isNotEmpty == true
        ? v.clinicalImpression!
        : v.complaints?.trim().isNotEmpty == true
            ? v.complaints!
            : 'OPD Visit';

    // Subtitle: medications from examination JSON
    String meds = '';
    if (v.examination?.isNotEmpty == true) {
      try {
        final m = jsonDecode(v.examination!) as Map<String, dynamic>;
        meds = (m['medications'] as String?) ?? '';
      } catch (_) {}
    }

    return _TimelineItem(
      id:       v.id,
      type:     'visit',
      date:     v.visitDate,
      title:    title,
      subtitle: meds,
      isDraft:  v.isDraft,
      visit:    v,
    );
  }

  factory _TimelineItem.fromSurgery(SurgeryEntity s) => _TimelineItem(
    id:       s.id,
    type:     'surgery',
    date:     s.surgeryDate,
    title:    s.procedure ?? 'Surgery',
    subtitle: s.preOpDiagnosis ?? '',
    isDraft:  s.status == 'draft',
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
    backgroundColor: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.white,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _kNavy),
      onPressed: () => context.go('/patients'),
    ),
    title: const Text(
      'Patient Timeline',
      style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _kNavy,
          letterSpacing: -0.2),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.tune_rounded, color: _kSlate, size: 22),
        onPressed: onFilter,
        tooltip: 'Filter',
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _kBorder),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient header card
// ─────────────────────────────────────────────────────────────────────────────
class _PatientHeaderCard extends StatelessWidget {
  final PatientEntity patient;
  const _PatientHeaderCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    final initials = patient.initials;
    final genderText = patient.sex?.isNotEmpty == true
        ? '${patient.sex![0].toUpperCase()}${patient.sex!.substring(1)}'
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Initials avatar
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(initials,
              style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
        ),
        const SizedBox(width: 14),

        // Name + gender + meta + patient ID (all stacked vertically)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(patient.fullName,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _kNavy,
                            letterSpacing: -0.3),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (genderText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _kAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(genderText,
                          style: const TextStyle(
                              color: _kAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (patient.ageSex.isNotEmpty) patient.ageSex,
                  if (patient.phone?.isNotEmpty == true) patient.phone!,
                ].join(' • '),
                style: const TextStyle(
                    fontSize: 12,
                    color: _kSlate,
                    fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 6),
              Row(children: [
                const Text('ID: ',
                    style: TextStyle(
                        fontSize: 11,
                        color: _kMuted,
                        fontWeight: FontWeight.w500)),
                Flexible(
                  child: Text(patient.prn,
                      style: const TextStyle(
                          color: _kAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: patient.prn));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Patient ID copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.copy_outlined,
                        size: 13, color: _kAccent),
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
// Single timeline row
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineRow extends StatefulWidget {
  final _TimelineItem item;
  final bool isLast;
  final bool canWrite;
  final List<PhotoEntity> photos;
  final VoidCallback onDocTap;
  final VoidCallback? onPrint;
  final bool initiallyExpanded;
  const _TimelineRow({
    required this.item,
    required this.isLast,
    required this.canWrite,
    required this.photos,
    required this.onDocTap,
    this.onPrint,
    this.initiallyExpanded = false,
  });

  @override
  State<_TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends State<_TimelineRow> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  _TimelineItem get item => widget.item;
  bool get isLast => widget.isLast;
  bool get canWrite => widget.canWrite;
  List<PhotoEntity> get photos => widget.photos;

  Color get _dotColor => item.type == 'visit' ? _kAccent : _kRed;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(item.date);
    final timeStr = DateFormat('hh:mm a').format(item.date);
    final dotColor = _dotColor;

    // ── Parse examination JSON ────────────────────────────────────
    final examMap = <String, String>{};
    if (item.visit?.examination?.isNotEmpty == true) {
      try {
        (jsonDecode(item.visit!.examination!) as Map<String, dynamic>)
            .forEach((k, v) {
          if (v is String && v.isNotEmpty) examMap[k] = v;
        });
      } catch (_) {}
    }
    String ex(String k) => examMap[k] ?? '';

    // ── Collect all data fields (only non-empty) ──────────────────
    final dataRows = <({String label, String value})>[];
    void add(String label, String val) {
      if (val.trim().isNotEmpty) dataRows.add((label: label, value: val.trim()));
    }

    if (item.visit != null) {
      add('Chief Complaint',     item.visit!.complaints ?? '');
      add('Previous History',    ex('previousHistory'));
      add('General Exam',        ex('examGeneral'));
      add('Neurological Exam',   ex('examNeurological'));
      add('Clinical Diagnosis',  ex('clinicalDiagnosis'));
      add('Imaging',             ex('imaging'));
      add('Other Investigation', ex('otherInvestigation'));
      add('Impression',          item.visit!.clinicalImpression ?? '');
      add('Plan',                item.visit!.plan ?? '');
      add('Treatment',           ex('medications'));
      add('Notes',               item.visit!.notes ?? '');
      add('Advice',              ex('advice'));
    } else {
      // Surgery
      add('Procedure',           item.title);
      add('Pre-op Diagnosis',    item.subtitle);
    }

    // Vitals: show in a dedicated row only if any present
    final bp   = ex('bp');
    final wt   = ex('weight');
    final temp = ex('temperature');
    final hasVitals = bp.isNotEmpty || wt.isNotEmpty || temp.isNotEmpty;

    final accentColor = item.type == 'visit' ? _kAccent : _kRed;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Left: dot + line ──────────────────────────────────────
        SizedBox(
          width: 28,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Center(
                    child: Container(width: 1.5, color: _kLine),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // ── Right: card ───────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row (always visible, tap to expand) ─────
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Row(children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.calendar_month_outlined,
                              size: 17, color: accentColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(dateStr,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _kNavy)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('|',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: _kMuted.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w300)),
                                ),
                                Text(timeStr,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _kNavy)),
                              ]),
                              const SizedBox(height: 4),
                              Row(children: [
                                if (item.visit != null) ...[
                                  _Chip(
                                    label: item.visit!.visitType.label,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                _Chip(
                                  label: item.isDraft ? 'Draft' : 'Completed',
                                  color: item.isDraft
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF059669),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        // Action buttons
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          if (widget.onPrint != null) ...[
                            Tooltip(
                              message: 'Print & Export',
                              child: GestureDetector(
                                onTap: widget.onPrint,
                                child: Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(Icons.print_outlined,
                                      size: 17, color: Color(0xFF7C3AED)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          // Expand/collapse chevron
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.keyboard_arrow_down_rounded,
                                size: 20, color: _kMuted),
                          ),
                        ]),
                      ]),
                    ),
                  ),

                  // ── Collapsible body ──────────────────────────
                  if (_expanded && (dataRows.isNotEmpty || hasVitals || photos.isNotEmpty)) ...[
                    Divider(height: 1, thickness: 1,
                        color: accentColor.withValues(alpha: 0.12)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasVitals) ...[
                            Wrap(spacing: 12, runSpacing: 6, children: [
                              if (bp.isNotEmpty)
                                _VitalChip(icon: Icons.favorite_border_rounded,
                                    label: 'BP', value: bp),
                              if (wt.isNotEmpty)
                                _VitalChip(icon: Icons.monitor_weight_outlined,
                                    label: 'Weight', value: wt),
                              if (temp.isNotEmpty)
                                _VitalChip(icon: Icons.thermostat_outlined,
                                    label: 'Temp', value: temp),
                            ]),
                            if (dataRows.isNotEmpty || photos.isNotEmpty)
                              const SizedBox(height: 10),
                          ],
                          ...dataRows.map((r) => _DataRow(label: r.label, value: r.value)),
                          if (photos.isNotEmpty) ...[
                            if (dataRows.isNotEmpty) const SizedBox(height: 10),
                            _AttachmentsSection(photos: photos),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Small helpers used inside _TimelineRow ────────────────────────────────────
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
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class _VitalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _VitalChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: _kMuted),
          const SizedBox(width: 4),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 11, color: _kMuted, fontWeight: FontWeight.w500)),
          Text(value,
              style: const TextStyle(
                  fontSize: 11, color: _kNavy, fontWeight: FontWeight.w700)),
        ]),
      );
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
              style: const TextStyle(
                  fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, color: _kNavy, fontWeight: FontWeight.w600)),
        ]),
      );
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
  if (t == 'Image') return const Color(0xFF7C3AED);
  if (t == 'Excel') return const Color(0xFF16A34A);
  if (t == 'Word')  return const Color(0xFF2563EB);
  return _kSlate;
}

IconData _attachIconData(PhotoEntity p) {
  final t = _attachTypeLabel(p);
  if (t == 'PDF')   return Icons.picture_as_pdf_rounded;
  if (t == 'Image') return Icons.image_rounded;
  if (t == 'Excel') return Icons.table_chart_rounded;
  if (t == 'Word')  return Icons.description_rounded;
  return Icons.insert_drive_file_rounded;
}

String _attachSizeLabel(PhotoEntity p) {
  final b = p.fileSize;
  if (b == null || b == 0) return '—';
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
}

Future<void> _openAttachment(PhotoEntity p) async {
  final url = p.url;
  if (url == null || url.isEmpty) return;
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attachments table — used in both timeline cards and patient details card
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
      // ── Header ───────────────────────────────────────────────────
      Row(children: [
        Text('Attachments (${widget.photos.length})',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _kNavy)),
      ]),
      const SizedBox(height: 8),

      // ── Table header row ─────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: _kBorder),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8), topRight: Radius.circular(8)),
        ),
        child: Row(children: const [
          Expanded(flex: 4,
              child: Text('File Name',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: _kMuted, letterSpacing: 0.3))),
          Expanded(flex: 4,
              child: Text('Uploaded On',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: _kMuted, letterSpacing: 0.3))),
          Expanded(flex: 3,
              child: Text('Actions',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: _kMuted, letterSpacing: 0.3))),
        ]),
      ),

      // ── Data rows ────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: _kBorder),
            right: BorderSide(color: _kBorder),
            bottom: BorderSide(color: _kBorder),
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

      // ── "N more" expand button ───────────────────────────────────
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

      // ── "Show less" collapse ─────────────────────────────────────
      if (_showAll && hiddenCount > 0)
        GestureDetector(
          onTap: () => setState(() => _showAll = false),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: const [
              Icon(Icons.remove_circle_outline_rounded,
                  size: 14, color: _kMuted),
              SizedBox(width: 4),
              Text('Show less',
                  style: TextStyle(
                      fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
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
    final dateStr  = DateFormat('dd MMM yyyy, hh:mm a').format(photo.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(children: [
        // File icon + name
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
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        // Date
        Expanded(flex: 4,
            child: Text(dateStr,
                style: const TextStyle(fontSize: 11, color: _kSlate),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
        // Actions
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // View
              GestureDetector(
                onTap: photo.url != null ? () => _openAttachment(photo) : null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.remove_red_eye_outlined,
                      size: 15,
                      color: photo.url != null ? _kAccent : _kMuted),
                  const SizedBox(width: 3),
                  Text('View',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: photo.url != null ? _kAccent : _kMuted)),
                ]),
              ),
              const SizedBox(width: 16),
              // Download
              GestureDetector(
                onTap: photo.url != null ? () => _openAttachment(photo) : null,
                child: Icon(Icons.download_rounded,
                    size: 18,
                    color: photo.url != null ? _kAccent : _kMuted),
              ),
            ],
          ),
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
          const Text('No visits yet',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _kNavy)),
          const SizedBox(height: 8),
          const Text('Tap "+ Add New Visit" below to get started',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _kMuted)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient Details Card — shows all registration fields
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
      _nonEmpty(p.chiefComplaint) || _nonEmpty(p.examGeneral) || _nonEmpty(p.examNeurological) ||
      _nonEmpty(p.clinicalDiagnosis) || _nonEmpty(p.imaging) || _nonEmpty(p.otherInvestigations) ||
      _nonEmpty(p.impression) || _nonEmpty(p.plan) || _nonEmpty(p.treatment) ||
      _nonEmpty(p.treatmentNotes) || _nonEmpty(p.advice) ||
      _nonEmpty(p.altPhone) || _nonEmpty(p.email) || _nonEmpty(p.address) ||
      _nonEmpty(p.idProofType) || _nonEmpty(p.idProofNumber) ||
      widget.photos.isNotEmpty;

  static bool _nonEmpty(String? v) => v != null && v.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyData) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row (tap to expand/collapse) ──────────────────
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
                const Expanded(
                  child: Text('Patient Information',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
                ),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: _kMuted, size: 20),
              ]),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact & Identity
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

                  // Vitals
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

                  // History
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

                  // Clinical Findings
                  if (_nonEmpty(p.chiefComplaint) || _nonEmpty(p.examGeneral) || _nonEmpty(p.examNeurological))
                    _Section(
                      title: 'Clinical Findings',
                      icon: Icons.person_search_outlined,
                      color: const Color(0xFF6366F1),
                      rows: [
                        if (_nonEmpty(p.chiefComplaint)) _Row('Chief Complaint', p.chiefComplaint!),
                        if (_nonEmpty(p.examGeneral)) _Row('General Exam', p.examGeneral!),
                        if (_nonEmpty(p.examNeurological)) _Row('Neurological Exam', p.examNeurological!),
                      ],
                    ),

                  // Investigation
                  if (_nonEmpty(p.clinicalDiagnosis) || _nonEmpty(p.imaging) || _nonEmpty(p.otherInvestigations))
                    _Section(
                      title: 'Investigation',
                      icon: Icons.science_outlined,
                      color: const Color(0xFF10B981),
                      rows: [
                        if (_nonEmpty(p.clinicalDiagnosis)) _Row('Diagnosis', p.clinicalDiagnosis!),
                        if (_nonEmpty(p.imaging)) _Row('Imaging', p.imaging!),
                        if (_nonEmpty(p.otherInvestigations)) _Row('Other Investigations', p.otherInvestigations!),
                      ],
                    ),

                  // Clinical Plan
                  if (_nonEmpty(p.impression) || _nonEmpty(p.plan) || _nonEmpty(p.treatment) ||
                      _nonEmpty(p.treatmentNotes) || _nonEmpty(p.advice))
                    _Section(
                      title: 'Clinical Plan',
                      icon: Icons.assignment_outlined,
                      color: _kAccent,
                      rows: [
                        if (_nonEmpty(p.impression)) _Row('Impression', p.impression!),
                        if (_nonEmpty(p.plan)) _Row('Plan', p.plan!),
                        if (_nonEmpty(p.treatment)) _Row('Treatment', p.treatment!),
                        if (_nonEmpty(p.treatmentNotes)) _Row('Notes', p.treatmentNotes!),
                        if (_nonEmpty(p.advice)) _Row('Advice', p.advice!),
                      ],
                    ),

                  // Uploaded Documents
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
                  style: const TextStyle(
                      fontSize: 11, color: _kMuted, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(r.value,
                  style: const TextStyle(
                      fontSize: 12, color: _kNavy, fontWeight: FontWeight.w600)),
            ),
          ]),
        )),
        const Divider(height: 1, color: _kBorder),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DocsSection removed — _AttachmentsSection is used directly
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Patient Reports Section — shows patientReport photos/PDFs even without visits
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_outlined,
                size: 15, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(width: 8),
          const Text(
            'Patient Reports',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${reports.length} file${reports.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),

        // PDF files
        if (pdfs.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...pdfs.map((p) => _PdfReportTile(photo: p)),
        ],

        // Image files
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
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded,
              color: Color(0xFF7C3AED), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _filename,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kNavy),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd MMM yyyy').format(photo.createdAt),
              style: const TextStyle(fontSize: 11, color: _kMuted),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: photo.url != null ? _open : null,
          icon: const Icon(Icons.open_in_new_rounded, size: 14),
          label: const Text('Open', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF7C3AED),
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
// Bottom "Add New Visit" bar  –  navigates directly to wizard (no pre-create)
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
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            '+ Add New Visit',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}
