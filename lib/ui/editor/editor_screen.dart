import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/editor_provider.dart';
import '../../models/note_model.dart';
import '../../services/pdf_service.dart';
import 'page_widget.dart';
import 'widgets/ai_chat_sheet.dart';
import '../widgets/responsive_layout.dart';

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

    return ResponsiveLayout(
      mobile: _buildMobileEditor(doc, isSaving, isEditMode, provider, context),
      tablet: _buildTabletEditor(doc, isSaving, isEditMode, provider, context),
      desktop: _buildTabletEditor(doc, isSaving, isEditMode, provider, context),
    );
  }

  Widget _buildMobileEditor(NoteDocument doc, bool isSaving, bool isEditMode,
      EditorProvider provider, BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await provider.saveCurrentDocument();
        provider.setEditMode(false);
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE0E0E0),
        appBar: _buildAppBar(doc, isSaving, isEditMode, provider, context),
        body: Stack(
          children: [
            _buildScrollableDocument(doc, isEditMode, provider),
            if (isEditMode)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ToolPalette(isVertical: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletEditor(NoteDocument doc, bool isSaving, bool isEditMode,
      EditorProvider provider, BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0E0E0),
      appBar: _buildAppBar(doc, isSaving, isEditMode, provider, context),
      body: Row(
        children: [
          if (isEditMode) const ToolPalette(isVertical: true),
          if (isEditMode) const VerticalDivider(width: 1),
          Expanded(child: _buildScrollableDocument(doc, isEditMode, provider)),
        ],
      ),
    );
  }

  AppBar _buildAppBar(NoteDocument doc, bool isSaving, bool isEditMode,
      EditorProvider provider, BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Expanded(
            child: Text(
              doc.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  Text('Saving...',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
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
          onPressed: () => PdfService.exportDocument(doc),
        ),
        IconButton(
          icon: const Icon(Icons.auto_awesome),
          tooltip: 'AI Assistant',
          onPressed: () => _showAIChatSheet(context),
        ),
        IconButton(
          icon: Icon(isEditMode ? Icons.edit : Icons.edit_outlined),
          color: isEditMode ? Colors.blue : Colors.black,
          tooltip: isEditMode ? 'Done Editing' : 'Edit',
          onPressed: () => provider.toggleEditMode(),
        ),
      ],
    );
  }

  Widget _buildScrollableDocument(
      NoteDocument doc, bool isEditMode, EditorProvider provider) {
    return GestureDetector(
      onTap: () {
        if (isEditMode) provider.setEditMode(false);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                          onTap: () {}, child: PageWidget(page: page)),
                    )),
                if (isEditMode)
                  OutlinedButton.icon(
                    onPressed: () => provider.addPage(),
                    icon: const Icon(Icons.add),
                    label: const Text("Add Page"),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                  ),
                const SizedBox(height: 120),
              ],
            ),
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
  final bool isVertical;
  const ToolPalette({super.key, required this.isVertical});

  @override
  Widget build(BuildContext context) {
    final activeLayer =
        context.select((EditorProvider p) => p.activeLayerIndex);
    final activeTool = context.select((EditorProvider p) => p.activeTool);
    final provider = context.read<EditorProvider>();

    if (isVertical) {
      return Container(
        width: 80,
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text("Layers",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              _layerIcon(Icons.layers, "Temp", 0, activeLayer, provider),
              _layerIcon(Icons.text_fields, "Text", 1, activeLayer, provider),
              _layerIcon(Icons.image, "Img", 2, activeLayer, provider),
              _layerIcon(Icons.draw, "Draw", 3, activeLayer, provider),
              if (activeLayer == 3) ...[
                const Divider(),
                const Text("Tools",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey)),
                _verticalToolButton(
                    Icons.edit, EditorTool.pen, activeTool, provider),
                _verticalToolButton(Icons.cleaning_services, EditorTool.eraser,
                    activeTool, provider),
                const Divider(),
                _verticalColorButton(Colors.black, provider),
                _verticalColorButton(Colors.red, provider),
                _verticalColorButton(Colors.blue, provider),
              ]
            ],
          ),
        ),
      );
    }

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolButton(Icons.edit, EditorTool.pen, activeTool, provider),
                _toolButton(Icons.cleaning_services, EditorTool.eraser,
                    activeTool, provider),
                Container(width: 1, height: 24, color: Colors.grey[300]),
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

  Widget _layerIcon(IconData icon, String label, int index, int activeIndex,
      EditorProvider provider) {
    final isActive = index == activeIndex;
    return IconButton(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? Colors.blue : Colors.grey),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: isActive ? Colors.blue : Colors.grey)),
        ],
      ),
      onPressed: () => provider.setActiveLayer(index),
    );
  }

  Widget _verticalToolButton(IconData icon, EditorTool tool,
      EditorTool activeTool, EditorProvider provider) {
    final isActive = tool == activeTool;
    return IconButton(
      icon: Icon(icon, color: isActive ? Colors.blue : Colors.grey),
      onPressed: () => provider.setTool(tool),
    );
  }

  Widget _verticalColorButton(Color color, EditorProvider provider) {
    return GestureDetector(
      onTap: () => provider.setPenProperties(color, provider.penWidth),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    );
  }

  Widget _colorButton(
      BuildContext context, Color color, EditorProvider provider) {
    final activeColor = provider.penColor;
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
        ),
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
