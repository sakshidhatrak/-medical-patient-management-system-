// ─────────────────────────────────────────────────────────────────────────────
// visit_view_screen.dart  –  Read-only visit detail view with photos/reports
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../examinations/presentation/screens/examination_screen.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../../../photos/domain/entities/photo_entity.dart';
import '../../../photos/presentation/providers/photo_provider.dart';
import '../../../photos/presentation/widgets/photo_gallery_widget.dart';
import '../../../prescriptions/presentation/screens/prescription_screen.dart';
import '../../domain/entities/visit_entity.dart';
import '../providers/visit_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kP1    = Color(0xFF7C3AED);
const _kP2    = Color(0xFF3B82F6);
const _kRed   = Color(0xFFEF4444);
const _kGreen = Color(0xFF10B981);
const _kAmber = Color(0xFFF59E0B);
const _kBg    = Color(0xFFF8FAFC);
const _kNavy  = Color(0xFF0F172A);
const _kSlate = Color(0xFF475569);
const _kMuted = Color(0xFF94A3B8);
const _kBorder= Color(0xFFE2E8F0);

class VisitViewScreen extends ConsumerWidget {
  final String patientId;
  final String visitId;
  const VisitViewScreen({super.key, required this.patientId, required this.visitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitAsync   = ref.watch(visitEditProvider('$patientId/$visitId'));
    final patientAsync = ref.watch(patientByIdProvider(patientId));
    final examState    = ref.watch(examinationProvider('$patientId/$visitId'));
    final rxState      = ref.watch(prescriptionProvider('$patientId/$visitId'));
    final photoState   = ref.watch(photoProvider(patientId));
    final canWrite     = ref.watch(canWriteProvider);

    final visit = visitAsync;
    if (visit == null) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(backgroundColor: _kP1, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator(color: _kP1)),
      );
    }

    // Parse vitals from examination JSON
    Map<String, String> vitals = {};
    String physExam   = '';
    String sysExam    = '';
    String radiology  = '';
    if (visit.examination?.isNotEmpty == true) {
      try {
        final m = json.decode(visit.examination!) as Map<String, dynamic>;
        if ((m['bp']       as String?)?.isNotEmpty == true) vitals['BP']          = '${m['bp']} mmHg';
        if ((m['pulse']    as String?)?.isNotEmpty == true) vitals['Pulse']        = '${m['pulse']} bpm';
        if ((m['temp']     as String?)?.isNotEmpty == true) vitals['Temp']         = '${m['temp']}°F';
        if ((m['spo2']     as String?)?.isNotEmpty == true) vitals['SpO₂']         = '${m['spo2']}%';
        if ((m['weight']   as String?)?.isNotEmpty == true) vitals['Weight']       = '${m['weight']} kg';
        if ((m['height']   as String?)?.isNotEmpty == true) vitals['Height']       = '${m['height']} cm';
        physExam   = (m['physical']  as String?) ?? '';
        sysExam    = (m['systemic']  as String?) ?? '';
        radiology  = (m['radiology'] as String?) ?? '';
      } catch (_) {}
    }

    // Photos by category
    final visitPhotos  = photoState.photos.where((p) => p.visitId == visitId && p.category == PhotoCategory.visit).toList();
    final examPhotos   = photoState.photos.where((p) => p.visitId == visitId && p.category == PhotoCategory.examination).toList();
    final radioPhotos  = photoState.photos.where((p) => p.visitId == visitId && p.category == PhotoCategory.radiology).toList();
    final txPhotos     = photoState.photos.where((p) => p.visitId == visitId && p.category == PhotoCategory.treatment).toList();
    final reportPhotos = photoState.photos.where((p) => p.patientId == patientId && p.category == PhotoCategory.patientReport).toList();

