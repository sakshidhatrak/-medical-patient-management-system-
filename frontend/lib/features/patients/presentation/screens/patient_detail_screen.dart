// ─────────────────────────────────────────────────────────────────────────────
// patient_detail_screen.dart  –  MediManage Patient Dashboard (Premium)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/patient_entity.dart';
import '../../../surgeries/domain/entities/surgery_entity.dart';
import '../../../surgeries/presentation/providers/surgery_provider.dart';
import '../../../visits/domain/entities/visit_entity.dart';
import '../../../visits/presentation/providers/visit_provider.dart';
import '../providers/patient_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kP1    = Color(0xFF7C3AED);
const _kP2    = Color(0xFF3B82F6);
const _kRed   = Color(0xFFEF4444);
const _kRed2  = Color(0xFFFEE2E2);
const _kGreen = Color(0xFF10B981);
const _kAmber = Color(0xFFF59E0B);
const _kBg    = Color(0xFFF8FAFC);
const _kNavy  = Color(0xFF0F172A);
const _kSlate = Color(0xFF475569);
const _kMuted = Color(0xFF94A3B8);
const _kBorder= Color(0xFFE2E8F0);

class PatientDashboardScreen extends ConsumerWidget {
  final String patientId;
  const PatientDashboardScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientByIdProvider(patientId));
    final visits       = ref.watch(visitsProvider(patientId));
    final surgeries    = ref.watch(surgeriesProvider(patientId));

    return patientAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: _kP1))),
      error:   (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data:    (patient) {
        if (patient == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Patient not found')));
        }

        final timeline = <_Event>[
          ...visits
              .where((v) =>
                  v.complaints?.isNotEmpty == true ||
                  v.examination?.isNotEmpty == true ||
                  v.clinicalImpression?.isNotEmpty == true ||
                  v.plan?.isNotEmpty == true ||
                  v.notes?.isNotEmpty == true)
              .map((v) => _Event(
                id: v.id,
                date: v.visitDate,
                type: 'visit',
                title: 'OPD Visit',
                summary: v.complaints?.isNotEmpty == true
                    ? v.complaints! : v.clinicalImpression ?? '',
                status: v.status,
              )),
          ...surgeries
              .where((s) =>
                  s.procedure?.isNotEmpty == true ||
                  s.preOpDiagnosis?.isNotEmpty == true ||
                  s.postOpPlan?.isNotEmpty == true)
              .map((s) => _Event(
                id: s.id,
                date: s.surgeryDate,
                type: 'surgery',
                title: 'Surgery',
                summary: s.procedure ?? s.preOpDiagnosis ?? '',
                status: s.status,
              )),
        ]..sort((a, b) => b.date.compareTo(a.date));

        final lastEvent = timeline.isNotEmpty ? timeline.first : null;

        return Scaffold(
          backgroundColor: _kBg,
          body: CustomScrollView(
            slivers: [
              // ── Hero sliver app bar ────────────────────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: _kP1,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 17),
                  onPressed: () => context.go('/patients'),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => context.push('/patients/$patientId/edit'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, size: 22),
                    onPressed: () {},
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _PatientHeroBg(
                    patient: patient,
                    totalVisits: visits.length,
                    totalSurgeries: surgeries.length,
                    lastEvent: lastEvent,
                  ),
                ),
              ),

              // ── Quick actions ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _QuickActionRow(patientId: patientId, ref: ref, context: context),
                ),
              ),

              // ── Timeline header ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_kP1, _kP2]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.timeline_rounded, color: Colors.white, size: 15),
                    ),
                    const SizedBox(width: 10),
                    const Text('Clinical Timeline',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _kNavy)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kP1.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${timeline.length} encounter${timeline.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 11, color: _kP1, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ),
              ),

              // ── Timeline entries ───────────────────────────────
              if (timeline.isEmpty)
                SliverToBoxAdapter(child: _EmptyTimeline())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _TimelineCard(
                        event: timeline[i],
                        isFirst: i == 0,
                        isLast: i == timeline.length - 1,
                        onTap: () {
                          if (timeline[i].type == 'visit') {
                            context.push('/patients/$patientId/visits/${timeline[i].id}');
                          } else {
                            context.push('/patients/$patientId/surgeries/${timeline[i].id}');
                          }
                        },
                      ),
                      childCount: timeline.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero background in SliverAppBar
// ─────────────────────────────────────────────────────────────────────────────
class _PatientHeroBg extends StatelessWidget {
  final PatientEntity patient;
  final int totalVisits, totalSurgeries;
  final _Event? lastEvent;

  const _PatientHeroBg({
    required this.patient,
    required this.totalVisits,
    required this.totalSurgeries,
    this.lastEvent,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6D28D9), Color(0xFF2563EB)],
      ),
    ),
    child: Stack(children: [
      // Decorative circles
      Positioned(right: -30, top: 30, child: _GlassOrb(120, 0.08)),
      Positioned(left: -20, bottom: 0, child: _GlassOrb(100, 0.05)),

      // Content
      Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 56,
          left: 20, right: 20, bottom: 20,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(patient.initials,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(patient.fullName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20,
                        letterSpacing: -0.3)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (patient.ageSex.isNotEmpty) _HeroPill(patient.ageSex, Icons.person_outline),
                  _HeroPill('UHID: ${patient.prn}', Icons.badge_outlined),
                  if (patient.phone?.isNotEmpty == true) _HeroPill(patient.phone!, Icons.phone_outlined),
                ]),
              ]),
            ),
          ]),

          const SizedBox(height: 18),

          // Stats row
          Row(children: [
            _HeroStat(icon: Icons.medical_services_outlined, label: 'Visits',
                value: '$totalVisits', color: Colors.blue[200]!),
            const SizedBox(width: 10),
            _HeroStat(icon: Icons.local_hospital_outlined, label: 'Surgeries',
                value: '$totalSurgeries', color: Colors.red[200]!),
            if (lastEvent != null) ...[
              const SizedBox(width: 10),
              _HeroStat(icon: Icons.schedule_outlined, label: 'Last seen',
                  value: _shortDate(lastEvent!.date), color: Colors.green[200]!),
            ],
          ]),
        ]),
      ),
    ]),
  );

  String _shortDate(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return DateFormat('dd MMM').format(d);
  }
}

