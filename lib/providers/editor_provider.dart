import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/note_model.dart';
import '../services/file_service.dart';
import '../core/page_layout_engine.dart';

enum EditorTool {
  select, // For text selection / moving images
  pen,
  eraser,
  text, // Text insertion mode
  hand, // Pan/Zoom
  highlighter,
  comment,
}

class EditorProvider extends ChangeNotifier {
  NoteDocument? _activeDocument;
  String? _activePageId;
  int _activeLayerIndex = 1; // Default to Text Layer (Index 1) usually
  EditorTool _activeTool = EditorTool.select;

  // Drawing State
  Color _penColor = Colors.black;
  double _penWidth = 2.0;

  // Edit Mode State
  bool _isEditMode = false;

  // Auto-save State
  Timer? _autoSaveTimer;
  bool _isSaving = false;
  DateTime? _lastSaved;

  NoteDocument? get activeDocument => _activeDocument;
  String? get activePageId => _activePageId;
  int get activeLayerIndex => _activeLayerIndex;
  EditorTool get activeTool => _activeTool;
  Color get penColor => _penColor;
  double get penWidth => _penWidth;
  bool get isEditMode => _isEditMode;
  bool get isSaving => _isSaving;
  DateTime? get lastSaved => _lastSaved;

  // --- Initialization ---

  void setActiveDocument(NoteDocument doc) {
    _activeDocument = doc;
    _activePageId = doc.pages.isNotEmpty ? doc.pages.first.id : null;
    _activeLayerIndex = 1;
    notifyListeners();
  }

  void createNewDocument() {
    _activeDocument = NoteDocument.create();
    _activePageId = _activeDocument!.pages.first.id;
    _activeLayerIndex = 1; // Start on Text Layer
    notifyListeners();
  }

  // --- Page Management ---

  NotePage? get currentPage {
    if (_activeDocument == null || _activePageId == null) return null;
    return _activeDocument!.pages.firstWhere((p) => p.id == _activePageId);
  }

  void addPage() {
    if (_activeDocument == null) return;
    final newIndex = _activeDocument!.pages.length;
    final newPage = NotePage.create(newIndex);

    _activeDocument = _activeDocument!.copyWith(
      pages: [..._activeDocument!.pages, newPage],
    );
    // Switch to new page
    _activePageId = newPage.id;
    notifyListeners();
    _scheduleAutoSave();
  }

  // --- Layer Management ---

  void setActiveLayer(int index) {
    if (index < 0 || index >= 5) {
      return; // 5 layers: Template, Text, Image, Drawing, Comment
    }
    _activeLayerIndex = index;
    notifyListeners();
  }

  NoteLayer? get currentLayer {
    final page = currentPage;
    if (page == null) return null;
    if (_activeLayerIndex >= page.layers.length) {
      return null;
    }
    return page.layers[_activeLayerIndex];
  }

  // --- Tool Management ---

  void setTool(EditorTool tool) {
    _activeTool = tool;
    notifyListeners();
  }

  void setPenProperties(Color color, double width) {
    _penColor = color;
    _penWidth = width;
    notifyListeners();
  }

  // --- Edit Mode Management ---

  void setEditMode(bool value) {
    if (_isEditMode != value) {
      _isEditMode = value;
      // If entering edit mode and still on default text tool, switch to pen
      if (_isEditMode && _activeTool == EditorTool.text) {
        setTool(EditorTool.pen);
      }
      notifyListeners();
    }
  }

  void toggleEditMode() {
    setEditMode(!_isEditMode);
  }

  // --- Editing Actions ---

  /// Generic update for a specific page's layer.
  /// If [pageId] is provided, updates that page; otherwise uses [_activePageId].
  void updateLayer(NoteLayer updatedLayer,
      {String? pageId, int? specificPageIndex}) {
    if (_activeDocument == null) return;

    final targetPageId = pageId ?? _activePageId;
    final pageIndex = specificPageIndex ??
        _activeDocument!.pages.indexWhere((p) => p.id == targetPageId);
    if (pageIndex == -1) {
      debugPrint(
          'Warning: Attempted to update layer on non-existent page: $targetPageId');
      return;
    }

    final oldPage = _activeDocument!.pages[pageIndex];

    // Replace layer in list
    // Note: This assumes layers are ordered by index and constant size.
    // Ideally we should match by ID, but for MVP strict structure (0=Template, 1=Text, etc) works.
    final newLayers = List<NoteLayer>.from(oldPage.layers);

    // Find index of layer to replace
    final layerIndex = newLayers.indexWhere((l) => l.id == updatedLayer.id);
    if (layerIndex != -1) {
      newLayers[layerIndex] = updatedLayer;
    }

    final newPage = oldPage.copyWith(layers: newLayers);

    final newPages = List<NotePage>.from(_activeDocument!.pages);
    newPages[pageIndex] = newPage;

    _activeDocument = _activeDocument!.copyWith(pages: newPages);
    _activeDocument = _activeDocument!.copyWith(updatedAt: DateTime.now());

    notifyListeners();
    _scheduleAutoSave();
  }