    final patient  = patientAsync.valueOrNull;
    final dateFmt  = DateFormat('EEEE, d MMM yyyy');
    final timeFmt  = DateFormat('h:mm a');
    final isDraft  = visit.isDraft;
    final chips    = visit.complaints?.isNotEmpty == true
        ? visit.complaints!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          // ── Hero app bar ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            backgroundColor: _kP1,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 17),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (canWrite)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit Visit',
                  onPressed: () =>
                      context.push('/patients/$patientId/visits/$visitId'),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _VisitHeroBg(
                patient:   patient,
                visitType: visit.visitType.label,
                date:      dateFmt.format(visit.visitDate),
                time:      timeFmt.format(visit.visitDate),
                isDraft:   isDraft,
              ),
            ),
          ),

          // ── Body ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Complaints ──────────────────────────────────────
                if (chips.isNotEmpty || visit.notes?.isNotEmpty == true)
                  _ViewSection(
                    title: 'Chief Complaints',
                    icon: Icons.medical_services_outlined,
                    color: _kP1,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (chips.isNotEmpty)
                        Wrap(spacing: 6, runSpacing: 6, children: chips.map((c) =>
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(
                              color: _kP1.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _kP1.withValues(alpha: 0.2)),
                            ),
                            child: Text(c, style: const TextStyle(fontSize: 12, color: _kP1, fontWeight: FontWeight.w600)),
                          )
                        ).toList()),
                      if (visit.notes?.isNotEmpty == true) ...[
                        if (chips.isNotEmpty) const SizedBox(height: 10),
                        _VField('History / Notes', visit.notes!),
                      ],
                    ]),
                  ),

                // ── Vitals ──────────────────────────────────────────
                if (vitals.isNotEmpty)
                  _ViewSection(
                    title: 'Vitals',
                    icon: Icons.monitor_heart_outlined,
                    color: _kRed,
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: vitals.entries.map((e) => _VitalChip(e.key, e.value)).toList(),
                    ),
                  ),

                // ── Examination ─────────────────────────────────────
                if (physExam.isNotEmpty || sysExam.isNotEmpty || examPhotos.isNotEmpty)
                  _ViewSection(
                    title: 'General Examination',
                    icon: Icons.document_scanner_outlined,
                    color: _kAmber,
                    child: Column(children: [
                      if (physExam.isNotEmpty) _VField('Physical Examination', physExam),
                      if (sysExam.isNotEmpty)  _VField('Systemic Examination', sysExam),
                      if (examPhotos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _PhotoRow('Exam Photos', examPhotos),
                      ],
                    ]),
                  ),

                // ── CNS Examination ─────────────────────────────────
                if (examState != null)
                  _ViewSection(
                    title: 'CNS Examination',
                    icon: Icons.psychology_outlined,
                    color: _kP2,
                    child: Column(children: [
                      if (examState.generalText?.isNotEmpty  == true) _VField('General',   examState.generalText!),
                      if (examState.motorText?.isNotEmpty    == true) _VField('Motor',     examState.motorText!),
                      if (examState.sensoryText?.isNotEmpty  == true) _VField('Sensory',   examState.sensoryText!),
                      if (examState.reflexesText?.isNotEmpty == true) _VField('Reflexes',  examState.reflexesText!),
                      if (examState.cerebellarText?.isNotEmpty == true) _VField('Cerebellar', examState.cerebellarText!),
                      if (examState.specialTestsText?.isNotEmpty == true) _VField('Special Tests', examState.specialTestsText!),
                    ]),
                  ),

                // ── Radiology ───────────────────────────────────────
                if (radiology.isNotEmpty || radioPhotos.isNotEmpty)
                  _ViewSection(
                    title: 'Radiology & Investigations',
                    icon: Icons.biotech_outlined,
                    color: _kP2,
                    child: Column(children: [
                      if (radiology.isNotEmpty) _VField('Findings', radiology),
                      if (radioPhotos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _PhotoRow('Radiology Images', radioPhotos),
                      ],
                    ]),
                  ),

                // ── Clinical Impression ─────────────────────────────
                if (visit.clinicalImpression?.isNotEmpty == true)
                  _ViewSection(
                    title: 'Clinical Impression',
                    icon: Icons.lightbulb_outline_rounded,
                    color: _kGreen,
                    child: _VField('Diagnosis / Impression', visit.clinicalImpression!),
                  ),

                // ── Plan ────────────────────────────────────────────
                if (visit.plan?.isNotEmpty == true)
                  _ViewSection(
                    title: 'Treatment Plan',
                    icon: Icons.receipt_long_outlined,
                    color: _kGreen,
                    child: _VField('Plan', visit.plan!),
                  ),

                // ── Prescription ────────────────────────────────────
                if (rxState != null && (rxState.text?.isNotEmpty == true || rxState.drugs.isNotEmpty))
                  _ViewSection(
                    title: 'Prescription',
                    icon: Icons.medication_outlined,
                    color: _kP1,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (rxState.text?.isNotEmpty == true)
                        _VField('Free-text Rx', rxState.text!),
                      if (rxState.drugs.isNotEmpty) ...[
                        if (rxState.text?.isNotEmpty == true) const SizedBox(height: 10),
                        ...rxState.drugs.map((d) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _kP1.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kP1.withValues(alpha: 0.15)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.medication_outlined, size: 16, color: _kP1),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(d.displayName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
                                if (d.displayDosage.isNotEmpty)
                                  Text(d.displayDosage,
                                      style: const TextStyle(fontSize: 11, color: _kMuted)),
                              ]),
                            ),
                          ]),
                        )),
                      ],
                    ]),
                  ),

                // ── Treatment Photos ─────────────────────────────────
                if (txPhotos.isNotEmpty || visitPhotos.isNotEmpty)
                  _ViewSection(
                    title: 'Treatment & Visit Photos',
                    icon: Icons.photo_library_outlined,
                    color: _kAmber,
                    child: Column(children: [
                      if (visitPhotos.isNotEmpty)  _PhotoRow('Visit Photos',     visitPhotos),
                      if (txPhotos.isNotEmpty) ...[
                        if (visitPhotos.isNotEmpty) const SizedBox(height: 10),
                        _PhotoRow('Treatment Photos', txPhotos),
                      ],
                    ]),
                  ),

                // ── Uploaded Reports ─────────────────────────────────
                if (reportPhotos.isNotEmpty)
                  _ViewSection(
                    title: 'Uploaded Reports',
                    icon: Icons.upload_file_rounded,
                    color: _kSlate,
                    child: _PhotoRow('Patient Reports', reportPhotos),
                  ),

                // ── Empty state ──────────────────────────────────────
                if (chips.isEmpty && vitals.isEmpty && physExam.isEmpty &&
                    examState == null && radiology.isEmpty &&
                    visit.clinicalImpression == null && visit.plan == null &&
                    rxState == null && visitPhotos.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(children: const [
                      Icon(Icons.note_alt_outlined, size: 40, color: _kMuted),
                      SizedBox(height: 12),
                      Text('No details recorded yet.',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kNavy)),
                      SizedBox(height: 6),
                      Text('No visit details have been filled in.',
                          style: TextStyle(fontSize: 12, color: _kMuted),
                          textAlign: TextAlign.center),
                    ]),
                  ),
              ]),
            ),
          ),
        ],
      ),

      // ── Edit FAB (admin only) ────────────────────────────────────────
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/patients/$patientId/visits/$visitId'),
              backgroundColor: _kP1,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit Visit', style: TextStyle(fontWeight: FontWeight.w700)),
              elevation: 4,
            )
          : null,
    );
  }
}