class _GlassOrb extends StatelessWidget {
  final double size;
  final double opacity;
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

class _HeroPill extends StatelessWidget {
  final String text;
  final IconData icon;
  const _HeroPill(this.text, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.8)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _HeroStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick action row
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionRow extends StatelessWidget {
  final String patientId;
  final WidgetRef ref;
  final BuildContext context;
  const _QuickActionRow({required this.patientId, required this.ref, required this.context});

  @override
  Widget build(BuildContext ctx) => Row(children: [
    Expanded(
      child: _ActionBtn(
        icon: Icons.add_circle_rounded,
        label: 'New Visit',
        sub: 'OPD consultation',
        color1: _kP1,
        color2: _kP2,
        onTap: () async {
          final visit = await ref.read(visitsProvider(patientId).notifier)
              .createVisit(patientId: patientId);
          if (visit != null && context.mounted) {
            context.push('/patients/$patientId/visits/${visit.id}');
          }
        },
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _ActionBtn(
        icon: Icons.local_hospital_rounded,
        label: 'New Surgery',
        sub: 'Operative note',
        color1: const Color(0xFFDC2626),
        color2: _kRed,
        onTap: () async {
          final surgery = await ref.read(surgeriesProvider(patientId).notifier)
              .createSurgery(patientId: patientId);
          if (surgery != null && context.mounted) {
            context.push('/patients/$patientId/surgeries/${surgery.id}');
          }
        },
      ),
    ),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color1, color2;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon, required this.label, required this.sub,
    required this.color1, required this.color2, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color1, color2]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color1.withValues(alpha: 0.3),
            blurRadius: 16, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            Text(sub,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
          ]),
        ),
        Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.6), size: 14),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline card
// ─────────────────────────────────────────────────────────────────────────────
class _Event {
  final String id, type, title, summary, status;
  final DateTime date;
  const _Event({
    required this.id, required this.date, required this.type,
    required this.title, required this.summary, required this.status,
  });
}

class _TimelineCard extends StatelessWidget {
  final _Event event;
  final bool isFirst, isLast;
  final VoidCallback onTap;
  const _TimelineCard({
    required this.event, required this.isFirst,
    required this.isLast, required this.onTap,
  });

  Color get _color => event.type == 'visit' ? _kP1 : _kRed;
  Color get _lightColor => event.type == 'visit'
      ? const Color(0xFFEDE9FE) : const Color(0xFFFEE2E2);

  @override
  Widget build(BuildContext context) {
    final dateStr = _fmt(event.date);
    final timeStr = DateFormat('h:mm a').format(event.date);
    final isDraft = event.status == 'draft';

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Spine
        SizedBox(
          width: 48,
          child: Column(children: [
            if (!isFirst)
              Expanded(child: Center(child: Container(width: 2, color: _kBorder)))
            else
              const SizedBox(height: 6),

            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_color, event.type == 'visit' ? _kP2 : const Color(0xFFF87171)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(
                event.type == 'visit'
                    ? Icons.medical_services_outlined
                    : Icons.local_hospital_outlined,
                color: Colors.white, size: 16,
              ),
            ),

            if (!isLast)
              Expanded(child: Center(child: Container(width: 2, color: _kBorder)))
            else
              const SizedBox(height: 6),
          ]),
        ),

        const SizedBox(width: 12),

        // Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFirst ? _color.withValues(alpha: 0.3) : _kBorder,
                    width: isFirst ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isFirst ? _color.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: _lightColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_color, event.type == 'visit' ? _kP2 : const Color(0xFFF87171)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(event.title.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                      ),
                      if (isDraft) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kAmber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
                          ),
                          child: const Text('DRAFT',
                              style: TextStyle(fontSize: 9, color: _kAmber, fontWeight: FontWeight.w800)),
                        ),
                      ],
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(dateStr,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kSlate)),
                        Text(timeStr, style: const TextStyle(fontSize: 10, color: _kMuted)),
                      ]),
                      const SizedBox(width: 6),
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                        child: Icon(Icons.chevron_right, color: _kMuted, size: 16),
                      ),
                    ]),
                  ),

                  // Body
                  if (event.summary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Text(
                        event.summary,
                        style: const TextStyle(fontSize: 13, color: _kSlate, height: 1.45),
                        maxLines: 3, overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Text('Tap to view details',
                          style: const TextStyle(fontSize: 12, color: _kMuted, fontStyle: FontStyle.italic)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  String _fmt(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(d);
    if (d.year == DateTime.now().year) return DateFormat('dd MMM').format(d);
    return DateFormat('dd MMM yyyy').format(d);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty timeline
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyTimeline extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
    child: Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kP1.withValues(alpha: 0.1), _kP2.withValues(alpha: 0.1)],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.timeline_outlined, size: 36, color: _kP1.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 18),
        const Text('No encounters yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: _kNavy)),
        const SizedBox(height: 8),
        const Text('Start with a New Visit or New Surgery above',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kMuted, fontSize: 13)),
      ]),
    ),
  );
}
