import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
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
  final Set<int> _activeStylusPointers = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final isEditMode = provider.isEditMode;
    final isActive = isEditMode && provider.activeLayerIndex == 3;
    final activeTool = provider.activeTool;

    return IgnorePointer(
      ignoring: !isActive,
      child: Listener(
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.stylus) {
            _activeStylusPointers.add(event.pointer);
          }
        },
        onPointerUp: (event) {
          if (event.kind == PointerDeviceKind.stylus) {
            _activeStylusPointers.remove(event.pointer);
          }
        },
        onPointerCancel: (event) {
          if (event.kind == PointerDeviceKind.stylus) {
            _activeStylusPointers.remove(event.pointer);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            if (!isActive) return;

            // Simple Palm Rejection (if we suspect stylus use)
            if (_activeStylusPointers.isNotEmpty) {
              // Note: GestureDetector's details don't easily tell us WHICH pointer kind it is,
              // but we can infer if a stylus is currently down.
              // Usually, stylists use high-level gestures too.
            }

            final RenderBox box = context.findRenderObject() as RenderBox;
            final offset = box.globalToLocal(details.globalPosition);

            if (activeTool == EditorTool.pen ||
                activeTool == EditorTool.highlighter) {
              setState(() {
                _currentStrokePoints = [DrawingPoint(offset: offset)];
              });
            } else if (activeTool == EditorTool.eraser) {
              _eraseAt(offset);
            }
          },
          onPanUpdate: (details) {
            if (!isActive || _currentStrokePoints == null) return;

            final RenderBox box = context.findRenderObject() as RenderBox;
            final offset = box.globalToLocal(details.globalPosition);

            if (activeTool == EditorTool.pen ||
                activeTool == EditorTool.highlighter) {
              setState(() {
                _currentStrokePoints?.add(DrawingPoint(offset: offset));
              });
            } else if (activeTool == EditorTool.eraser) {
              _eraseAt(offset);
            }
          },
          onPanEnd: (details) {
            if ((activeTool == EditorTool.pen ||
                    activeTool == EditorTool.highlighter) &&
                _currentStrokePoints != null) {
              _addStrokeToModel(provider, activeTool == EditorTool.highlighter);
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
              currentWidth: provider.activeTool == EditorTool.highlighter
                  ? 20.0
                  : provider.penWidth,
              isCurrentHighlighter:
                  provider.activeTool == EditorTool.highlighter,
            ),
          ),
        ),
      ),
    );
  }

  void _addStrokeToModel(EditorProvider provider, bool isHighlighter) {
    if (_currentStrokePoints == null || _currentStrokePoints!.isEmpty) return;

    final newStroke = DrawingStroke(
      points: List.from(_currentStrokePoints!),
      color: provider.penColor,
      strokeWidth: isHighlighter ? 20.0 : provider.penWidth,
      isHighlighter: isHighlighter,
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
  final bool isCurrentHighlighter;

  _StrokesPainter({
    required this.strokes,
    this.currentStroke,
    required this.currentColor,
    required this.currentWidth,
    this.isCurrentHighlighter = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.strokeWidth,
          stroke.isHighlighter);
    }

    if (currentStroke != null && currentStroke!.isNotEmpty) {
      _drawStroke(canvas, currentStroke!, currentColor, currentWidth,
          isCurrentHighlighter);
    }
  }

  void _drawStroke(Canvas canvas, List<DrawingPoint> points, Color color,
      double baseWidth, bool isHighlighter) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = isHighlighter ? color.withValues(alpha: 0.3) : color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = isHighlighter ? BlendMode.multiply : BlendMode.srcOver;

    if (points.length == 1) {
      paint.strokeWidth = baseWidth;
      canvas.drawCircle(points[0].offset, paint.strokeWidth / 2, paint);
      return;
    }

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      paint.strokeWidth = baseWidth;
      canvas.drawLine(p1.offset, p2.offset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) => true;
}
