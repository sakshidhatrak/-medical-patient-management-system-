import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/services/google_drive_service.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../services/pdf_export_service.dart';
import '../providers/print_config_provider.dart';
import 'template_save_dialog.dart';

class ReportActionBar extends ConsumerStatefulWidget {
  const ReportActionBar({super.key});

  @override
  ConsumerState<ReportActionBar> createState() => _ReportActionBarState();
}

class _ReportActionBarState extends ConsumerState<ReportActionBar> {

  bool _isDriveSaving = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printConfigProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(bottom: BorderSide(color: context.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            color: context.textSecondary,
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
            Text(
              'Generating…',
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
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
            const SizedBox(width: 4),
            _BarButton(
              icon: Icons.print_outlined,
              label: 'Print w/o Letterhead',
              color: AppColors.primary,
              outlined: true,
              onTap: () => _printWithoutLetterhead(context, ref),
            ),
            const SizedBox(width: 4),
            if (_isDriveSaving)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1B72E8),
                ),
              )
            else
              _BarButton(
                icon: Icons.add_to_drive_rounded,
                label: 'Save to Drive',
                color: const Color(0xFF1B72E8),
                outlined: true,
                onTap: () => _saveToGoogleDrive(context, ref),
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
      await PdfExportService.exportPdf(
        ref.read(printConfigProvider),
        patientData: ref.read(activePatientDataProvider),
      );
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
      await PdfExportService.printReport(
        ref.read(printConfigProvider),
        patientData: ref.read(activePatientDataProvider),
      );
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

  Future<void> _printWithoutLetterhead(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(printConfigProvider.notifier);
    notifier.setExporting(true);
    try {
      await PdfExportService.printReport(
        ref.read(printConfigProvider),
        patientData: ref.read(activePatientDataProvider),
        withLetterhead: false,
      );
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

  Future<void> _saveToGoogleDrive(BuildContext context, WidgetRef ref) async {
    setState(() => _isDriveSaving = true);
    try {
      final config      = ref.read(printConfigProvider);
      final patientData = ref.read(activePatientDataProvider);
      final bytes       = await PdfExportService.buildPdf(config, patientData: patientData);

      // Build filename matching the Export PDF convention.
      final data      = patientData ?? {};
      final firstName = (data['firstName'] ?? '').trim();
      final lastName  = (data['lastName']  ?? '').trim();
      final fullName  = [firstName, lastName].where((s) => s.isNotEmpty).join('');
      final now       = DateTime.now();
      String p2(int v) => v.toString().padLeft(2, '0');
      final dateStr   = '${p2(now.day)}${p2(now.month)}${now.year}';
      final fileName  = fullName.isNotEmpty
          ? '${fullName}_$dateStr.pdf'
          : 'patient_report_$dateStr.pdf';

      // Offline: save bytes to local queue; upload when connection restores.
      if (ref.read(isOnlineProvider) != true) {
        await ref.read(driveUploadQueueProvider).enqueue(fileName, bytes);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline — report queued for Drive upload when connection restores'),
            backgroundColor: Color(0xFF1B72E8),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final fileId = await GoogleDriveService.uploadPdf(bytes, fileName);
      if (!context.mounted) return;

      if (fileId == null) {
        // User cancelled Google sign-in — silently ignore.
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report saved to Google Drive'),
          backgroundColor: Color(0xFF1B72E8),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Drive upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDriveSaving = false);
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
        color: context.bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: context.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: state.templates
                  .any((t) => t.id == state.activeTemplateId)
              ? state.activeTemplateId
              : state.templates.first.id,
          isDense: true,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded,
              size: 16, color: context.textSecondary),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
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
                          child: Icon(Icons.close_rounded,
                              size: 12,
                              color: context.textSecondary),
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
                    ? widget.color.withValues(alpha: 0.06)
                    : Colors.transparent)
                : (_hovered
                    ? widget.color.withValues(alpha: 0.85)
                    : widget.color),
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusMd),
            border: widget.outlined
                ? Border.all(color: widget.color.withValues(alpha: 0.5))
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
