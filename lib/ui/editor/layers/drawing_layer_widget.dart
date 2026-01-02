import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  List<DrawingPoint>? _currentStrokePoints;
  bool _isUsingStylus = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final isActive = provider.activeLayerIndex == 3;
    final activeTool = provider.activeTool;

    final double displayOpacity =
        isActive ? 1.0 : AppConstants.inactiveLayerOpacity;

    return IgnorePointer(
      ignoring: !isActive,
      child: Opacity(
        opacity: displayOpacity,
        child: Listener(
          onPointerDown: (event) {
            if (!isActive) return;

            // Palm Rejection Logic: If we see a stylus, we flag it.
            // If we are using a stylus and see a touch, we might want to ignore it.
            if (event.kind == PointerDeviceKind.stylus) {
              _isUsingStylus = true;
            } else if (event.kind == PointerDeviceKind.touch &&
                _isUsingStylus) {
              // Ignore touch if stylus is active (crude palm rejection)
              return;
            }

            final RenderBox box = context.findRenderObject() as RenderBox;
            final offset = box.globalToLocal(event.position);
            final point =
                DrawingPoint(offset: offset, pressure: event.pressure);

            if (activeTool == EditorTool.pen) {
              setState(() {
                _currentStrokePoints = [point];
              });
            } else if (activeTool == EditorTool.eraser) {
              _eraseAt(offset);
            }
          },
          onPointerMove: (event) {
            if (!isActive) return;
            if (event.kind == PointerDeviceKind.touch && _isUsingStylus) return;

            final RenderBox box = context.findRenderObject() as RenderBox;
            final offset = box.globalToLocal(event.position);
            final point =
                DrawingPoint(offset: offset, pressure: event.pressure);

            if (activeTool == EditorTool.pen) {
              setState(() {
                _currentStrokePoints?.add(point);
              });
            } else if (activeTool == EditorTool.eraser) {
              _eraseAt(offset);
            }
          },
          onPointerUp: (event) {
            if (activeTool == EditorTool.pen && _currentStrokePoints != null) {
              _addStrokeToModel(provider);
              setState(() {
                _currentStrokePoints = null;
              });
            }
            if (event.kind == PointerDeviceKind.stylus) {
              // Reset stylus flag after some timeout or on specific conditions?
              // For now, let's keep it until touch is clearly intentional.
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
    final newStrokes = widget.layer.strokes.where((stroke) {
      for (final p in stroke.points) {
        if ((p.offset - point).distance < eraseRadius) {
          return false;
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
  final List<DrawingPoint>? currentStroke;
  final Color currentColor;
  final double currentWidth;

  _StrokesPainter({
    required this.strokes,
    this.currentStroke,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.strokeWidth);
    }

    if (currentStroke != null && currentStroke!.isNotEmpty) {
      _drawStroke(canvas, currentStroke!, currentColor, currentWidth);
    }
  }

  void _drawStroke(
      Canvas canvas, List<DrawingPoint> points, Color color, double baseWidth) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      paint.strokeWidth = baseWidth * points[0].pressure;
      canvas.drawCircle(points[0].offset, paint.strokeWidth / 2, paint);
      return;
    }

    // Draw segment by segment to respect pressure
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      // Interpolate width based on pressure
      paint.strokeWidth = baseWidth * ((p1.pressure + p2.pressure) / 2);
      canvas.drawLine(p1.offset, p2.offset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) => true;
}
