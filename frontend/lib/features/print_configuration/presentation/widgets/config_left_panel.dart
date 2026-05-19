import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/print_field.dart';
import '../../domain/models/report_section.dart';
import '../providers/print_config_provider.dart';
import 'field_toggle_tile.dart';
import 'upload_section_widget.dart';

class ConfigLeftPanel extends ConsumerStatefulWidget {
  const ConfigLeftPanel({super.key});

  @override
  ConsumerState<ConfigLeftPanel> createState() => _ConfigLeftPanelState();
}

class _ConfigLeftPanelState extends ConsumerState<ConfigLeftPanel> {
  final Set<String> _expanded = {
    kSectionBasicInfo,
    kSectionVitals,
    kSectionTreatment,
    kSectionReports,
  };

  @override
  Widget build(BuildContext context) {
    final sectionOrder =
        ref.watch(printConfigProvider.select((s) => s.sectionOrder));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(AppDimensions.sm),
              onReorder: (oldIndex, newIndex) => ref
                  .read(printConfigProvider.notifier)
                  .reorderSections(oldIndex, newIndex),
              itemCount: sectionOrder.length,
              proxyDecorator: (child, index, animation) => Material(
                elevation: 6,
                shadowColor: AppColors.primary.withOpacity(0.18),
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLg),
                child: child,
              ),
              itemBuilder: (context, index) {
                final sectionId = sectionOrder[index];
                final section = sectionById(sectionId);
                if (section == null) return const SizedBox.shrink(key: ValueKey(''));
                return _SectionExpansion(
                  key: ValueKey(sectionId),
                  section: section,
                  isExpanded: _expanded.contains(sectionId),
                  onToggle: (open) {
                    setState(() {
                      if (open) {
                        _expanded.add(sectionId);
                      } else {
                        _expanded.remove(sectionId);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const UploadSectionWidget(),
          _SelectAllFooter(),
        ],
      ),
    );
  }
}

// ── Panel Header ──────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Icon(Icons.tune_rounded,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: AppDimensions.sm),
              const Expanded(
                child: Text(
                  'Print Configuration',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Select fields to include in the report. Drag sections to reorder.',
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

// ── Section Expansion Tile ────────────────────────────────────────────────────

class _SectionExpansion extends ConsumerWidget {
  final ReportSection section;
  final bool isExpanded;
  final ValueChanged<bool> onToggle;

  const _SectionExpansion({
    super.key,
    required this.section,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledIds =
        ref.watch(printConfigProvider.select((s) => s.enabledFieldIds));
    final allFields = section.allFields;
    final enabledCount =
        allFields.where((f) => enabledIds.contains(f.id)).length;
    final allEnabled = enabledCount == allFields.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: onToggle,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm,
            vertical: 4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_indicator_rounded,
                  size: 18, color: AppColors.textDisabled),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: section.color.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Icon(section.icon, color: section.color, size: 14),
              ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _FieldCountBadge(
                  enabled: enabledCount, total: allFields.length),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SectionToggle(
                allEnabled: allEnabled,
                onTap: () => ref
                    .read(printConfigProvider.notifier)
                    .toggleSection(section.id, enable: !allEnabled),
              ),
              const Icon(Icons.expand_more_rounded,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
          children: allFields
              .map((f) => FieldToggleTile(field: f))
              .toList(),
        ),
      ),
    );
  }
}

class _FieldCountBadge extends StatelessWidget {
  final int enabled;
  final int total;

  const _FieldCountBadge({required this.enabled, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: enabled > 0
            ? AppColors.primarySurface
            : AppColors.surfaceVariant,
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Text(
        '$enabled / $total',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color:
              enabled > 0 ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SectionToggle extends StatelessWidget {
  final bool allEnabled;
  final VoidCallback onTap;

  const _SectionToggle({required this.allEnabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: allEnabled ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusRound),
          ),
          child: Text(
            allEnabled ? 'All On' : 'All Off',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: allEnabled ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Select All Footer ─────────────────────────────────────────────────────────

class _SelectAllFooter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalFields = kAllPrintFields.length;
    final enabledCount = ref.watch(
        printConfigProvider.select((s) => s.enabledFieldIds.length));

    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            '$enabledCount of $totalFields fields selected',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              final notifier =
                  ref.read(printConfigProvider.notifier);
              for (final section in kAllReportSections) {
                notifier.toggleSection(section.id, enable: true);
              }
            },
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Select All',
                style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () {
              final notifier =
                  ref.read(printConfigProvider.notifier);
              for (final section in kAllReportSections) {
                notifier.toggleSection(section.id, enable: false);
              }
            },
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Clear All',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
