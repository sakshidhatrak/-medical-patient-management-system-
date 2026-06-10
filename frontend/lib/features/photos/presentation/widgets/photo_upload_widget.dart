import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/photo_entity.dart';
import '../providers/photo_provider.dart';
import 'photo_gallery_widget.dart';

/// Drop-in widget for any screen that needs photo upload.
class PhotoUploadWidget extends ConsumerWidget {
  final String patientId;
  final PhotoCategory category;
  final String? visitId;
  final String? surgeryId;

  const PhotoUploadWidget({
    super.key,
    required this.patientId,
    required this.category,
    this.visitId,
    this.surgeryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(photoProvider(patientId));

    final relevant = visitId != null
        ? state.photos
            .where((p) => p.visitId == visitId && p.category == category)
            .toList()
        : surgeryId != null
            ? state.photos
                .where((p) => p.surgeryId == surgeryId && p.category == category)
                .toList()
            : state.photos.where((p) => p.category == category).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Photos — ${category.label}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const Spacer(),
            if (state.isUploading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              _UploadButton(
                onPickCamera: () => _pick(context, ref, ImageSource.camera),
                onPickGallery: () =>
                    _pick(context, ref, ImageSource.gallery),
              ),
          ],
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(state.error!,
                style:
                    const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        if (relevant.isNotEmpty) ...[
          const SizedBox(height: 8),
          PhotoGalleryWidget(
            photos: relevant,
            onDelete: (p) =>
                ref.read(photoProvider(patientId).notifier).delete(p),
          ),
        ] else if (!state.isUploading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No photos yet',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    final xfiles = source == ImageSource.gallery
        ? await picker.pickMultiImage()
        : [await picker.pickImage(source: source)]
            .whereType<XFile>()
            .toList();

    for (final xf in xfiles) {
      final bytes = await xf.readAsBytes();
      await ref.read(photoProvider(patientId).notifier).upload(
            bytes:    bytes,
            filename: xf.name,
            category: category,
            visitId:   visitId,
            surgeryId: surgeryId,
          );
    }
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  const _UploadButton(
      {required this.onPickCamera, required this.onPickGallery});

  @override
  Widget build(BuildContext context) {
    // On web, only gallery is available (no camera API in this setup)
    if (kIsWeb) {
      return TextButton.icon(
        onPressed: onPickGallery,
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
        label: const Text('Add Photo', style: TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      );
    }

    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'camera') {
          onPickCamera();
        } else {
          onPickGallery();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'camera',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.camera_alt_outlined),
              title: Text('Camera'),
            )),
        const PopupMenuItem(
            value: 'gallery',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.photo_library_outlined),
              title: Text('Gallery'),
            )),
      ],
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text('Photo',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