// ── Hero background ───────────────────────────────────────────────────────────
class _VisitHeroBg extends StatelessWidget {
  final PatientEntity? patient;
  final String visitType, date, time;
  final bool isDraft;
  const _VisitHeroBg({
    required this.patient, required this.visitType,
    required this.date, required this.time, required this.isDraft,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF6D28D9), Color(0xFF2563EB)],
      ),
    ),
    child: Stack(children: [
      Positioned(right: -20, top: 20, child: _GlassOrb(100, 0.08)),
      Positioned(left: -10, bottom: 0, child: _GlassOrb(80, 0.05)),
      Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 56,
          left: 20, right: 20, bottom: 16,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Visit type badge + draft
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.medical_services_outlined, size: 12, color: Colors.white),
                const SizedBox(width: 5),
                Text(visitType,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
            if (isDraft) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAmber.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kAmber.withValues(alpha: 0.5)),
                ),
                child: const Text('DRAFT',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ]),

          const SizedBox(height: 12),

          // Patient name
          if (patient != null)
            Text(patient!.fullName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.3)),
          const SizedBox(height: 4),

          // Date/time
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.white70),
            const SizedBox(width: 5),
            Text(date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 10),
            const Icon(Icons.access_time_outlined, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            Text(time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ]),
      ),
    ]),
  );
}

class _GlassOrb extends StatelessWidget {
  final double size, opacity;
  const _GlassOrb(this.size, this.opacity);
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

// ── View section card ─────────────────────────────────────────────────────────
class _ViewSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  const _ViewSection({required this.title, required this.icon, required this.color, required this.child});
  @override
  State<_ViewSection> createState() => _ViewSectionState();
}

class _ViewSectionState extends State<_ViewSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, size: 15, color: widget.color),
            ),
            const SizedBox(width: 10),
            Text(widget.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
            const Spacer(),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: widget.color.withValues(alpha: 0.7)),
            ),
          ]),
        ),
      ),
      if (_open) ...[
        Divider(height: 1, color: widget.color.withValues(alpha: 0.12)),
        Padding(padding: const EdgeInsets.all(14), child: widget.child),
      ],
    ]),
  );
}

// ── Field display ─────────────────────────────────────────────────────────────
class _VField extends StatelessWidget {
  final String label, value;
  const _VField(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.7)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(fontSize: 13, color: _kNavy, height: 1.5)),
    ]),
  );
}

// ── Photo row ─────────────────────────────────────────────────────────────────
class _PhotoRow extends StatelessWidget {
  final String label;
  final List<PhotoEntity> photos;
  const _PhotoRow(this.label, this.photos);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.7)),
    const SizedBox(height: 8),
    PhotoGalleryWidget(photos: photos),
  ]);
}

// ── Vital chip ────────────────────────────────────────────────────────────────
class _VitalChip extends StatelessWidget {
  final String label, value;
  const _VitalChip(this.label, this.value);

  static const _icons = <String, IconData>{
    'BP': Icons.favorite_outline, 'Pulse': Icons.monitor_heart_outlined,
    'Temp': Icons.thermostat_outlined, 'SpO₂': Icons.air_outlined,
    'Weight': Icons.scale_outlined, 'Height': Icons.height_outlined,
  };
  static const _colors = <String, Color>{
    'BP': _kP1, 'Pulse': _kRed, 'Temp': _kAmber,
    'SpO₂': _kP2, 'Weight': _kGreen, 'Height': Color(0xFF8B5CF6),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors[label] ?? _kP1;
    final ico = _icons[label] ?? Icons.analytics_outlined;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(ico, size: 14, color: c),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.w600)),
        const SizedBox(height: 1),
        Text(value, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
