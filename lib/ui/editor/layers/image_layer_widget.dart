import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/note_model.dart';
import '../../../providers/editor_provider.dart';

class ImageLayerWidget extends StatelessWidget {
  final ImageLayer layer;
  final String pageId;

  const ImageLayerWidget(
      {super.key, required this.layer, required this.pageId});

  @override
  Widget build(BuildContext context) {
    final activeLayerIndex =
        context.select((EditorProvider p) => p.activeLayerIndex);
    final isEditMode = context.select((EditorProvider p) => p.isEditMode);
    final isActive = isEditMode && activeLayerIndex == 2; // Image layer is 2

    return IgnorePointer(
      ignoring: !isActive,
      child: Stack(
        children: layer.images.map((image) {
          const double handlePadding = 20.0;
          return Positioned(
            left: image.x - handlePadding,
            top: image.y - handlePadding,
            width: image.width + (handlePadding * 2),
            height: image.height + (handlePadding * 2),
            child: _NoteImageItem(
              image: image,
              pageId: pageId,
              isActive: isActive,
              layer: layer,
              handlePadding: handlePadding,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NoteImageItem extends StatelessWidget {
  final NoteImage image;
  final String pageId;
  final bool isActive;
  final ImageLayer layer;
  final double handlePadding;

  const _NoteImageItem({
    required this.image,
    required this.pageId,
    required this.isActive,
    required this.layer,
    required this.handlePadding,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EditorProvider>();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Drag Area
        Padding(
          padding: EdgeInsets.all(handlePadding),
          child: GestureDetector(
            onPanUpdate: isActive
                ? (details) {
                    final newImage = image.copyWith(
                      x: image.x + details.delta.dx,
                      y: image.y + details.delta.dy,
                    );
                    _updateImage(provider, newImage);
                  }
                : null,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive
                      ? Colors.blue
                      : Colors.grey.withValues(alpha: 0.5),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: image.path.startsWith('http')
                  ? Image.network(image.path,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                  : Image.file(File(image.path),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          const Icon(Icons.broken_image)),
            ),
          ),
        ),

        // Resize Handle (Bottom-Right)
        if (isActive)
          Positioned(
            right: handlePadding - 10,
            bottom: handlePadding - 10,
            child: GestureDetector(
              onPanUpdate: (details) {
                final newImage = image.copyWith(
                  width: (image.width + details.delta.dx).clamp(50.0, 1000.0),
                  height: (image.height + details.delta.dy).clamp(50.0, 1000.0),
                );
                _updateImage(provider, newImage);
              },
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
                ),
                child: const Icon(Icons.open_in_full,
                    size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  void _updateImage(EditorProvider provider, NoteImage updatedImage) {
    final newImages = layer.images
        .map((img) => img.id == image.id ? updatedImage : img)
        .toList();
    provider.updateLayer(layer.copyWith(images: newImages), pageId: pageId);
  }
}
