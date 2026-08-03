import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/print_field.dart';
import '../providers/print_config_provider.dart';

// ── Shell ─────────────────────────────────────────────────────────────────────

class PreviewRightPanel extends ConsumerWidget {
  const PreviewRightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFFEEEFF4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 794),
                  child: const _ReportDocument(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _PreviewHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: const Icon(Icons.visibility_outlined,
                size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: AppDimensions.sm),
          const Text(
            'Live Report Preview',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(width: AppDimensions.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.successSurface,
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusRound),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: AppColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text('Live',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success)),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'A4 · Portrait (fixed)',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── A4 Report document ────────────────────────────────────────────────────────

class _ReportDocument extends ConsumerWidget {
  const _ReportDocument();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(printConfigProvider);
    final activeData = ref.watch(activePatientDataProvider);
    final isRealPatient = activeData != null;
    final inOrder = state.sectionOrder.toSet();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning when using mock data
          if (!isRealPatient)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFBBF24)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text(
                  'No patient selected — showing sample data',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),

          // Letterhead
          const _DocumentHeader(),
          const SizedBox(height: 14),

          // Patient Summary
          if (inOrder.contains(kSectionBasicInfo)) ...[
            const _PatientSummaryBox(),
            const SizedBox(height: 12),
          ],

          // Vitals
          if (inOrder.contains(kSectionVitals))
            const _VitalsSection(),

          // Clinical info + Prescription + Doctor notes
          if (inOrder.contains(kSectionTreatment)) ...[
            const _ClinicalInfoSection(),
            const _PrescriptionSection(),
            const _DoctorNotesRow(),
          ],

          const SizedBox(height: 20),
          const _DocumentFooter(),
        ],
      ),
    );
  }
}

