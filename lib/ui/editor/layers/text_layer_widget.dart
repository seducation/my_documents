import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../constants.dart';
import '../../../core/page_layout_engine.dart';
import '../../../models/note_model.dart';
import '../../../providers/editor_provider.dart';

class TextLayerWidget extends StatelessWidget {
  final TextLayer layer;
  final String pageId;

  const TextLayerWidget({super.key, required this.layer, required this.pageId});

  @override
  Widget build(BuildContext context) {
    final activeLayerIndex =
        context.select((EditorProvider p) => p.activeLayerIndex);
    final isActive = activeLayerIndex == 1; // Text Layer is 1

    final double displayOpacity =
        isActive ? 1.0 : AppConstants.inactiveLayerOpacity;

    return IgnorePointer(
      ignoring: !isActive,
      child: Opacity(
        opacity: displayOpacity,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            if (!isActive) return;
            // Add new text block at tap position
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset localOffset =
                box.globalToLocal(details.globalPosition);

            _addTextBlock(context, localOffset);
          },
          child: Stack(
            children: layer.blocks.map((block) {
              return Positioned(
                left: block.x,
                top: block.y,
                width: block.width,
                child: _EditableTextBlock(
                  block: block,
                  onChanged: (newText) {
                    _updateBlockText(context, block, newText);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _addTextBlock(BuildContext context, Offset position) {
    final newBlock = TextBlock(
      id: const Uuid().v4(),
      text: "",
      x: position.dx,
      // Ensure we don't start below the margin logic
      y: position.dy,
      width: 400, // Default width
    );

    final provider = context.read<EditorProvider>();
    final newLayer = layer.copyWith(
      blocks: [...layer.blocks, newBlock],
    );
    provider.updateLayer(newLayer);
  }

  void _updateBlockText(BuildContext context, TextBlock block, String newText) {
    final provider = context.read<EditorProvider>();

    // Updates
    TextBlock updatedBlock = block.copyWith(text: newText);

    // Check overflow
    // In a real app, we'd handle the split result here.
    // For MVP, we'll just check and maybe show a snackbar or console warn
    final isOverflow = PageLayoutEngine.checkOverflow(updatedBlock);
    if (isOverflow) {
      // Calculate split
      final splitResult = PageLayoutEngine.splitBlock(updatedBlock);

      if (splitResult.containsKey('remain') &&
          splitResult.containsKey('moved')) {
        final remain = splitResult['remain']!;
        final moved = splitResult['moved']!;

        // If moved has content logic
        if (moved.text.isNotEmpty) {
          provider.handleTextOverflow(pageId, remain, moved);
          return; // Stop local update, provider handles it all
        }
      }
    }

    final newBlocks =
        layer.blocks.map((b) => b.id == block.id ? updatedBlock : b).toList();
    provider.updateLayer(layer.copyWith(blocks: newBlocks));
  }
}

class _EditableTextBlock extends StatefulWidget {
  final TextBlock block;
  final ValueChanged<String> onChanged;

  const _EditableTextBlock({required this.block, required this.onChanged});

  @override
  State<_EditableTextBlock> createState() => _EditableTextBlockState();
}

class _EditableTextBlockState extends State<_EditableTextBlock> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block.text);
  }

  @override
  void didUpdateWidget(covariant _EditableTextBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.text != widget.block.text &&
        _controller.text != widget.block.text) {
      // Only update from model if local is different (avoid cursor jumps)
      // State management with text fields is tricky; for MVP this simple check is okay
      // but ideally we rely on Controller being source of truth while focused.
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
        hintText: "Type something...",
        hintStyle: TextStyle(color: Colors.black26),
      ),
      style: TextStyle(
        fontSize: widget.block.fontSize,
        fontFamily: 'Inter',
        color: Colors.black,
        height: 1.2,
      ),
      maxLines: null, // Multiline
      onChanged: widget.onChanged,
    );
  }
}
