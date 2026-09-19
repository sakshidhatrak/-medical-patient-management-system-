import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../services/pdf_export_service.dart';
import '../providers/print_config_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kNavy       = Color(0xFF1A2D5A);
const _kMaroon     = Color(0xFF7B1F2E);
const _kCream      = Color(0xFFF0EDE6);
const _kDot        = Color(0xFFBBBBBB);
const _kBorder     = Color(0xFFDDDDDD);
const _kSub        = Color(0xFF888888);
const _kHeaderBlue   = Color(0xFFDEEDF8);
const _kClinicRed    = Color(0xFFC41230);
const _kSpecBlue     = Color(0xFF1A5276);
const _kSidebarRed   = Color(0xFFE53935);
const _kSidebarCream = Color(0xFFF0EAD2);

// ── Approved specialties list ─────────────────────────────────────────────────

const _kSpecialties = [
  'Brain and Spine Injury',
  'Vascular Neurosurgery',
  'Brain tumors',
  'Spine tumors',
  'Pediatric Neurosurgery',
  'Degenerative spine disease',
  'Spondylosis',
  'Slip disc',
  'Cranio-Vertebral junction abnormality',
  'Root or epidural block',
  'Endoscopic skull base surgery',
  'Hydrocephalus',
  'Minimally invasive spine surgery',
];

// ── Section specification model ───────────────────────────────────────────────

class _S {
  final String title;
  final IconData icon;
  final List<(String, String)> fields; // (label, dataKey)
  final bool rxIcon;
  const _S(this.title, this.icon, this.fields, {this.rxIcon = false});
}

final _kSectionDefs = <_S>[
  _S('PATIENT CONTACT & ID', Icons.contact_phone_outlined, [
    ('Phone', 'phone'),
    ('Alt Phone', 'altPhone'),
    ('Email', 'email'),
    ('Address', 'address'),
    ('ID Type', 'idProofType'),
    ('ID No.', 'idProofNumber'),
  ]),
  _S('KNOWN ALLERGIES', Icons.warning_amber_rounded, [
    ('Known Allergies', 'allergies'),
  ]),
  _S('CHIEF COMPLAINT', Icons.report_problem_outlined, [
    ('Chief Complaint', 'chiefComplaint'),
  ]),
  _S('PREVIOUS HISTORY', Icons.history_edu_outlined, [
    ('Previous History', 'previousHistory'),
  ]),
  _S('EXAMINATION FINDING', Icons.search_outlined, [
    ('Weight', 'weight'),
    ('Blood Pressure', 'bloodPressure'),
    ('Temperature', 'temperature'),
    ('General Examination', 'examGeneral'),
    ('Neurological Examination', 'examNeurological'),
  ]),
  _S('PREVIOUS INVESTIGATIONS', Icons.description_outlined, [
    ('Imaging', 'imaging'),
    ('Other Investigations', 'otherInvestigation'),
  ]),
  _S('IMPRESSION', Icons.lightbulb_outline_rounded, [
    ('Clinical Diagnosis', 'clinicalDiagnosis'),
    ('Impression', 'diagnosis'),
  ]),
  _S('TREATMENT PLAN', Icons.assignment_turned_in_outlined, [
    ('Treatment Plan', 'treatmentPlan'),
  ]),
  _S('MEDICINE / TREATMENT', Icons.medication_outlined, [
    ('Medicine / Treatment', 'medications'),
  ], rxIcon: true),
  _S('ADVICE', Icons.health_and_safety_outlined, [
    ('Instructions', 'advice'),
    ('Investigation Should be done', 'investigationToBeDone'),
    ('Cross Consultation', 'crossConsultation'),
  ]),
];

// ── Shell ─────────────────────────────────────────────────────────────────────

class PreviewRightPanel extends ConsumerWidget {
  const PreviewRightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ReportScreen();
  }
}

// ── Main scrollable report screen ─────────────────────────────────────────────

class _ReportScreen extends ConsumerStatefulWidget {
  const _ReportScreen();

