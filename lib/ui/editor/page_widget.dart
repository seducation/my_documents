import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/editor_provider.dart';
import '../../constants.dart';
import '../../models/note_model.dart';
import 'layers/template_layer_widget.dart';
import 'layers/text_layer_widget.dart';
import 'layers/drawing_layer_widget.dart';
// import 'layers/image_layer_widget.dart';

class PageWidget extends StatelessWidget {
  final NotePage page;

  const PageWidget({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate A4 Aspect Ratio
    const aspectRatio = AppConstants.a4Width / AppConstants.a4Height;
    final isEditMode = context.select((EditorProvider p) => p.isEditMode);
    final activeLayerIndex =
        context.select((EditorProvider p) => p.activeLayerIndex);

    // Helper to calculate opacity
    double getLayerOpacity(int layerIndex) {
      if (!isEditMode) return 1.0; // Reading mode: full visibility
      if (layerIndex == 0) return 1.0; // Template always visible
      return layerIndex == activeLayerIndex
          ? 1.0
          : 0.3; // Active 1.0, others 0.3
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                blurRadius: 4,
                offset: const Offset(0, 2),
                color: Colors.black.withValues(alpha: 0.15))
          ],
        ),
        // Clip to bounds so drawing doesn't bleed out
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Layer 0: Template (Always visible, behind everything)
            RepaintBoundary(
              child:
                  TemplateLayerWidget(layer: page.layers[0] as TemplateLayer),
            ),

            // Layer 1: Text
            Opacity(
              opacity: getLayerOpacity(1),
              child: RepaintBoundary(
                child: TextLayerWidget(
                    layer: page.layers[1] as TextLayer, pageId: page.id),
              ),
            ),

            // Layer 2: Images (Placeholder for now)
            Opacity(
              opacity: getLayerOpacity(2),
              child: RepaintBoundary(
                // child: ImageLayerWidget(layer: page.layers[2] as ImageLayer),
                child: Container(),
              ),
            ),

            // Layer 3: Drawing
            Opacity(
              opacity: getLayerOpacity(3),
              child: RepaintBoundary(
                child: DrawingLayerWidget(
                    layer: page.layers[3] as DrawingLayer, pageId: page.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
