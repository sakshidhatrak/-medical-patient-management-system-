import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/photo_entity.dart';

class PhotoGalleryWidget extends StatelessWidget {
  final List<PhotoEntity> photos;
  final ValueChanged<PhotoEntity>? onDelete;

  const PhotoGalleryWidget({
    super.key,
    required this.photos,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        itemBuilder: (ctx, i) => _PhotoThumb(
          photo: photos[i],
          onTap: () => _showFull(context, photos, i),
          onDelete: onDelete != null ? () => onDelete!(photos[i]) : null,
        ),
      ),
    );
  }

  void _showFull(
      BuildContext context, List<PhotoEntity> photos, int initial) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenViewer(photos: photos, initial: initial),
    ));
  }
}

class _PhotoThumb extends StatelessWidget {
  final PhotoEntity photo;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PhotoThumb(
      {required this.photo, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildImage(width: 90, height: 90),
              ),
            ),
            // Pending-upload badge (clock icon)
            if (!photo.isUploaded)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 10, color: Colors.white),
                      SizedBox(width: 2),
                      Text('Pending',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            if (onDelete != null)
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(Icons.close,
                        size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildImage({required double width, required double height}) {
    // Local file (pending upload)
    if (!photo.isUploaded && photo.localPath != null && !kIsWeb) {
      return Image.file(
        File(photo.localPath!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(width, height),
      );
    }
    // Remote URL
    if (photo.url != null) {
      return CachedNetworkImage(
        imageUrl: photo.url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(width, height,
            child: const CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => _placeholder(width, height,
            child: const Icon(Icons.broken_image, color: Colors.grey)),
      );
    }
    return _placeholder(width, height,
        child: const Icon(Icons.image, color: Colors.grey));
  }

  Widget _placeholder(double width, double height, {Widget? child}) =>
      Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: child != null ? Center(child: child) : null,
      );

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete photo?'),
        content: Text(photo.isUploaded
            ? 'This cannot be undone.'
            : 'This pending photo will be removed and will not upload.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _FullScreenViewer extends StatefulWidget {
  final List<PhotoEntity> photos;
  final int initial;
  const _FullScreenViewer(
      {required this.photos, required this.initial});

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
  late PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    _ctrl = PageController(initialPage: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Row(
            children: [
              Text(
                '${_current + 1} / ${widget.photos.length}',
                style: const TextStyle(color: Colors.white),
              ),
              if (!widget.photos[_current].isUploaded) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Pending upload',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
        body: PageView.builder(
          controller: _ctrl,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (ctx, i) {
            final photo = widget.photos[i];
            return Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    child: Center(
                      child: _buildFullImage(photo),
                    ),
                  ),
                ),
                if (photo.caption?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      photo.caption!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          },
        ),
      );

  Widget _buildFullImage(PhotoEntity photo) {
    if (!photo.isUploaded && photo.localPath != null && !kIsWeb) {
      return Image.file(
        File(photo.localPath!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white, size: 64),
      );
    }
    if (photo.url != null) {
      return CachedNetworkImage(
        imageUrl: photo.url!,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const CircularProgressIndicator(color: Colors.white),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white, size: 64),
      );
    }
    return const Icon(Icons.broken_image, color: Colors.white, size: 64);
  }
}