  @override
  ConsumerState<_ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<_ReportScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final data   = ref.watch(effectivePatientDataProvider);
    final config = ref.watch(printConfigProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Approved letterhead header ────────────────────────────────
            _LetterheadHeader(data: data),
            // ── Body: specialty sidebar + right content ───────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left specialty sidebar
                const _SpecialtySidebar(),
                // Right content area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      // ── Customize fields bar ──────────────────────────────
                      _CustomizeBar(data: data, config: config),
                      const SizedBox(height: 8),
                      // ── Report sections ───────────────────────────────────
                      ..._buildSections(config, data),
                      const SizedBox(height: 10),
                      // ── Footer ────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _FooterCard(data: data),
                      ),
                      const SizedBox(height: 14),
                      // ── Save button ───────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _SaveButton(
                          saving: _saving,
                          onTap: () => _export(config),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldListWidget(
      PrintConfigState c, Map<String, String> d,
      List<(String, String)> pairs) {
    final filled = pairs
        .where((p) =>
            c.enabledFieldIds.contains(p.$2) &&
            (d[p.$2] ?? '').isNotEmpty &&
            d[p.$2] != '—')
        .toList();
    if (filled.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dot(),
          const SizedBox(height: 8),
          _dot(),
          const SizedBox(height: 8),
          _dot(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < filled.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Text(
            filled[i].$1,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: _kSub,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            d[filled[i].$2]!,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  bool _sectionHasData(PrintConfigState c, Map<String, String> d,
      List<(String, String)> fields) {
    return fields.any((f) =>
        c.enabledFieldIds.contains(f.$2) &&
        (d[f.$2] ?? '').isNotEmpty &&
        d[f.$2] != '—');
  }

  List<Widget> _buildSections(PrintConfigState c, Map<String, String> d) {
    final result = <Widget>[];

    void addFull(_S s) {
      if (!_sectionHasData(c, d, s.fields)) return;
      if (result.isNotEmpty) result.add(const SizedBox(height: 8));
      result.add(_SectionCard(
        icon: s.icon,
        title: s.title,
        rxIcon: s.rxIcon,
        contentWidget: _fieldListWidget(c, d, s.fields),
      ));
    }

    void addPaired(_S left, _S right) {
      final hasL = _sectionHasData(c, d, left.fields);
      final hasR = _sectionHasData(c, d, right.fields);
      if (!hasL && !hasR) return;
      if (result.isNotEmpty) result.add(const SizedBox(height: 8));
      if (hasL && hasR) {
        result.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SectionCard(
                    icon: left.icon,
                    title: left.title,
                    rxIcon: left.rxIcon,
                    contentWidget: _fieldListWidget(c, d, left.fields),
                    noPadding: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SectionCard(
                    icon: right.icon,
                    title: right.title,
                    contentWidget: _fieldListWidget(c, d, right.fields),
                    noPadding: true,
                  ),
                ),
              ],
            ),
          ),
        ));
      } else if (hasL) {
        result.add(_SectionCard(
          icon: left.icon,
          title: left.title,
          rxIcon: left.rxIcon,
          contentWidget: _fieldListWidget(c, d, left.fields),
        ));
      } else {
        result.add(_SectionCard(
          icon: right.icon,
          title: right.title,
          contentWidget: _fieldListWidget(c, d, right.fields),
        ));
      }
    }

    addFull(_kSectionDefs[0]);  // Patient Contact & ID
    addFull(_kSectionDefs[1]);  // Known Allergies
    addFull(_kSectionDefs[2]);  // Chief Complaint
    addFull(_kSectionDefs[3]);  // Previous History
    addFull(_kSectionDefs[4]);  // Examination Finding
    addFull(_kSectionDefs[5]);  // Previous Investigations
    addFull(_kSectionDefs[6]);  // Impression
    addFull(_kSectionDefs[7]);  // Treatment Plan
    addFull(_kSectionDefs[8]);  // Medicine / Treatment
    addFull(_kSectionDefs[9]);  // Advice

