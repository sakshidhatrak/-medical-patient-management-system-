import 'package:cached_network_image/cached_network_image.dart';
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
                child: photo.url != null
                    ? CachedNetworkImage(
                        imageUrl: photo.url!,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey[200],
                          child: const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 90,
                        height: 90,
                        color: Colors.grey[200],
                        child:
                            const Icon(Icons.image, color: Colors.grey),
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This cannot be undone.'),
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
          title: Text(
            '${_current + 1} / ${widget.photos.length}',
            style: const TextStyle(color: Colors.white),
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
                      child: photo.url != null
                          ? CachedNetworkImage(
                              imageUrl: photo.url!,
                              fit: BoxFit.contain,
                              placeholder: (_, __) =>
                                  const CircularProgressIndicator(
                                      color: Colors.white),
                            )
                          : const Icon(Icons.broken_image,
                              color: Colors.white, size: 64),
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
}