  void handleTextOverflow(
      String sourcePageId, TextBlock remainBlock, TextBlock movedBlock) {
    if (_activeDocument == null) return;

    final sourcePageIndex =
        _activeDocument!.pages.indexWhere((p) => p.id == sourcePageId);
    if (sourcePageIndex == -1) return;

    // 1. Update Source Page (with truncated block)
    final sourcePage = _activeDocument!.pages[sourcePageIndex];
    const sourceTextLayerIndex = 1;

    final sourceTextLayer =
        sourcePage.layers[sourceTextLayerIndex] as TextLayer;

    // Update or remove the block
    final List<TextBlock> updatedSourceBlocks;
    if (remainBlock.text.isEmpty) {
      updatedSourceBlocks =
          sourceTextLayer.blocks.where((b) => b.id != remainBlock.id).toList();
    } else {
      updatedSourceBlocks = sourceTextLayer.blocks
          .map((b) => b.id == remainBlock.id ? remainBlock : b)
          .toList();
    }

    final updatedSourceLayer =
        sourceTextLayer.copyWith(blocks: updatedSourceBlocks);

    final updatedSourceLayers = List<NoteLayer>.from(sourcePage.layers);
    updatedSourceLayers[sourceTextLayerIndex] = updatedSourceLayer;
    final updatedSourcePage = sourcePage.copyWith(layers: updatedSourceLayers);

    // 2. Handle Target Page (Next Page)
    int targetPageIndex = sourcePageIndex + 1;
    List<NotePage> newPagesList = List.from(_activeDocument!.pages);
    newPagesList[sourcePageIndex] = updatedSourcePage;

    if (targetPageIndex >= newPagesList.length) {
      newPagesList.add(NotePage.create(targetPageIndex));
    }

    _activeDocument = _activeDocument!.copyWith(pages: newPagesList);
    final targetPage = _activeDocument!.pages[targetPageIndex];

    // 3. Process the moved block on the target page (Recursive via _processTextInsertion)
    // We use the same coordinates (x, margin) for the spillover, and maintain width
    _processTextInsertion(movedBlock.text, targetPage.id, movedBlock.x,
        PageLayoutEngine.pageMargin,
        width: movedBlock.width);

    notifyListeners();
    _scheduleAutoSave();
  }

  /// Appends text to the document, starting a new page if requested,
  /// and automatically overflowing across pages as needed.
  void appendTextWithOverflow(String text, {bool startNewPage = true}) {
    if (_activeDocument == null) return;

    if (startNewPage) {
      addPage();
    }

    // Use current page as start
    String targetPageId = _activePageId ?? _activeDocument!.pages.last.id;
    double startX = PageLayoutEngine.pageMargin;
    double startY = PageLayoutEngine.pageMargin;

    _processTextInsertion(text, targetPageId, startX, startY,
        width: PageLayoutEngine.contentWidth);

    notifyListeners();
    _scheduleAutoSave();
  }

  void _processTextInsertion(String text, String pageId, double x, double y,
      {double? width}) {
    TextBlock block = TextBlock(
      id: const Uuid().v4(),
      text: text,
      x: x,
      y: y,
      width: width ?? PageLayoutEngine.contentWidth,
    );

    if (PageLayoutEngine.checkOverflow(block)) {
      final split = PageLayoutEngine.splitBlock(block);
      final remain = split['remain']!;
      final moved = split['moved']!;

      if (remain.text.isNotEmpty) {
        _addBlockToPage(pageId, remain);
      }

      // Create/Get next page
      int currentPageIndex =
          _activeDocument!.pages.indexWhere((p) => p.id == pageId);
      NotePage nextPage;
      if (currentPageIndex + 1 < _activeDocument!.pages.length) {
        nextPage = _activeDocument!.pages[currentPageIndex + 1];
      } else {
        nextPage = NotePage.create(_activeDocument!.pages.length);
        _activeDocument = _activeDocument!.copyWith(
          pages: [..._activeDocument!.pages, nextPage],
        );
      }

      // Recursive call for moved text on next page
      _processTextInsertion(moved.text, nextPage.id, moved.x, moved.y,
          width: moved.width);
    } else if (text.trim().isNotEmpty) {
      _addBlockToPage(pageId, block);
    }
  }

  void updateViewport(double scale, double x, double y) {
    if (_activeDocument == null) return;

    _activeDocument = _activeDocument!.copyWith(
      viewportScale: scale,
      viewportX: x,
      viewportY: y,
    );

    _scheduleAutoSave();
  }

  // --- Comment Management ---

  void addComment(String pageId, String text, Offset position) {
    final pageIndex = _activeDocument!.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final page = _activeDocument!.pages[pageIndex];
    const commentLayerIndex = 4;
    final commentLayer = page.layers[commentLayerIndex] as CommentLayer;

    final newComment = CommentAnnotation(
      id: const Uuid().v4(),
      text: text,
      x: position.dx,
      y: position.dy,
      createdAt: DateTime.now(),
      color: _getNextCommentColor(),
    );

    final updatedLayer = commentLayer
        .copyWith(annotations: [...commentLayer.annotations, newComment]);
    updateLayer(updatedLayer, pageId: pageId);
  }

