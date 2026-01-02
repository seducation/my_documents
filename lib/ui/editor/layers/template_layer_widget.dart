import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants.dart';
import '../../../models/note_model.dart';
import '../../../providers/editor_provider.dart';

class TemplateLayerWidget extends StatelessWidget {
  final TemplateLayer layer;

  const TemplateLayerWidget({super.key, required this.layer});

  @override
  Widget build(BuildContext context) {
    // Check if this layer is active in the provider
    // Note: In our model, Template is Layer 0
    final activeLayerIndex =
        context.select((EditorProvider p) => p.activeLayerIndex);
    final isActive = activeLayerIndex == 0;

    // Opacity Logic
    final double displayOpacity =
        isActive ? 1.0 : AppConstants.inactiveLayerOpacity;

    return IgnorePointer(
      ignoring: !isActive, // Locked if not active
      child: Opacity(
        opacity: displayOpacity,
        child: Container(
          color: Colors.white, // Base A4 White
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Grid Pattern (Simple placeholder for MVP)
              CustomPaint(painter: GridPainter()),
            ],
          ),
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
