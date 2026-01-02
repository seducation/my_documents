import 'dart:async';
import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/file_service.dart';

enum EditorTool {
  select, // For text selection / moving images
  pen,
  eraser,
  text, // Text insertion mode
  hand, // Pan/Zoom
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
    if (index < 0 || index >= 4) return; // 4 fixed layers for now
    _activeLayerIndex = index;
    notifyListeners();
  }

  NoteLayer? get currentLayer {
    final page = currentPage;
    if (page == null) return null;
    if (_activeLayerIndex >= page.layers.length) return null;
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

  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    notifyListeners();
  }

  void setEditMode(bool value) {
    if (_isEditMode != value) {
      _isEditMode = value;
      notifyListeners();
    }
  }

  // --- Editing Actions ---

  /// Generic update for the current page's specific layer
  void updateLayer(NoteLayer updatedLayer) {
    if (_activeDocument == null || _activePageId == null) return;

    final pageIndex =
        _activeDocument!.pages.indexWhere((p) => p.id == _activePageId);
    if (pageIndex == -1) return;

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
    final sourceTextLayerIndex = 1; // Assuming Text is index 1

    final sourceTextLayer =
        sourcePage.layers[sourceTextLayerIndex] as TextLayer;
    final updatedSourceBlocks = sourceTextLayer.blocks
        .map((b) => b.id == remainBlock.id ? remainBlock : b)
        .toList();
    final updatedSourceLayer =
        sourceTextLayer.copyWith(blocks: updatedSourceBlocks);

    final updatedSourceLayers = List<NoteLayer>.from(sourcePage.layers);
    updatedSourceLayers[sourceTextLayerIndex] = updatedSourceLayer;
    final updatedSourcePage = sourcePage.copyWith(layers: updatedSourceLayers);

    // 2. Handle Target Page (Next Page)
    int targetPageIndex = sourcePageIndex + 1;
    List<NotePage> newPagesList = List.from(_activeDocument!.pages);
    newPagesList[sourcePageIndex] = updatedSourcePage; // Apply source update

    NotePage targetPage;
    if (targetPageIndex >= newPagesList.length) {
      // Create new page
      targetPage = NotePage.create(targetPageIndex);
      newPagesList.add(targetPage);
    } else {
      targetPage = newPagesList[targetPageIndex];
    }

    // 3. Add Moved Block to Target Page
    final targetTextLayerIndex = 1;
    final targetTextLayer =
        targetPage.layers[targetTextLayerIndex] as TextLayer;
    final updatedTargetBlocks = [...targetTextLayer.blocks, movedBlock];
    final updatedTargetLayer =
        targetTextLayer.copyWith(blocks: updatedTargetBlocks);

    final updatedTargetLayers = List<NoteLayer>.from(targetPage.layers);
    updatedTargetLayers[targetTextLayerIndex] = updatedTargetLayer;
    final updatedTargetPage = targetPage.copyWith(layers: updatedTargetLayers);

    newPagesList[targetPageIndex] = updatedTargetPage;

    // 4. Update Document & UI
    _activeDocument = _activeDocument!
        .copyWith(pages: newPagesList, updatedAt: DateTime.now());

    // Optionally move focus to new block? For MVP, maybe not to avoid jarring jump while typing.
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
  void createNewDocumentWithTitle(String title, {String? parentId}) {
    _activeDocument = NoteDocument.create(title: title, parentId: parentId);
    _activePageId = _activeDocument!.pages.first.id;
    _activeLayerIndex = 1;
    notifyListeners();
    saveCurrentDocument(); // Save immediately after creation
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
