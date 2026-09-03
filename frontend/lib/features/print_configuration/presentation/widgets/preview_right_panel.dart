import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
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
  _S('VITALS', Icons.monitor_heart_outlined, [
    ('Weight', 'weight'),
    ('Blood Pressure', 'bloodPressure'),
    ('Temperature', 'temperature'),
  ]),
  _S('KNOWN ALLERGIES', Icons.warning_amber_rounded, [
    ('Allergies', 'allergies'),
  ]),
  _S('PAST MEDICAL HISTORY', Icons.history_outlined, [
    ('Medical History', 'medicalHistory'),
  ]),
  _S('PRESENTING COMPLAINTS & CLINICAL HISTORY', Icons.assignment_outlined, [
    ('Chief Complaint', 'chiefComplaint'),
    ('Previous History', 'previousHistory'),
  ]),
  _S('EXAMINATION FINDINGS', Icons.search_outlined, [
    ('General Examination', 'examGeneral'),
    ('Neurological Examination', 'examNeurological'),
  ]),
  _S('REPORTS', Icons.description_outlined, [
    ('Imaging', 'imaging'),
    ('Other Investigation', 'otherInvestigation'),
  ]),
  _S('ADVICE', Icons.health_and_safety_outlined, [
    ('Advice', 'advice'),
  ]),
  _S('TREATMENT (MEDICINES)', Icons.medication_outlined, [
    ('Medications', 'medications'),
  ], rxIcon: true),
  _S('INVESTIGATIONS', Icons.science_outlined, [
    ('Clinical Diagnosis', 'clinicalDiagnosis'),
    ('Impression', 'diagnosis'),
    ('Treatment Plan', 'treatmentPlan'),
  ]),
  _S('CROSS REFERENCE (OTHER DOCTOR CONSULTATION)', Icons.people_outline, [
    ('Notes', 'notes'),
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

    // Indices match _kSectionDefs order
    addFull(_kSectionDefs[0]);              // Patient Contact & ID
    addPaired(_kSectionDefs[1], _kSectionDefs[2]); // Vitals | Allergies
    addFull(_kSectionDefs[3]);              // Medical History
    addFull(_kSectionDefs[4]);              // Presenting Complaints
    addFull(_kSectionDefs[5]);              // Examination Findings
    addPaired(_kSectionDefs[6], _kSectionDefs[7]); // Reports | Advice
    addPaired(_kSectionDefs[8], _kSectionDefs[9]); // Treatment | Investigations
    addFull(_kSectionDefs[10]);             // Cross Reference

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
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _FieldConfigSheet(data: data),
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

// ── Field configuration bottom sheet ─────────────────────────────────────────

class _FieldConfigSheet extends ConsumerWidget {
  final Map<String, String> data;
  const _FieldConfigSheet({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled  = ref.watch(printConfigProvider).enabledFieldIds;
    final notifier = ref.read(printConfigProvider.notifier);

    return Material(
      color: Colors.transparent,
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                color: _kNavy,
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Customize Report Fields',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => notifier.reset(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('Reset All',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ── Section list ─────────────────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final s in _kSectionDefs) ...[
                      _SectionHeader(section: s, enabled: enabled, notifier: notifier),
                      for (final f in s.fields)
                        _FieldTile(
                          field: f,
                          data: data,
                          enabled: enabled,
                          notifier: notifier,
                        ),
                      const Divider(height: 1, thickness: 0.5),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              // ── Done button ──────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                    16, 10, 16,
                    16 + MediaQuery.of(context).padding.bottom),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNavy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('DONE',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final _S section;
  final Set<String> enabled;
  final PrintConfigNotifier notifier;
  const _SectionHeader(
      {required this.section,
      required this.enabled,
      required this.notifier});

  @override
  Widget build(BuildContext context) {
    final allOn = section.fields.every((f) => enabled.contains(f.$2));
    return Container(
      color: _kCream,
      padding: const EdgeInsets.fromLTRB(16, 9, 8, 9),
      child: Row(
        children: [
          Icon(section.icon, size: 15, color: _kNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              section.title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _kNavy,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: allOn,
              onChanged: (val) {
                for (final f in section.fields) {
                  final isOn = enabled.contains(f.$2);
                  if (val && !isOn) notifier.toggleField(f.$2);
                  if (!val && isOn) notifier.toggleField(f.$2);
                }
              },
              activeColor: _kNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final (String, String) field;
  final Map<String, String> data;
  final Set<String> enabled;
  final PrintConfigNotifier notifier;
  const _FieldTile(
      {required this.field,
      required this.data,
      required this.enabled,
      required this.notifier});

  @override
  Widget build(BuildContext context) {
    final isOn   = enabled.contains(field.$2);
    final value  = data[field.$2] ?? '';
    final filled = value.isNotEmpty && value != '—';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.fromLTRB(32, 0, 8, 0),
      title: Text(
        field.$1,
        style: TextStyle(
          fontSize: 13,
          color: isOn ? Colors.black87 : _kSub,
          fontWeight: isOn ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
      subtitle: filled
          ? Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: isOn ? _kSub : const Color(0xFFCCCCCC)),
            )
          : const Text(
              'No data entered',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFBBBBBB),
                  fontStyle: FontStyle.italic),
            ),
      trailing: Checkbox(
        value: isOn,
        onChanged: (_) => notifier.toggleField(field.$2),
        activeColor: _kNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onTap: () => notifier.toggleField(field.$2),
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
