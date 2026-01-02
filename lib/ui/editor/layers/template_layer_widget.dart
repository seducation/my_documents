import 'package:flutter/material.dart';
import 'dart:io';
import '../../../models/note_model.dart';

class TemplateLayerWidget extends StatelessWidget {
  final TemplateLayer layer;

  const TemplateLayerWidget({super.key, required this.layer});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true, // Template is always locked for interaction
      child: Container(
        color: Colors.white, // Base A4 White
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Image (from PDF Import)
            if (layer.backgroundImagePath != null)
              Image.file(
                File(layer.backgroundImagePath!),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.red),
                ),
              )
            else if (layer.backgroundAsset != null)
              Image.asset(
                layer.backgroundAsset!,
                fit: BoxFit.contain,
              ),

            // 2. Grid Pattern Overlay (Optional/Subtle)
            if (layer.backgroundImagePath == null)
              CustomPaint(painter: GridPainter()),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    const double gridSize = 30.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
