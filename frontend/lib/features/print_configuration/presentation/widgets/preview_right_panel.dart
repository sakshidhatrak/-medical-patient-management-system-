import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/print_field.dart';
import '../../domain/models/report_section.dart';
import '../providers/print_config_provider.dart';

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

class _PreviewHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 10,
      ),
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
              color: AppColors.textPrimary,
            ),
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
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text(
            'A4 · Portrait',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── A4 Report Document ────────────────────────────────────────────────────────

class _ReportDocument extends ConsumerWidget {
  const _ReportDocument();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(printConfigProvider);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DocumentHeader(),
          const SizedBox(height: 12),
          _PatientSummaryBar(),
          const SizedBox(height: 20),
          // Sections in configured order
          for (final sectionId in state.sectionOrder) ...[
            _buildSection(context, sectionId, state),
          ],
          const SizedBox(height: 24),
          _DocumentFooter(),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String sectionId, PrintConfigState state) {
    final section = sectionById(sectionId);
    if (section == null) return const SizedBox.shrink();
    final fields = section.enabledFields(state.enabledFieldIds);
    if (fields.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _SectionBlock(section: section, fields: fields),
    );
  }
}

// ── Document Header ───────────────────────────────────────────────────────────

class _DocumentHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hospital logo placeholder
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.local_hospital_rounded,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MEDIMANAGE MEDICAL CENTER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'General Hospital & Healthcare Services',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Text(
                    '123 Medical Drive, Healthcare City  ·  Tel: +1 (555) 000-1234  ·  info@medimanage.com',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // QR code placeholder
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusSm),
                color: AppColors.surfaceVariant,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded,
                      size: 24, color: AppColors.textSecondary),
                  const Text(
                    'QR Code',
                    style: TextStyle(
                      fontSize: 7,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: AppColors.divider),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'PATIENT MEDICAL REPORT',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Generated: ${DateFormat('dd MMMM yyyy  HH:mm').format(DateTime.now())}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: AppColors.divider),
      ],
    );
  }
}

// ── Patient Summary Bar ───────────────────────────────────────────────────────

class _PatientSummaryBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _SummaryChip(
            label: 'Patient',
            value:
                '${kMockPatientData['firstName']} ${kMockPatientData['lastName']}',
            icon: Icons.person_rounded,
          ),
          const _SummaryDivider(),
          _SummaryChip(
            label: 'DOB',
            value: kMockPatientData['dob'] ?? '—',
            icon: Icons.cake_outlined,
          ),
          const _SummaryDivider(),
          _SummaryChip(
            label: 'Gender',
            value: kMockPatientData['gender'] ?? '—',
            icon: Icons.wc_rounded,
          ),
          const _SummaryDivider(),
          _SummaryChip(
            label: 'Blood Type',
            value: kMockPatientData['bloodType'] ?? '—',
            icon: Icons.bloodtype_outlined,
          ),
          const _SummaryDivider(),
          _SummaryChip(
            label: 'Report ID',
            value: 'RPT-2026-001',
            icon: Icons.badge_outlined,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.primary.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }
}

// ── Section Block ─────────────────────────────────────────────────────────────

class _SectionBlock extends StatelessWidget {
  final ReportSection section;
  final List<PrintField> fields;

  const _SectionBlock({
    required this.section,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: 10),
            decoration: BoxDecoration(
              color: section.color.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.radiusMd - 1),
                topRight: Radius.circular(AppDimensions.radiusMd - 1),
              ),
              border: Border(
                bottom: BorderSide(color: section.color.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: section.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(section.icon, color: section.color, size: 15),
                const SizedBox(width: 6),
                Text(
                  section.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: section.color,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Field rows
          ...fields.asMap().entries.map((entry) {
            final isLast = entry.key == fields.length - 1;
            return _FieldRow(
              field: entry.value,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final PrintField field;
  final bool isLast;

  const _FieldRow({
    required this.field,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final value = kMockPatientData[field.id] ?? '—';
    final isMultiline = value.length > 80;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: 9),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              border:
                  Border(right: BorderSide(color: AppColors.divider)),
            ),
            child: Text(
              field.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md, vertical: 9),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Document Footer ───────────────────────────────────────────────────────────

class _DocumentFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: AppColors.divider),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Doctor Signature',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    width: 160,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Dr. Alice Morgan  |  Cardiology',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: const Text(
                      'CONFIDENTIAL\nFor authorised medical use only',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Report generated by\nMediManage EMR System v1.0',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
