import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/uploaded_medical_file.dart';
import '../providers/upload_provider.dart';

// ── Public Widget ─────────────────────────────────────────────────────────────

class UploadSectionWidget extends ConsumerStatefulWidget {
  const UploadSectionWidget({super.key});

  @override
  ConsumerState<UploadSectionWidget> createState() =>
      _UploadSectionWidgetState();
}

class _UploadSectionWidgetState
    extends ConsumerState<UploadSectionWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadProvider);
    final total = state.files.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppDimensions.sm, 0, AppDimensions.sm, AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: total > 0
              ? AppColors.success.withOpacity(0.4)
              : AppColors.border,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sm, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF00C48C).withOpacity(0.12),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: const Icon(Icons.upload_file_rounded,
                color: Color(0xFF00C48C), size: 14),
          ),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Upload Medical Files',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(
                        AppDimensions.radiusRound),
                  ),
                  child: Text(
                    '$total file${total == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          trailing: const Icon(Icons.expand_more_rounded,
              size: 18, color: AppColors.textSecondary),
          children: [
            // Error banner
            if (state.errorMessage != null)
              _ErrorBanner(
                message: state.errorMessage!,
                onDismiss: () =>
                    ref.read(uploadProvider.notifier).clearError(),
              ),

            // Type upload rows
            ...ReportFileType.values.map(
              (type) => _TypeUploadRow(type: type),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Per-type Upload Row ───────────────────────────────────────────────────────

class _TypeUploadRow extends ConsumerWidget {
  final ReportFileType type;

  const _TypeUploadRow({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadProvider);
    final files = state.filesOfType(type);
    final isPicking = state.isPicking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type header row
        Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.xs),
          child: Row(
            children: [
              Text(
                type.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              _UploadButton(
                isPicking: isPicking,
                onTap: () =>
                    ref.read(uploadProvider.notifier).pickFiles(type),
              ),
            ],
          ),
        ),

        // Drop zone (only shown when no files yet for this type)
        if (files.isEmpty)
          _DropZone(
            isPicking: isPicking,
            onTap: () =>
                ref.read(uploadProvider.notifier).pickFiles(type),
          )
        else
          ...files.map(
            (f) => _FileCard(
              file: f,
              onRemove: () =>
                  ref.read(uploadProvider.notifier).removeFile(f.id),
            ),
          ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Upload Button ─────────────────────────────────────────────────────────────

class _UploadButton extends StatefulWidget {
  final bool isPicking;
  final VoidCallback onTap;

  const _UploadButton({required this.isPicking, required this.onTap});

  @override
  State<_UploadButton> createState() => _UploadButtonState();
}

class _UploadButtonState extends State<_UploadButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.isPicking
          ? SystemMouseCursors.wait
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isPicking ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.primarySurface,
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isPicking)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.primary,
                  ),
                )
              else
                const Icon(Icons.add_rounded,
                    size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              const Text(
                'Add',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Drop Zone ─────────────────────────────────────────────────────────────────

class _DropZone extends StatefulWidget {
  final bool isPicking;
  final VoidCallback onTap;

  const _DropZone({required this.isPicking, required this.onTap});

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isPicking ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 64,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primarySurface
                : AppColors.surfaceVariant,
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: _hovered ? AppColors.primary : AppColors.border,
              width: _hovered ? 1.5 : 1,
            ),
          ),
          child: widget.isPicking
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 20,
                      color: _hovered
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click or drag & drop  ·  PDF · JPG · PNG',
                      style: TextStyle(
                        fontSize: 10,
                        color: _hovered
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── File Card ─────────────────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final UploadedMedicalFile file;
  final VoidCallback onRemove;

  const _FileCard({required this.file, required this.onRemove});

  Color get _typeColor => switch (file.type) {
        ReportFileType.prescription => AppColors.success,
        ReportFileType.labReport => AppColors.warning,
        ReportFileType.xray => AppColors.info,
        ReportFileType.mriCt => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(
              file.isImage
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_outlined,
              color: _typeColor,
              size: 14,
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    _Badge(
                        label: file.type.shortLabel,
                        color: _typeColor),
                    const SizedBox(width: 4),
                    Text(
                      file.sizeLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Upload complete check
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: AppColors.successSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 10, color: AppColors.success),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 11, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Error Banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm, vertical: AppDimensions.xs),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border:
            Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 14, color: AppColors.error),
          const SizedBox(width: AppDimensions.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.error),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                size: 12, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