    return result;
  }

  Future<void> _export(PrintConfigState config) async {
    setState(() => _saving = true);
    try {
      await PdfExportService.exportPdf(
        config,
        patientData: ref.read(activePatientDataProvider),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Approved letterhead header ────────────────────────────────────────────────

class _LetterheadHeader extends StatelessWidget {
  final Map<String, String> data;
  const _LetterheadHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = [data['firstName'] ?? '', data['lastName'] ?? '']
        .where((s) => s.isNotEmpty && s != '—').join(' ');
    final date = data['date'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Letterhead header with dot-pattern background ─────────────
        Stack(
          children: [
            Positioned.fill(child: Container(color: _kHeaderBlue)),
            Positioned.fill(
                child: CustomPaint(painter: const _HeaderDotPainter())),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: clinic branding + logo
                SizedBox(
                  width: 165,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 8, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'The Brain & Spine Clinic',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: _kClinicRed,
                            letterSpacing: 0.3,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Excellence, Ethics, Efficiency',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: _kClinicRed,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 115,
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.local_hospital,
                              size: 80,
                              color: _kNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Vertical divider
                Container(width: 1, color: Colors.grey.shade400),
                // Right: doctor credentials – centered
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Dr. Harshal S. Chaudhari',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: _kNavy,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Divider(height: 1, thickness: 0.8, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text(
                          'Brain and Spine surgeon/ Neurosurgeon',
                          style: TextStyle(fontSize: 10.5, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const Text(
                          'M.B.B.S., M.S. General Surgery',
                          style: TextStyle(fontSize: 10.5, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const Text(
                          '(K.E.M. Hospital, Mumbai)',
                          style: TextStyle(fontSize: 10.5, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const Text(
                          'M.Ch. Neurosurgery (G.M.C., Goa)',
                          style: TextStyle(fontSize: 10.5, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const Text(
                          'Fellow in Neurosurgical Oncology (Tata Memorial Hospital)',
                          style: TextStyle(fontSize: 10.5, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.language, size: 11, color: _kNavy),
                            SizedBox(width: 3),
                            Text(
                              'www.drharshalchaudhari.com',
                              style: TextStyle(fontSize: 10, color: _kNavy),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // ── Separator ─────────────────────────────────────────────────
        Container(height: 1, color: Colors.grey.shade400),
        // ── Patient Name + Date row ───────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Text(
                'Patient Name : ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: name.isNotEmpty
                    ? Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700))
                    : Container(height: 0.8, color: Colors.black45),
              ),
              const SizedBox(width: 8),
              const Text(
                'Date : ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
              SizedBox(
                width: 82,
                child: date.isNotEmpty
                    ? Text(date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11))
                    : Container(height: 0.8, color: Colors.black45),
              ),
            ],
          ),
        ),
        Container(height: 1, color: Colors.grey.shade400),
      ],
    );
  }
}

// ── Specialty sidebar ─────────────────────────────────────────────────────────

class _SpecialtySidebar extends StatelessWidget {
  const _SpecialtySidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      decoration: BoxDecoration(
        color: _kSidebarCream,
        border: Border(
          left: const BorderSide(color: _kSidebarRed, width: 5),
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _kSpecialties
            .map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s,
                        style: const TextStyle(
                          fontSize: 9,
                          color: _kSpecBlue,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(height: 0.8, color: _kSpecBlue),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final Widget? contentWidget;
  final bool rxIcon;
  final bool noPadding;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.contentWidget,
    this.rxIcon = false,
    this.noPadding = false,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Navy circle icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: _kNavy,
                      shape: BoxShape.circle,
                    ),
                    child: widget.rxIcon
                        ? const Center(
                            child: Text(
                              'Rx',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Icon(widget.icon,
                            size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _kNavy,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Content
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: widget.contentWidget ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _dot(),
                      const SizedBox(height: 8),
                      _dot(),
                      const SizedBox(height: 8),
                      _dot(),
                    ],
                  ),
            ),
        ],
      ),
    );

    if (widget.noPadding) return card;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: card,
    );
  }
}

// ── Footer card ───────────────────────────────────────────────────────────────

class _FooterCard extends StatelessWidget {
  final Map<String, String> data;
  const _FooterCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 360,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Signature + credentials
              SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harshal',
                      style: TextStyle(
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        color: _kNavy,
                      ),
                    ),
                    Container(height: 0.8, width: 90, color: Colors.black38),
                    const SizedBox(height: 4),
                    const Text('Dr. Harshal S. Chaudhari',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    const Text('Neurosurgeon (Brain & Spine)',
                        style: TextStyle(fontSize: 8)),
                    const Text('MBBS, MS Gen Surg (KEM)',
                        style: TextStyle(fontSize: 7.5, color: _kSub)),
                    const Text('MCh Neurosurgery (GMC, Goa)',
                        style: TextStyle(fontSize: 7.5, color: _kSub)),
                    const Text('Fellow Neuro-Oncology (TMH)',
                        style: TextStyle(fontSize: 7.5, color: _kSub)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Logo
              SizedBox(
                width: 90,
                child: Center(
                  child: SizedBox(
                    width: 80,
                    height: 90,
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.local_hospital, size: 50, color: _kNavy),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Follow up
              SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FOLLOW UP / REVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: _kNavy),
                      const SizedBox(width: 4),
                      const Text('Next Visit on : ',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: _kNavy)),
                      Expanded(child: Container(height: 0.8, color: _kNavy)),
                    ]),
                    const SizedBox(height: 14),
                    const Text(
                      'NOTES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _dot(),
                    const SizedBox(height: 8),
                    _dot(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Save Report button ────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onTap;
  const _SaveButton({required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kNavy,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: saving ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'SAVE REPORT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Customize bar ─────────────────────────────────────────────────────────────

class _CustomizeBar extends StatelessWidget {
  final Map<String, String> data;
  final PrintConfigState config;
  const _CustomizeBar({required this.data, required this.config});

  @override
  Widget build(BuildContext context) {
    final total   = _kSectionDefs.fold<int>(0, (s, e) => s + e.fields.length);
    final enabled = config.enabledFieldIds.length.clamp(0, total);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => FieldConfigPage(patientData: data),
          ),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _kNavy,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.tune_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Customize Report Fields',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kNavy,
                  ),
                ),
              ),
              Text(
                '$enabled / $total selected',
                style: const TextStyle(fontSize: 11, color: _kSub),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 18, color: _kSub),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Field Configuration Page (full-screen) ───────────────────────────────────

const kFieldCfgPageBg  = Color(0xFFF0F3FF);
const kFieldCfgIconBg  = Color(0xFFE8ECFF);
const kFieldCfgNavy    = Color(0xFF1A237E);

// ignore: library_private_types_in_public_api (intentional — used by PrintConfigScreen)
const _kPageBg  = kFieldCfgPageBg;
const _kIconBg  = kFieldCfgIconBg;
const _kPrimNvy = kFieldCfgNavy;

class FieldConfigPage extends ConsumerStatefulWidget {
  final Map<String, String> patientData;
  const FieldConfigPage({super.key, required this.patientData});

  @override
  ConsumerState<FieldConfigPage> createState() => _FieldConfigPageState();
}

class _FieldConfigPageState extends ConsumerState<FieldConfigPage> {
  final Set<int> _expanded = {};
  bool _saving = false;
  bool _printing = false;

  @override
  Widget build(BuildContext context) {
    final enabled  = ref.watch(printConfigProvider).enabledFieldIds;
    final notifier = ref.read(printConfigProvider.notifier);
    final botPad   = MediaQuery.of(context).padding.bottom;

    // Count total & enabled across filled fields only
    final allFilled = _kSectionDefs
        .expand((s) => s.fields)
        .where((f) =>
            (widget.patientData[f.$2] ?? '').isNotEmpty &&
            widget.patientData[f.$2] != '—')
        .toList();
    final totalCount   = allFilled.length;
    final enabledCount = allFilled.where((f) => enabled.contains(f.$2)).length;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4B55CC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 17),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Report Preview',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () => notifier.reset(),
            child: Text(
              'Reset All',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Scrollable section list ──────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                // Section cards — only show sections that have actual data
                for (int i = 0; i < _kSectionDefs.length; i++)
                  Builder(builder: (ctx) {
                    final s = _kSectionDefs[i];
                    final filled = s.fields
                        .where((f) =>
                            (widget.patientData[f.$2] ?? '').isNotEmpty &&
                            widget.patientData[f.$2] != '—')
                        .toList();
                    if (filled.isEmpty) return const SizedBox.shrink();
                    return _SectionConfigCard(
                      key: ValueKey(i),
                      section: s,
                      filledFields: filled,
                      enabled: enabled,
                      isExpanded: _expanded.contains(i),
                      patientData: widget.patientData,
                      onToggleExpand: () => setState(() {
                        if (_expanded.contains(i)) {
                          _expanded.remove(i);
                        } else {
                          _expanded.add(i);
                        }
                      }),
                      onToggleSection: (val) {
                        for (final f in filled) {
                          final isOn = enabled.contains(f.$2);
                          if (val && !isOn) notifier.toggleField(f.$2);
                          if (!val && isOn) notifier.toggleField(f.$2);
                        }
                      },
                      onToggleField: notifier.toggleField,
                    );
                  }),
              ],
            ),
          ),
          // ── Bottom action bar ─────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + botPad),
            decoration: BoxDecoration(
              color: context.cardColor,
              border: Border(top: BorderSide(color: context.borderColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Cancel — text only
                TextButton(
                  onPressed: (_saving || _printing)
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4B55CC),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                // Print
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_saving || _printing) ? null : _print,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B55CC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _printing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print_rounded, size: 16),
                              SizedBox(width: 5),
                              Text('PRINT',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Save
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_saving || _printing) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B55CC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded, size: 16),
                              SizedBox(width: 5),
                              Text('SAVE',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await PdfExportService.exportPdf(
        ref.read(printConfigProvider),
        patientData: ref.read(activePatientDataProvider),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await PdfExportService.printReport(
        ref.read(printConfigProvider),
        patientData: ref.read(activePatientDataProvider),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

// ── Summary header card ───────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final int enabledCount;
  final int totalCount;
  const _SummaryHeader({required this.enabledCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    final pct = totalCount > 0
        ? (enabledCount / totalCount * 100).round()
        : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4B55CC), Color(0xFF353FBB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4B55CC).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Report Fields',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$enabledCount of $totalCount fields enabled',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                'included',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Field tile grid — 2-per-row for short values, full-width for long ─────────

class _FieldTileGrid extends StatelessWidget {
  final List<(String, String)> filledFields;
  final Set<String> enabled;
  final Map<String, String> patientData;
  final ValueChanged<String> onToggleField;

  const _FieldTileGrid({
    required this.filledFields,
    required this.enabled,
    required this.patientData,
    required this.onToggleField,
  });

  static const _kBlue = Color(0xFF4B55CC);

  bool _isLong(String value) => value.length > 40 || value.contains('\n');

  @override
  Widget build(BuildContext context) {
    // Pair up short fields; long fields get their own full-width row
    final rows = <List<(String, String)>>[];
    int i = 0;
    while (i < filledFields.length) {
      final f     = filledFields[i];
      final val   = patientData[f.$2] ?? '';
      final long  = _isLong(val);
      if (long) {
        rows.add([f]);
        i++;
      } else if (i + 1 < filledFields.length) {
        final next    = filledFields[i + 1];
        final nextVal = patientData[next.$2] ?? '';
        if (_isLong(nextVal)) {
          rows.add([f]);
          i++;
        } else {
          rows.add([f, next]);
          i += 2;
        }
      } else {
        rows.add([f]);
        i++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.asMap().entries.map((entry) {
        final rowIdx = entry.key;
        final row    = entry.value;
        return Padding(
          padding: EdgeInsets.only(top: rowIdx == 0 ? 0 : 8),
          child: row.length == 2
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Tile(
                      f: row[0], enabled: enabled,
                      patientData: patientData,
                      onToggle: onToggleField,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _Tile(
                      f: row[1], enabled: enabled,
                      patientData: patientData,
                      onToggle: onToggleField,
                    )),
                  ],
                )
              : _Tile(
                  f: row[0], enabled: enabled,
                  patientData: patientData,
                  onToggle: onToggleField,
                ),
        );
      }).toList(),
    );
  }
}

class _Tile extends StatelessWidget {
  final (String, String) f;
  final Set<String> enabled;
  final Map<String, String> patientData;
  final ValueChanged<String> onToggle;

  const _Tile({
    required this.f,
    required this.enabled,
    required this.patientData,
    required this.onToggle,
  });

  static const _kBlue = Color(0xFF4B55CC);

  @override
  Widget build(BuildContext context) {
    final isOn    = enabled.contains(f.$2);
    final value   = patientData[f.$2] ?? '';
    final hasVal  = value.isNotEmpty && value != '—';
    final isLong  = value.length > 40 || value.contains('\n');

    return GestureDetector(
      onTap: () => onToggle(f.$2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOn
                ? _kBlue.withValues(alpha: 0.4)
                : context.borderColor,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox + label
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isOn ? _kBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isOn ? _kBlue : context.borderColor,
                      width: 1.5,
                    ),
                  ),
                  child: isOn
                      ? const Icon(Icons.check_rounded,
                          size: 10, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    f.$1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isOn ? _kBlue : context.textSecondary,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Value card
            if (hasVal) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isOn
                      ? Colors.white.withValues(alpha: 0.75)
                      : context.cardColor,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isOn
                        ? _kBlue.withValues(alpha: 0.15)
                        : context.borderColor,
                  ),
                ),
                child: Text(
                  value,
                  maxLines: isLong ? 4 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isOn
                        ? context.textPrimary
                        : context.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Info header card ──────────────────────────────────────────────────────────

class _CfgInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kIconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded, color: _kPrimNvy, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customize Report Fields',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kPrimNvy,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Select the sections you want to include in the report',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section config card — modern floating card with gradient icon + progress ───

class _SectionConfigCard extends StatelessWidget {
  final _S section;
  final List<(String, String)> filledFields;
  final Set<String> enabled;
  final bool isExpanded;
  final Map<String, String> patientData;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onToggleSection;
  final ValueChanged<String> onToggleField;

  const _SectionConfigCard({
    super.key,
    required this.section,
    required this.filledFields,
    required this.enabled,
    required this.isExpanded,
    required this.patientData,
    required this.onToggleExpand,
    required this.onToggleSection,
    required this.onToggleField,
  });

  static const _kBlue  = Color(0xFF4B55CC);
  static const _kGreen = Color(0xFF22C55E);
  static const _kAmber = Color(0xFFF59E0B);

  static const _iconGradients = [
    [Color(0xFF4B55CC), Color(0xFF6B75EC)],
    [Color(0xFF4B55CC), Color(0xFF6B75EC)],
    [Color(0xFF4B55CC), Color(0xFF6B75EC)],
    [Color(0xFF4B55CC), Color(0xFF6B75EC)],
    [Color(0xFF4B55CC), Color(0xFF6B75EC)],
    [Color(0xFF4B55CC), Color(0xFF6B75EC)],
    [Color(0xFF4B55CC), Color(0xFF6B75EC)],
    [Color(0xFF4B55CC), Color(0xFF6B75EC)],
    [Color(0xFF4B55CC), Color(0xFF6B75EC)],
    [Color(0xFF4B55CC), Color(0xFF6B75EC)],
  ];

  String _toTitleCase(String s) => s.split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      }).join(' ');

  @override
  Widget build(BuildContext context) {
    final allOn = filledFields.every((f) => enabled.contains(f.$2));
    final anyOn = filledFields.any((f)  => enabled.contains(f.$2));
    final count = filledFields.where((f) => enabled.contains(f.$2)).length;
    final total = filledFields.length;
    final pct   = total > 0 ? count / total : 0.0;

    final sIdx = _kSectionDefs.indexOf(section) % _iconGradients.length;
    final grad = _iconGradients[sIdx < 0 ? 0 : sIdx];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: allOn
                  ? _kBlue.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────
              InkWell(
                onTap: onToggleExpand,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(16),
                  bottom: Radius.circular(isExpanded ? 0 : 16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Circular icon
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: grad,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: section.rxIcon
                                ? const Center(
                                    child: Text(
                                      'Rx',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(section.icon,
                                    color: Colors.white, size: 17),
                          ),
                          const SizedBox(width: 13),
                          // Title + status text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _toTitleCase(section.title),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  allOn
                                      ? 'All $total fields included'
                                      : anyOn
                                          ? '$count of $total fields selected'
                                          : 'No fields included',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: anyOn
                                        ? _kBlue
                                        : context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Toggle switch
                          Transform.scale(
                            scale: 0.85,
                            child: Switch(
                              value: allOn,
                              onChanged: onToggleSection,
                              activeColor: Colors.white,
                              activeTrackColor: _kBlue,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: context.textDisabled,
                              trackOutlineColor:
                                  WidgetStateProperty.all(Colors.transparent),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          // Animated chevron
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: context.textSecondary,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      // ── Progress bar ───────────────────────────────────
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Container(
                                height: 4,
                                color: const Color(0xFFF3F4F6)),
                            AnimatedFractionallySizedBox(
                              duration: const Duration(milliseconds: 300),
                              widthFactor: pct,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: grad,
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Expanded field tiles ─────────────────────────────────
              if (isExpanded) ...[
                Divider(height: 1, thickness: 0.5, color: context.borderColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: _FieldTileGrid(
                    filledFields: filledFields,
                    enabled: enabled,
                    patientData: patientData,
                    onToggleField: onToggleField,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mini medicine table for Customize Report screen ───────────────────────────

class _MedsMiniTable extends StatelessWidget {
  final String raw;
  final bool isEnabled;
  const _MedsMiniTable({required this.raw, required this.isEnabled});

  List<List<String>> _parse() {
    return raw.split('\n').where((l) => l.trim().isNotEmpty).map((line) {
      // Extract special instruction first (anything after last " | ")
      final pipeIdx = line.lastIndexOf(' | ');
      final lineMain = pipeIdx >= 0 ? line.substring(0, pipeIdx).trim() : line;
      final specialInstruction = pipeIdx >= 0 ? line.substring(pipeIdx + 3).trim() : '';
      final doseMatch   = RegExp(r'\[([^\]]+)\]').firstMatch(lineMain);
      final dose        = doseMatch?.group(1) ?? '';
      final withoutDose = lineMain.replaceFirst(doseMatch?.group(0) ?? '', '').trim();
      final routeMatch  = RegExp(r'\(([^)]+)\)').firstMatch(withoutDose);
      final route       = routeMatch?.group(1) ?? '';
      final withoutRoute = withoutDose.replaceFirst(routeMatch?.group(0) ?? '', '').trim();
      final dashIdx  = withoutRoute.indexOf(' - ');
      final medicine = dashIdx >= 0 ? withoutRoute.substring(0, dashIdx).trim() : withoutRoute;
      final right    = dashIdx >= 0 ? withoutRoute.substring(dashIdx + 3).trim() : '';
      final mulIdx   = right.indexOf(' × ');
      final frequency = mulIdx >= 0 ? right.substring(0, mulIdx).trim() : right;
      final duration  = mulIdx >= 0 ? right.substring(mulIdx + 3).trim() : '';
      return [medicine, dose, route, frequency, duration, specialInstruction];
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _parse();
    if (rows.isEmpty) return const SizedBox.shrink();

    const headers = ['Medicine', 'Dose', 'Route', 'Freq', 'Duration'];
    final dimColor = isEnabled ? context.textSecondary : context.textDisabled;
    final textColor = isEnabled ? context.textPrimary : context.textDisabled;
    final borderColor = isEnabled ? context.borderColor : context.dividerColor;

    Widget cell(String t, {bool isHeader = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            t.isEmpty ? '—' : t,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
              color: isHeader ? dimColor : textColor,
            ),
          ),
        );

    return Table(
      border: TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: const {
        0: FlexColumnWidth(4),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
        4: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: borderColor.withValues(alpha: 0.5)),
          children: headers.map((h) => cell(h, isHeader: true)).toList(),
        ),
        ...rows.map((r) {
          final specialInstruction = r.length > 5 ? r[5] : '';
          return TableRow(
            children: [
              // Medicine cell — includes special instruction if present
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r[0].isEmpty ? '—' : r[0],
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: textColor),
                    ),
                    if (specialInstruction.isNotEmpty)
                      Text(
                        '* $specialInstruction',
                        style: const TextStyle(
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFB07D2A),
                        ),
                      ),
                  ],
                ),
              ),
              ...r.skip(1).take(4).map((v) => cell(v)),
            ],
          );
        }),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _dot() {
  return CustomPaint(
    painter: _DotLinePainter(),
    child: const SizedBox(height: 1),
  );
}

class _HeaderDotPainter extends CustomPainter {
  const _HeaderDotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x407AB8D8)
      ..style = PaintingStyle.fill;
    const spacing = 9.0;
    const radius = 1.5;
    for (var row = 0; row * spacing < size.height + spacing; row++) {
      final offsetX = (row % 2 == 0) ? 0.0 : spacing / 2;
      for (var col = 0; col * spacing < size.width + spacing; col++) {
        canvas.drawCircle(
          Offset(col * spacing + offsetX, row * spacing),
          radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotLinePainter extends CustomPainter {
  const _DotLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _kDot;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 4, 0.9), paint);
      x += 7;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