// ── Letterhead ────────────────────────────────────────────────────────────────

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Medical cross box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Center(
                child: Text(
                  '+',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MEDIMANAGE MEDICAL CENTER',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.3),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'General Hospital & Healthcare Services',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // QR code placeholder
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded,
                      size: 22, color: AppColors.textSecondary),
                  const Text('Scan to Verify',
                      style: TextStyle(
                          fontSize: 6,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: AppColors.divider),
        const SizedBox(height: 4),
        // Address bar
        Row(
          children: [
            const Icon(Icons.location_on_outlined,
                size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            const Text('123 Medical Drive, Healthcare City, HC 560001',
                style: TextStyle(
                    fontSize: 9, color: AppColors.textSecondary)),
            const SizedBox(width: 16),
            const Icon(Icons.phone_outlined,
                size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            const Text('+1 (555) 000-1234',
                style: TextStyle(
                    fontSize: 9, color: AppColors.textSecondary)),
            const SizedBox(width: 16),
            const Icon(Icons.email_outlined,
                size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            const Text('info@medimanage.com',
                style: TextStyle(
                    fontSize: 9, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 2, color: Colors.black),
        const SizedBox(height: 12),
        // Report title
        const Center(
          child: Text(
            'PATIENT MEDICAL REPORT',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 1.5),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Generated: ${DateFormat('dd MMMM yyyy').format(now)}'
            '    |    ${DateFormat('HH:mm').format(now)}'
            '    |    Report ID: RPT-${DateFormat('ddMMyyyy').format(now)}-${DateFormat('HHmmss').format(now)}',
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ── Patient Summary box ───────────────────────────────────────────────────────

class _PatientSummaryBox extends ConsumerWidget {
  const _PatientSummaryBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(effectivePatientDataProvider);

    final fn = data['firstName'] ?? '';
    final ln = data['lastName'] ?? '';
    final fullName =
        [fn, ln].where((s) => s.isNotEmpty && s != '—').join(' ');
    final age = data['age'] ?? '';
    final gender = data['gender'] ?? '';
    final ageGender =
        [age, gender].where((s) => s.isNotEmpty && s != '—').join(' / ');

    return _BorderedSection(
      header: Row(children: [
        _BlackIconBox(icon: Icons.person_rounded),
        const SizedBox(width: 8),
        const Text('PATIENT SUMMARY',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryCol('Patient Name',
                fullName.isEmpty ? '—' : fullName),
            const _VertDivider(),
            _summaryCol('Age / Gender',
                ageGender.isEmpty ? '—' : ageGender),
            const _VertDivider(),
            _summaryCol('Phone', data['phone'] ?? '—'),
            const _VertDivider(),
            _summaryCol('Address', data['address'] ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _summaryCol(String label, String value) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      );
}

// ── Vitals ────────────────────────────────────────────────────────────────────

class _VitalsSection extends ConsumerWidget {
  const _VitalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(effectivePatientDataProvider);
    final config = ref.watch(printConfigProvider);
    final isReal = ref.watch(activePatientDataProvider) != null;

    final vitals = <Map<String, String>>[];
    void add(String id, String label) {
      if (!config.enabledFieldIds.contains(id)) return;
      final v = data[id] ?? '';
      if (isReal && v.isEmpty) return;
      vitals.add({'label': label, 'value': v.isEmpty ? '—' : v});
    }

    add('weight', 'Weight');
    add('bloodPressure', 'Blood Pressure');
    add('temperature', 'Temperature');

    if (vitals.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Black left panel
            Container(
              width: 88,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(7),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 22),
                  SizedBox(height: 4),
                  Text('VITALS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('(Latest)',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 9)),
                ],
              ),
            ),
            // Vital cells
            ...vitals.map((v) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['label']!,
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(v['value']!,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Clinical Information ──────────────────────────────────────────────────────

class _ClinicalInfoSection extends ConsumerWidget {
  const _ClinicalInfoSection();

  static const _clinicalIds = {
    'previousHistory',
    'chiefComplaint',
    'examGeneral',
    'examNeurological',
    'clinicalDiagnosis',
    'imaging',
    'otherInvestigation',
    'diagnosis',
    'treatmentPlan',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(effectivePatientDataProvider);
    final config = ref.watch(printConfigProvider);
    final isReal = ref.watch(activePatientDataProvider) != null;

    var fields = kAllPrintFields
        .where((f) =>
            f.sectionId == kSectionTreatment &&
            _clinicalIds.contains(f.id) &&
            config.enabledFieldIds.contains(f.id))
        .toList();
    if (isReal) {
      fields = fields
          .where((f) => (data[f.id] ?? '').isNotEmpty)
          .toList();
    }
    if (fields.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(children: [
              _BlackIconBox(icon: Icons.assignment_outlined),
              const SizedBox(width: 8),
              const Text('CLINICAL INFORMATION',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Field rows
          ...fields.asMap().entries.map((entry) {
            final isLast = entry.key == fields.length - 1;
            final f = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 14,
                          child: Text('-',
                              style: TextStyle(
                                  color:
                                      AppColors.textSecondary))),
                      SizedBox(
                        width: 160,
                        child: Text(f.label,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 4),
                      Text(':  ',
                          style: TextStyle(
                              color: AppColors.textSecondary)),
                      Expanded(
                        child: Text(
                          data[f.id] ?? '—',
                          style: const TextStyle(
                              fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(
                      height: 1, color: AppColors.divider),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Prescription / Medication ─────────────────────────────────────────────────

class _PrescriptionSection extends ConsumerWidget {
  const _PrescriptionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(effectivePatientDataProvider);
    final config = ref.watch(printConfigProvider);
    final isReal = ref.watch(activePatientDataProvider) != null;

    if (!config.enabledFieldIds.contains('medications')) {
      return const SizedBox.shrink();
    }
    final meds = data['medications'] ?? '';
    if (isReal && meds.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(children: [
              const Text('Rx',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic)),
              const SizedBox(width: 8),
              const Text('PRESCRIPTION / MEDICATION',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Table with black header
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(7),
              bottomRight: Radius.circular(7),
            ),
            child: Table(
              border: TableBorder.all(
                  color: AppColors.border, width: 0.5),
              columnWidths: const {
                0: FlexColumnWidth(2.5),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1.5),
              },
              children: [
                // Black header
                TableRow(
                  decoration:
                      const BoxDecoration(color: Colors.black),
                  children: [
                    'Medication',
                    'Dose',
                    'Frequency',
                    'Duration',
                    'Instructions',
                  ]
                      .map((h) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: Text(h,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ))
                      .toList(),
                ),
                // Data row
                TableRow(children: [
                  meds.isEmpty ? '—' : meds,
                  '—',
                  '—',
                  '—',
                  '—',
                ]
                    .map((v) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          child: Text(v,
                              style:
                                  const TextStyle(fontSize: 10)),
                        ))
                    .toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Doctor Notes + Follow Up ──────────────────────────────────────────────────

class _DoctorNotesRow extends ConsumerWidget {
  const _DoctorNotesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(effectivePatientDataProvider);
    final config = ref.watch(printConfigProvider);
    final isReal = ref.watch(activePatientDataProvider) != null;

    final notesOn = config.enabledFieldIds.contains('notes');
    final adviceOn = config.enabledFieldIds.contains('advice');
    final notes = notesOn ? (data['notes'] ?? '') : '';
    final advice = adviceOn ? (data['advice'] ?? '') : '';

    final showNotes = notesOn && (!isReal || notes.isNotEmpty);
    final showAdvice = adviceOn && (!isReal || advice.isNotEmpty);

    if (!showNotes && !showAdvice) return const SizedBox.shrink();

    Widget notesBox = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _BlackIconBox(icon: Icons.notes_rounded),
            const SizedBox(width: 8),
            const Text('DOCTOR NOTES',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text(
            notes.isEmpty ? '- No additional notes' : '- $notes',
            style: const TextStyle(fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );

    Widget adviceBox = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _BlackIconBox(icon: Icons.calendar_month_outlined),
            const SizedBox(width: 8),
            const Text('FOLLOW UP',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text(
            advice.isEmpty ? '—' : advice,
            style: const TextStyle(fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: (showNotes && showAdvice)
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: notesBox),
                const SizedBox(width: 10),
                Expanded(child: adviceBox),
              ],
            )
          : (showNotes ? notesBox : adviceBox),
    );
  }
}

// ── Document Footer ───────────────────────────────────────────────────────────

class _DocumentFooter extends ConsumerWidget {
  const _DocumentFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const Divider(color: AppColors.divider),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Doctor signature
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Container(height: 1, width: 150, color: Colors.black),
                  const SizedBox(height: 5),
                  const Text('Dr. Harshal S. Chaudhari',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800)),
                  const Text('Consultant Neurosurgeon (Brain and Spine)',
                      style: TextStyle(fontSize: 10)),
                  const SizedBox(height: 4),
                  const Text(
                      'MBBS, MS Gen. Surg. (KEM Hospital, Mumbai)',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary)),
                  const Text('MCh Neurosurgery (GMC, Goa)',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary)),
                  const Text(
                      'Fellow in NeuroSurgical Oncology (Tata Memorial Hospital, Mumbai)',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('MMC Reg. No: 2009031020',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            // Circular hospital stamp
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.5),
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_hospital_rounded,
                      size: 18),
                  const Text('MEDIMANAGE',
                      style: TextStyle(fontSize: 6)),
                  const Text('MEDICAL CENTER',
                      style: TextStyle(fontSize: 6)),
                ],
              ),
            ),
            // System generated note
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.security_outlined,
                          size: 16,
                          color: AppColors.textSecondary),
                      const SizedBox(height: 4),
                      const Text(
                        'This is a system generated report.\nNo signature required.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _BorderedSection extends StatelessWidget {
  final Widget header;
  final Widget child;

  const _BorderedSection({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: header,
          ),
          const Divider(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }
}

class _BlackIconBox extends StatelessWidget {
  final IconData icon;

  const _BlackIconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Icon(icon, color: Colors.white, size: 13),
    );
  }
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: AppColors.border);
  }
}
