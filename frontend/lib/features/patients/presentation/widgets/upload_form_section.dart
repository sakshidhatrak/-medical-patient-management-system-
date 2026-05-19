import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/medical_report_entity.dart';
import 'form_section_card.dart';

const _kMaxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

// ── Internal file model ───────────────────────────────────────────────────────

class UploadedFile {
  final String id;
  final String name;
  final String extension;
  final int sizeBytes;
  final Uint8List bytes;
  final ReportType type;

  const UploadedFile({
    required this.id,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.bytes,
    required this.type,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class UploadFormSection extends StatefulWidget {
  const UploadFormSection({super.key});

  @override
  State<UploadFormSection> createState() => UploadFormSectionState();
}

class UploadFormSectionState extends State<UploadFormSection> {
  final List<UploadedFile> _files = [];
  ReportType _selectedType = ReportType.medicalReport;
  bool _picking = false;
  String? _lastError;

  List<UploadedFile> get files => List.unmodifiable(_files);

  // ── File picking ─────────────────────────────────────────────────────────

  Future<void> _pick() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _lastError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || !mounted) return;

      final oversized = <String>[];
      for (final f in result.files) {
        if (f.bytes == null) continue;
        if (f.size > _kMaxFileSizeBytes) {
          oversized.add(f.name);
          continue;
        }
        final existing = _files.any((x) => x.name == f.name && x.type == _selectedType);
        if (existing) continue;

        setState(() {
          _files.add(UploadedFile(
            id: const Uuid().v4(),
            name: f.name,
            extension: (f.extension ?? 'bin').toLowerCase(),
            sizeBytes: f.size,
            bytes: f.bytes!,
            type: _selectedType,
          ));
        });
      }

      if (oversized.isNotEmpty) {
        setState(() => _lastError =
            '${oversized.join(', ')} exceeded the 10 MB limit and were skipped.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _lastError = 'Could not pick files: $e');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _remove(String id) => setState(() => _files.removeWhere((f) => f.id == id));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FormSectionCard(
      title: 'Upload Reports',
      icon: Icons.upload_file_rounded,
      iconColor: AppColors.info,
      children: [
        // Type selector
        const FieldGroupLabel('Upload as'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ReportType.values.map((t) {
              final selected = _selectedType == t;
              return Padding(
                padding: const EdgeInsets.only(right: AppDimensions.xs),
                child: FilterChip(
                  label: Text(t.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedType = t),
                  selectedColor: AppColors.info,
                  checkmarkColor: AppColors.onPrimary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                  ),
                  backgroundColor: AppColors.surfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusRound),
                    side: BorderSide(
                      color: selected ? AppColors.info : AppColors.border,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Drop zone
        _DropZone(picking: _picking, onTap: _pick),

        // Error message
        if (_lastError != null)
          _ErrorBanner(message: _lastError!, onDismiss: () => setState(() => _lastError = null)),

        // Uploaded files
        if (_files.isNotEmpty) ...[
          const FieldGroupLabel('Attached files'),
          ..._files.map(
            (f) => _FileCard(file: f, onRemove: () => _remove(f.id)),
          ),
        ],
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DropZone extends StatefulWidget {
  final bool picking;
  final VoidCallback onTap;
  const _DropZone({required this.picking, required this.onTap});

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 140,
          decoration: BoxDecoration(
            color: _hovering
                ? AppColors.primarySurface
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: _hovering ? AppColors.primary : AppColors.border,
              width: _hovering ? 1.5 : 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: widget.picking
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        size: 28,
                        color: _hovering
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      'Click to upload or drag & drop',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _hovering
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PDF · JPG · PNG    ·    Max 10 MB per file',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final UploadedFile file;
  final VoidCallback onRemove;

  const _FileCard({required this.file, required this.onRemove});

  Color get _typeColor => switch (file.type) {
        ReportType.medicalReport => AppColors.primary,
        ReportType.prescription => AppColors.success,
        ReportType.labReport => AppColors.warning,
        ReportType.scan => AppColors.info,
      };

  IconData get _fileIcon => switch (file.extension) {
        'pdf' => Icons.picture_as_pdf_outlined,
        'jpg' || 'jpeg' || 'png' => Icons.image_outlined,
        _ => Icons.insert_drive_file_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(_fileIcon, color: _typeColor, size: 20),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _Badge(
                      label: file.type.shortLabel,
                      color: _typeColor,
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    Text(
                      file.sizeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          // Progress indicator (simulated complete)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppColors.successSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 12, color: AppColors.success),
          ),
          const SizedBox(width: AppDimensions.sm),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: AppColors.error),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.error),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
