import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/editor_provider.dart';
import '../../../models/note_model.dart';

class CommentLayerWidget extends StatelessWidget {
  final String pageId;
  const CommentLayerWidget({super.key, required this.pageId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final isEditMode = provider.isEditMode;
    final activeLayer = provider.activeLayerIndex;
    final isCommentLayerActive = activeLayer == 4;

    final page =
        provider.activeDocument?.pages.firstWhere((p) => p.id == pageId);
    if (page == null) return const SizedBox.shrink();

    final commentLayer = page.layers.firstWhere(
      (l) => l is CommentLayer,
      orElse: () => CommentLayer(id: '', annotations: []),
    ) as CommentLayer;

    if (commentLayer.id.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: !isCommentLayerActive,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          if (isEditMode && isCommentLayerActive) {
            _showCommentDialog(context, provider, details.localPosition);
          }
        },
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              ...commentLayer.annotations.map((comment) => Positioned(
                    left: comment.x - comment.radius,
                    top: comment.y - comment.radius,
                    child: GestureDetector(
                      onTap: () => _showCommentText(context, comment.text),
                      child: Container(
                        width: comment.radius * 2,
                        height: comment.radius * 2,
                        decoration: BoxDecoration(
                          color: comment.color.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: comment.color, width: 2),
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommentDialog(
      BuildContext context, EditorProvider provider, Offset position) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Comment"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter your comment..."),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.addComment(pageId, controller.text, position);
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showCommentText(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
  }
}
