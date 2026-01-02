import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants.dart';
import '../../../models/note_model.dart';
import '../../../providers/editor_provider.dart';

class DrawingLayerWidget extends StatefulWidget {
  final DrawingLayer layer;
  final String pageId;

  const DrawingLayerWidget(
      {super.key, required this.layer, required this.pageId});

  @override
  State<DrawingLayerWidget> createState() => _DrawingLayerWidgetState();
}

class _DrawingLayerWidgetState extends State<DrawingLayerWidget> {
  // Temporary storage for current stroke being drawn (before added to model)
  List<Offset>? _currentStrokePoints;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final activeLayerIndex = provider.activeLayerIndex;
    final isActive = activeLayerIndex == 3; // Drawing is 3
    final activeTool = provider.activeTool;

    final double displayOpacity =
        isActive ? 1.0 : AppConstants.inactiveLayerOpacity;

    return IgnorePointer(
      ignoring: !isActive,
      child: Opacity(
        opacity: displayOpacity,
        child: GestureDetector(
          onPanStart: (details) {
            if (!isActive) return;
            final RenderBox box = context.findRenderObject() as RenderBox;
            final point = box.globalToLocal(details.globalPosition);

            if (activeTool == EditorTool.pen) {
              setState(() {
                _currentStrokePoints = [point];
              });
            } else if (activeTool == EditorTool.eraser) {
              _eraseAt(point);
            }
          },
          onPanUpdate: (details) {
            if (!isActive) return;
            final RenderBox box = context.findRenderObject() as RenderBox;
            final point = box.globalToLocal(details.globalPosition);

            if (activeTool == EditorTool.pen) {
              setState(() {
                _currentStrokePoints?.add(point);
              });
            } else if (activeTool == EditorTool.eraser) {
              _eraseAt(point);
            }
          },
          onPanEnd: (details) {
            if (activeTool == EditorTool.pen && _currentStrokePoints != null) {
              // Commit stroke to model
              _addStrokeToModel(provider);
              setState(() {
                _currentStrokePoints = null;
              });
            }
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: _StrokesPainter(
              strokes: widget.layer.strokes,
              currentStroke: _currentStrokePoints,
              currentColor: provider.penColor,
              currentWidth: provider.penWidth,
            ),
          ),
        ),
      ),
    );
  }

  void _addStrokeToModel(EditorProvider provider) {
    if (_currentStrokePoints == null || _currentStrokePoints!.isEmpty) return;

    final newStroke = DrawingStroke(
      points: List.from(_currentStrokePoints!),
      color: provider.penColor,
      strokeWidth: provider.penWidth,
    );

    final newLayer = widget.layer.copyWith(
      strokes: [...widget.layer.strokes, newStroke],
    );
    provider.updateLayer(newLayer);
  }

  void _eraseAt(Offset point) {
    const double eraseRadius = 20.0;
    // Naive erasure: remove any stroke that has a point within eraseRadius
    // For MVP this is acceptable. Optimized approach uses QuadTree or bitmap masking.

    final newStrokes = widget.layer.strokes.where((stroke) {
      for (final p in stroke.points) {
        if ((p - point).distance < eraseRadius) {
          return false; // Remove this stroke
        }
      }
      return true;
    }).toList();

    if (newStrokes.length != widget.layer.strokes.length) {
      final newLayer = widget.layer.copyWith(strokes: newStrokes);
      context.read<EditorProvider>().updateLayer(newLayer);
    }
  }
}

class _StrokesPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<Offset>? currentStroke;
  final Color currentColor;
  final double currentWidth;

  _StrokesPainter(
      {required this.strokes,
      this.currentStroke,
      required this.currentColor,
      required this.currentWidth});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw existing strokes
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth;

      if (stroke.points.isNotEmpty) {
        final path = Path();
        path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // 2. Draw current stroke (if drawing)
    if (currentStroke != null && currentStroke!.isNotEmpty) {
      final paint = Paint()
        ..color = currentColor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentWidth;

      final path = Path();
      path.moveTo(currentStroke!.first.dx, currentStroke!.first.dy);
      for (int i = 1; i < currentStroke!.length; i++) {
        path.lineTo(currentStroke![i].dx, currentStroke![i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) {
    return true; // Simple invalidation for MVP. Optimizing RepaintBoundary handles mostly.
  }
}
