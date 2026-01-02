import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/editor_provider.dart';
import '../../../models/note_model.dart';

class CommentIndicatorsWidget extends StatefulWidget {
  final TransformationController transformationController;
  const CommentIndicatorsWidget(
      {super.key, required this.transformationController});

  @override
  State<CommentIndicatorsWidget> createState() =>
      _CommentIndicatorsWidgetState();
}

class _CommentIndicatorsWidgetState extends State<CommentIndicatorsWidget> {
  @override
  void initState() {
    super.initState();
    widget.transformationController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    setState(() {}); // Rebuild to update indicator positions based on scroll
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final doc = provider.activeDocument;
    if (doc == null) return const SizedBox.shrink();

    // Collect all comments across all pages
    final List<_CommentInfo> allComments = [];
    double currentYOffset = 0;
    const pageGap = 20.0;
    const topPadding = 40.0;

    currentYOffset += topPadding;

    for (var page in doc.pages) {
      final commentLayer = page.layers[4] as CommentLayer;
      for (var comment in commentLayer.annotations) {
        allComments.add(_CommentInfo(
          documentY: currentYOffset + comment.y,
          color: comment.color,
        ));
      }
      currentYOffset += 842.0 + pageGap;
    }

    // Get current transformation
    final matrix = widget.transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translationY = matrix.getTranslation().y;

    return Container(
      width: 12,
      height: double.infinity,
      color: Colors.white.withValues(alpha: 0.05),
      child: Stack(
        children: allComments.map((c) {
          // Calculate screen position: (docY * scale) + translationY
          final screenY = (c.documentY * scale) + translationY;

          // Only show if visible on screen
          if (screenY < 0 || screenY > MediaQuery.of(context).size.height) {
            return const Positioned(child: SizedBox.shrink());
          }

          return Positioned(
            top: screenY - 1,
            child: Container(
              width: 12,
              height: 2,
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.8),
                boxShadow: [
                  BoxShadow(
                      color: c.color.withValues(alpha: 0.5), blurRadius: 4)
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CommentInfo {
  final double documentY;
  final Color color;
  _CommentInfo({required this.documentY, required this.color});
}