  Color _getNextCommentColor() {
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
    ];
    final page = currentPage;
    if (page == null) return colors[0];
    final count = (page.layers[4] as CommentLayer).annotations.length;
    return colors[count % colors.length];
  }

  void removeComment(String pageId, String commentId) {
    final pageIndex = _activeDocument!.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final page = _activeDocument!.pages[pageIndex];
    const commentLayerIndex = 4;
    final commentLayer = page.layers[commentLayerIndex] as CommentLayer;

    final updatedAnnotations =
        commentLayer.annotations.where((a) => a.id != commentId).toList();
    final updatedLayer = commentLayer.copyWith(annotations: updatedAnnotations);
    updateLayer(updatedLayer, pageId: pageId);
  }

  // --- Image Import ---

  Future<void> importImageFromLocal(String pageId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      if (file.path != null) {
        await _addFileToImageLayer(pageId, File(file.path!));
      }
    }
  }

  Future<void> importImageFromUrl(String pageId, String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'web_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final localFile = File(p.join(appDir.path, fileName));
        await localFile.writeAsBytes(response.bodyBytes);
        await _addFileToImageLayer(pageId, localFile);
      }
    } catch (e) {
      debugPrint('Error importing image from URL: $e');
    }
  }

  Future<void> _addFileToImageLayer(String pageId, File file) async {
    final pageIndex = _activeDocument!.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final page = _activeDocument!.pages[pageIndex];
    const imageLayerIndex = 2;
    final imageLayer = page.layers[imageLayerIndex] as ImageLayer;

    // Default placement with some staggering to avoid perfect overlap
    final int existingCount = imageLayer.images.length;
    final double offset = existingCount * 20.0;

    final newImage = NoteImage(
      id: const Uuid().v4(),
      path: file.path,
      x: PageLayoutEngine.pageMargin + (offset % 100),
      y: PageLayoutEngine.pageMargin + (offset % 100),
      width: 200,
      height: 200,
    );

    final updatedLayer =
        imageLayer.copyWith(images: [...imageLayer.images, newImage]);
    updateLayer(updatedLayer, specificPageIndex: pageIndex);
  }

  void _addBlockToPage(String pageId, TextBlock block) {
    final pageIndex = _activeDocument!.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final page = _activeDocument!.pages[pageIndex];
    const textLayerIndex = 1;
    final textLayer = page.layers[textLayerIndex] as TextLayer;

    final updatedLayer =
        textLayer.copyWith(blocks: [...textLayer.blocks, block]);
    final updatedLayers = List<NoteLayer>.from(page.layers);
    updatedLayers[textLayerIndex] = updatedLayer;

    final updatedPage = page.copyWith(layers: updatedLayers);
    final updatedPages = List<NotePage>.from(_activeDocument!.pages);
    updatedPages[pageIndex] = updatedPage;

    _activeDocument = _activeDocument!.copyWith(pages: updatedPages);
  }

  // --- AI Chat History ---

  void addAIChatMessage(AIChatMessage message) {
    if (_activeDocument == null) return;

    final updatedHistory = [..._activeDocument!.chatHistory, message];
    _activeDocument = _activeDocument!.copyWith(chatHistory: updatedHistory);

    notifyListeners();
    _scheduleAutoSave();
  }

  // --- Auto-Save & Persistence ---

  /// Schedule an auto-save (debounced to prevent excessive writes)
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      saveCurrentDocument();
    });
  }

  /// Save the current document to local storage
  Future<void> saveCurrentDocument() async {
    if (_activeDocument == null || _isSaving) return;

    try {
      _isSaving = true;
      notifyListeners();

      await FileService.saveDocument(_activeDocument!);

      _lastSaved = DateTime.now();
      _isSaving = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving document: $e');
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Load a document from storage
  Future<void> loadDocument(String id) async {
    try {
      final doc = await FileService.loadDocument(id);
      if (doc != null) {
        _activeDocument = doc;
        _activePageId = doc.pages.first.id;
        _activeLayerIndex = 1;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading document: $e');
    }
  }

  /// Create a new document with a given title
  Future<void> createNewDocumentWithTitle(String title,
      {String? parentId}) async {
    _activeDocument = NoteDocument.create(title: title, parentId: parentId);

    // Add initial AI greeting
    final greeting = AIChatMessage(
      text:
          "Hello! I'm your AI assistant. How can I help you with your document today?",
      isUser: false,
      timestamp: DateTime.now(),
    );
    _activeDocument = _activeDocument!.copyWith(chatHistory: [greeting]);

    _activePageId = _activeDocument!.pages.first.id;
    _activeLayerIndex = 1;
    notifyListeners();
    await saveCurrentDocument(); // Save immediately after creation
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
