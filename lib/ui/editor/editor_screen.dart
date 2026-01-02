import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/editor_provider.dart';
import '../../services/pdf_service.dart';
import 'page_widget.dart';
import 'widgets/ai_chat_sheet.dart';

class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doc = context.select((EditorProvider p) => p.activeDocument);
    final isSaving = context.select((EditorProvider p) => p.isSaving);
    final isEditMode = context.select((EditorProvider p) => p.isEditMode);
    final provider = context.read<EditorProvider>();

    if (doc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Save before exiting
        await provider.saveCurrentDocument();

        // Ensure Edit Mode is off when leaving
        provider.setEditMode(false);

        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
        onTap: () {
          // Tap background to dismiss edit mode (optional, per user request "Tapping outside the page... Hides all editing tools")
          // Logic: If tapping strictly outside pages.
          // For now, let's keep it manual toggle or handle in Stack listener if needed.
          // User said: "Tapping outside the page OR turning off Pencil mode: Hides bottom layer UI"
          // We can try to catch taps here.
          // However, scrolling is priority. Let's rely on Pencil toggle mainly or specific outside taps.
          // Implementing tap outside closes edit mode:
          if (isEditMode) {
            // We can turn it off. But this might conflict with scrolling or tapping pages.
            // Let's implement this on the stack background only if possible.
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFE0E0E0),
          appBar: AppBar(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    doc.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isSaving)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Saving...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Export PDF',
                onPressed: () {
                  PdfService.exportDocument(doc);
                },
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'AI Assistant',
                onPressed: () => _showAIChatSheet(context),
              ),
              // Pencil Icon Toggle
              IconButton(
                icon: Icon(isEditMode ? Icons.edit : Icons.edit_outlined),
                color: isEditMode ? Colors.blue : Colors.black,
                tooltip: isEditMode ? 'Done Editing' : 'Edit',
                onPressed: () => provider.toggleEditMode(),
              ),
            ],
          ),
          body: Stack(
            children: [
              // 1. The Scrollable Document Area
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (isEditMode) {
                      provider.setEditMode(false);
                    }
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Column(
                          children: [
                            ...doc.pages.map((page) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: GestureDetector(
                                      // Prevent background tap from closing edit mode when tapping ON page
                                      onTap: () {},
                                      child: PageWidget(page: page)),
                                )),

                            // Add Page Button (Only in Edit Mode?)
                            // User didn't specify, but "Clean viewing mode" suggests hiding it.
                            if (isEditMode)
                              OutlinedButton.icon(
                                onPressed: () {
                                  context.read<EditorProvider>().addPage();
                                },
                                icon: const Icon(Icons.add),
                                label: const Text("Add Page"),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white54,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                ),
                              ),
                            const SizedBox(
                                height: 120), // More space for bottom sheet
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Bottom Tool Palette (Only visible in Edit Mode)
              if (isEditMode)
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ToolPalette(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAIChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AIChatSheet(),
    );
  }
}

class ToolPalette extends StatelessWidget {
  const ToolPalette({super.key});

  @override
  Widget build(BuildContext context) {
    final activeLayer =
        context.select((EditorProvider p) => p.activeLayerIndex);
    final activeTool = context.select((EditorProvider p) => p.activeTool);
    final provider = context.read<EditorProvider>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Layer Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text("Layers: ",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                _layerTab("Template", 0, activeLayer, provider),
                _layerTab("Text", 1, activeLayer, provider),
                _layerTab("Images", 2, activeLayer, provider),
                _layerTab("Drawing", 3, activeLayer, provider),
              ],
            ),
          ),

          if (activeLayer == 3) ...[
            const Divider(height: 24),
            // Drawing Tools (Only when Drawing Layer is selected)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolButton(Icons.edit, EditorTool.pen, activeTool, provider),
                _toolButton(Icons.cleaning_services, EditorTool.eraser,
                    activeTool, provider),
                Container(width: 1, height: 24, color: Colors.grey[300]),
                // Simple color picker mockups
                _colorButton(context, Colors.black, provider),
                _colorButton(context, Colors.red, provider),
                _colorButton(context, Colors.blue, provider),
              ],
            )
          ] else if (activeLayer == 1) ...[
            const Divider(height: 24),
            const Center(
                child: Text("Tap on page to type",
                    style: TextStyle(color: Colors.grey))),
          ]
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, EditorTool tool, EditorTool activeTool,
      EditorProvider provider) {
    final isActive = tool == activeTool;
    return IconButton(
      icon: Icon(icon),
      color: isActive ? Colors.blue : Colors.grey,
      onPressed: () => provider.setTool(tool),
      style: isActive
          ? IconButton.styleFrom(
              backgroundColor: Colors.blue.withValues(alpha: 0.1))
          : null,
    );
  }

  Widget _colorButton(
      BuildContext context, Color color, EditorProvider provider) {
    final activeColor = context.select((EditorProvider p) => p.penColor);
    final isActive = color.toARGB32() == activeColor.toARGB32();

    return GestureDetector(
      onTap: () => provider.setPenProperties(color, provider.penWidth),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: Colors.blue, width: 2) : null,
            boxShadow: [
              if (isActive)
                BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 2)
            ]),
      ),
    );
  }

  Widget _layerTab(
      String label, int index, int activeIndex, EditorProvider provider) {
    final isActive = index == activeIndex;
    return GestureDetector(
      onTap: () => provider.setActiveLayer(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.blue : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
