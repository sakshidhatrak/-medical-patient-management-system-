import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../services/pdf_export_service.dart';
import '../providers/print_config_provider.dart';
import 'template_save_dialog.dart';

class ReportActionBar extends ConsumerWidget {
  const ReportActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(printConfigProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Template selector ─────────────────────────────────────────
          _TemplateDropdown(state: state),
          const SizedBox(width: AppDimensions.sm),
          _BarButton(
            icon: Icons.bookmark_add_outlined,
            label: 'Save Template',
            color: AppColors.primary,
            outlined: true,
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const TemplateSaveDialog(),
            ),
          ),
          const SizedBox(width: 4),
          _BarButton(
            icon: Icons.refresh_rounded,
            label: 'Reset',
            color: AppColors.textSecondary,
            outlined: true,
            onTap: () => ref.read(printConfigProvider.notifier).reset(),
          ),
          const Spacer(),
          // ── Export / Print ────────────────────────────────────────────
          if (state.isExporting) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            const Text(
              'Generating…',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ] else ...[
            _BarButton(
              icon: Icons.picture_as_pdf_rounded,
              label: 'Export PDF',
              color: AppColors.error,
              onTap: () => _exportPdf(context, ref),
            ),
            const SizedBox(width: 4),
            _BarButton(
              icon: Icons.print_rounded,
              label: 'Print',
              color: AppColors.primary,
              onTap: () => _print(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(printConfigProvider.notifier);
    notifier.setExporting(true);
    try {
      await PdfExportService.exportPdf(ref.read(printConfigProvider));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      notifier.setExporting(false);
    }
  }

  Future<void> _print(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(printConfigProvider.notifier);
    notifier.setExporting(true);
    try {
      await PdfExportService.printReport(ref.read(printConfigProvider));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      notifier.setExporting(false);
    }
  }
}

// ── Template Dropdown ─────────────────────────────────────────────────────────

class _TemplateDropdown extends ConsumerWidget {
  final PrintConfigState state;

  const _TemplateDropdown({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: state.templates
                  .any((t) => t.id == state.activeTemplateId)
              ? state.activeTemplateId
              : state.templates.first.id,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded,
              size: 16, color: AppColors.textSecondary),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: state.templates
              .map(
                (t) => DropdownMenuItem<String>(
                  value: t.id,
                  child: Row(
                    children: [
                      Icon(
                        t.isBuiltIn
                            ? Icons.layers_rounded
                            : Icons.bookmark_rounded,
                        size: 14,
                        color: t.isBuiltIn
                            ? AppColors.primary
                            : AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          t.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!t.isBuiltIn) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => ref
                              .read(printConfigProvider.notifier)
                              .deleteTemplate(t.id),
                          child: const Icon(Icons.close_rounded,
                              size: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id != null) {
              ref
                  .read(printConfigProvider.notifier)
                  .loadTemplate(id);
            }
          },
        ),
      ),
    );
  }
}

// ── Bar Button ────────────────────────────────────────────────────────────────

class _BarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: widget.outlined
                ? (_hovered
                    ? widget.color.withOpacity(0.06)
                    : Colors.transparent)
                : (_hovered
                    ? widget.color.withOpacity(0.85)
                    : widget.color),
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusMd),
            border: widget.outlined
                ? Border.all(color: widget.color.withOpacity(0.5))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: widget.outlined ? widget.color : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.outlined ? widget.color : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
