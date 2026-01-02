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
    final isEditMode = context.select((EditorProvider p) => p.isEditMode);
    final isActive = activeLayerIndex == 1 &&
        isEditMode; // Text Layer is 1 and Edit Mode is on

    return IgnorePointer(
      ignoring: !isActive,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) {
          if (!isActive) return;
          // Add new text block at tap position
          final RenderBox box = context.findRenderObject() as RenderBox;
          final Offset localOffset = box.globalToLocal(details.globalPosition);

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
    );
  }

  void _addTextBlock(BuildContext context, Offset position) {
    final double rightLimit =
        AppConstants.a4Width - PageLayoutEngine.pageMargin;
    final double maxWidth = rightLimit - position.dx;

    // Use a natural width (400) but cap it at the available space
    final double safeWidth =
        maxWidth > 50 ? (maxWidth < 400 ? maxWidth : 400) : 50;

    final newBlock = TextBlock(
      id: const Uuid().v4(),
      text: "",
      x: position.dx,
      y: position.dy,
      width: safeWidth,
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
      // Logic for syncing text field
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = context.select((EditorProvider p) => p.isEditMode);
    return TextField(
      controller: _controller,
      enabled: isEditMode,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
        isCollapsed: true,
        prefixIconConstraints: BoxConstraints(maxWidth: 0, maxHeight: 0),
        suffixIconConstraints: BoxConstraints(maxWidth: 0, maxHeight: 0),
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
