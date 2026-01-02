import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../providers/editor_provider.dart';
import '../../models/note_model.dart';
import '../../services/pdf_service.dart';
import 'page_widget.dart';
import 'widgets/ai_chat_sheet.dart';
import 'widgets/comment_indicators_widget.dart';
import '../widgets/responsive_layout.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TransformationController _transformationController;
  int _pointerCount = 0;
  double _appBarFactor = 1.0; // 1.0 = full, 0.0 = minimized
  double _lastTranslationY = 0.0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();

    // Initial viewport restoration after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreViewport();
      _transformationController.addListener(_onTransformationChanged);
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _restoreViewport() {
    final provider = context.read<EditorProvider>();
    final doc = provider.activeDocument;
    if (doc == null) return;

    final matrix = Matrix4.translationValues(doc.viewportX, doc.viewportY, 0.0)
      ..multiply(
          Matrix4.diagonal3Values(doc.viewportScale, doc.viewportScale, 1.0));

    _transformationController.value = matrix;
  }

  void _onTransformationChanged() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    final x = translation.x;
    final y = translation.y;

    // Calculate AppBar factor (Safari-style)
    // Scrolling down (y decreases) -> minimize
    // Scrolling up (y increases) -> expand
    // At top (y >= -10) -> full
    if (y > _lastTranslationY || y >= -10) {
      if (_appBarFactor < 1.0) {
        setState(() {
          _appBarFactor =
              (y >= -10) ? 1.0 : (_appBarFactor + 0.1).clamp(0.0, 1.0);
        });
      }
    } else if (y < _lastTranslationY) {
      if (_appBarFactor > 0.0) {
        setState(() {
          _appBarFactor = (_appBarFactor - 0.1).clamp(0.0, 1.0);
        });
      }
    }
    _lastTranslationY = y;

    context.read<EditorProvider>().updateViewport(scale, x, y);
  }

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
        appBar:
            _buildMinimizedAppBar(doc, isSaving, isEditMode, provider, context),
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
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: CommentIndicatorsWidget(
                transformationController: _transformationController,
              ),
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
      appBar:
          _buildMinimizedAppBar(doc, isSaving, isEditMode, provider, context),
      body: Row(
        children: [
          if (isEditMode) const ToolPalette(isVertical: true),
          if (isEditMode) const VerticalDivider(width: 1),
          Expanded(child: _buildScrollableDocument(doc, isEditMode, provider)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildMinimizedAppBar(NoteDocument doc, bool isSaving,
      bool isEditMode, EditorProvider provider, BuildContext context) {
    const double fullHeight = 56.0;
    const double minHeight = 40.0;
    final double currentHeight =
        minHeight + (fullHeight - minHeight) * _appBarFactor;

    return PreferredSize(
      preferredSize: Size.fromHeight(currentHeight),
      child: AppBar(
        toolbarHeight: currentHeight,
        titleSpacing: 0,
        title: Opacity(
          opacity: _appBarFactor.clamp(0.3, 1.0),
          child: Transform.scale(
            scale: 0.8 + (0.2 * _appBarFactor),
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.title,
                      style: TextStyle(
                        fontSize: 14 + (2 * _appBarFactor),
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (isSaving)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          if (_appBarFactor > 0.5) ...[
                            const SizedBox(width: 4),
                            const Text('Saving...',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: _appBarFactor > 0.1 ? 1 : 0,
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _minimizedAction(
                Icons.picture_as_pdf,
                'Export PDF',
                () => PdfService.exportDocument(doc),
              ),
              _minimizedAction(
                Icons.auto_awesome,
                'AI Assistant',
                () => _showAIChatSheet(context),
              ),
              _minimizedAction(
                isEditMode ? Icons.edit : Icons.edit_outlined,
                isEditMode ? 'Done' : 'Edit',
                () => provider.setEditMode(!isEditMode),
                color: isEditMode ? Colors.blue : Colors.black,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _minimizedAction(IconData icon, String tooltip, VoidCallback onPressed,
      {Color? color}) {
    return Transform.scale(
      scale: 0.7 + (0.3 * _appBarFactor),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20 + (4 * _appBarFactor)),
        tooltip: _appBarFactor > 0.5 ? tooltip : null,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildScrollableDocument(
      NoteDocument doc, bool isEditMode, EditorProvider provider) {
    return GestureDetector(
      onTap: () {
        if (isEditMode) provider.setEditMode(false);
      },
      child: Container(
        color: const Color(0xFFE0E0E0),
        child: Listener(
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.touch) {
              setState(() => _pointerCount++);
            }
          },
          onPointerUp: (event) {
            if (event.kind == PointerDeviceKind.touch) {
              setState(() => _pointerCount = (_pointerCount - 1).clamp(0, 10));
            }
          },
          onPointerCancel: (event) {
            if (event.kind == PointerDeviceKind.touch) {
              setState(() => _pointerCount = (_pointerCount - 1).clamp(0, 10));
            }
          },
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.2,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(500),
            constrained: false,
            panEnabled: !isEditMode || _pointerCount >= 2,
            scaleEnabled: !isEditMode || _pointerCount >= 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
              child: Column(
                children: [
                  ...doc.pages.map((page) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: PageWidget(page: page),
                      )),
                  if (isEditMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: OutlinedButton.icon(
                        onPressed: () => provider.addPage(),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Page"),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 16),
                        ),
                      ),
                    ),
                  const SizedBox(height: 200),
                ],
              ),
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
              _layerIcon(Icons.comment, "Com", 4, activeLayer, provider),
              if (activeLayer == 3) ...[
                const Divider(),
                const Text("Tools",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey)),
                _verticalToolButton(
                    Icons.edit, EditorTool.pen, activeTool, provider),
                _verticalToolButton(
                    Icons.brush, EditorTool.highlighter, activeTool, provider),
                _verticalToolButton(Icons.cleaning_services, EditorTool.eraser,
                    activeTool, provider),
                const Divider(),
                _verticalColorButton(Colors.black, provider),
                _verticalColorButton(Colors.red, provider),
                _verticalColorButton(Colors.blue, provider),
                _verticalColorButton(
                    Colors.yellow.withValues(alpha: 0.5), provider),
              ] else if (activeLayer == 2) ...[
                const Divider(),
                _verticalActionButton(
                    Icons.add_photo_alternate,
                    "Local",
                    () =>
                        provider.importImageFromLocal(provider.activePageId!)),
                _verticalActionButton(Icons.language, "Web",
                    () => _showImageUrlDialog(context, provider)),
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
                _layerTab("Comments", 4, activeLayer, provider),
              ],
            ),
          ),
          if (activeLayer == 3) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolButton(Icons.edit, EditorTool.pen, activeTool, provider),
                _toolButton(
                    Icons.brush, EditorTool.highlighter, activeTool, provider),
                _toolButton(Icons.cleaning_services, EditorTool.eraser,
                    activeTool, provider),
                Container(width: 1, height: 24, color: Colors.grey[300]),
                _colorButton(context, Colors.black, provider),
                _colorButton(context, Colors.red, provider),
                _colorButton(context, Colors.blue, provider),
                _colorButton(
                    context, Colors.yellow.withValues(alpha: 0.5), provider),
              ],
            )
          ] else if (activeLayer == 2) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(
                    Icons.add_photo_alternate,
                    "Local",
                    () =>
                        provider.importImageFromLocal(provider.activePageId!)),
                _actionButton(Icons.language, "Website",
                    () => _showImageUrlDialog(context, provider)),
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

  Widget _verticalActionButton(
      IconData icon, String label, VoidCallback onPressed) {
    return IconButton(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blue),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.blue)),
        ],
      ),
      onPressed: onPressed,
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onPressed) {
    return TextButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  void _showImageUrlDialog(BuildContext context, EditorProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Image from URL"),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(hintText: "https://example.com/image.jpg"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.importImageFromUrl(
                    provider.activePageId!, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
}
