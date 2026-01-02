import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum LayerType { template, text, image, drawing }

// --- Document & Page ---

class NoteDocument {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NotePage> pages;
  final String? parentId; // null means root folder
  final List<AIChatMessage> chatHistory;

  NoteDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.pages,
    this.parentId,
    this.chatHistory = const [],
  });

  NoteDocument copyWith({
    String? title,
    DateTime? updatedAt,
    List<NotePage>? pages,
    String? parentId,
    List<AIChatMessage>? chatHistory,
  }) {
    return NoteDocument(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pages: pages ?? this.pages,
      parentId: parentId ?? this.parentId,
      chatHistory: chatHistory ?? this.chatHistory,
    );
  }

  factory NoteDocument.create(
      {String title = 'Untitled Note', String? parentId}) {
    return NoteDocument(
      id: const Uuid().v4(),
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      pages: [NotePage.create(0)],
      parentId: parentId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'pages': pages.map((p) => p.toJson()).toList(),
      'parentId': parentId,
      'chatHistory': chatHistory.map((m) => m.toJson()).toList(),
    };
  }

  factory NoteDocument.fromJson(Map<String, dynamic> json) {
    return NoteDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      pages: (json['pages'] as List)
          .map<NotePage>((p) => NotePage.fromJson(p as Map<String, dynamic>))
          .toList(),
      parentId: json['parentId'] as String?,
      chatHistory: (json['chatHistory'] as List? ?? [])
          .map<AIChatMessage>(
              (m) => AIChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class NotePage {
  final String id;
  final int pageIndex;
  final List<NoteLayer> layers;

  NotePage({
    required this.id,
    required this.pageIndex,
    required this.layers,
  });

  NotePage copyWith({
    List<NoteLayer>? layers,
  }) {
    return NotePage(
      id: id,
      pageIndex: pageIndex,
      layers: layers ?? this.layers,
    );
  }

  factory NotePage.create(int index) {
    return NotePage(
      id: const Uuid().v4(),
      pageIndex: index,
      layers: [
        TemplateLayer(id: const Uuid().v4(), isLocked: true), // Layer 0
        TextLayer(id: const Uuid().v4(), blocks: []), // Layer 1
        ImageLayer(id: const Uuid().v4(), images: []), // Layer 2
        DrawingLayer(id: const Uuid().v4(), strokes: []), // Layer 3
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pageIndex': pageIndex,
      'layers': layers.map((l) => _layerToJson(l)).toList(),
    };
  }

  factory NotePage.fromJson(Map<String, dynamic> json) {
    return NotePage(
      id: json['id'] as String,
      pageIndex: json['pageIndex'] as int,
      layers: (json['layers'] as List)
          .map((l) => _layerFromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  static Map<String, dynamic> _layerToJson(NoteLayer layer) {
    final Map<String, dynamic> base = {
      'id': layer.id,
      'type': layer.type.name,
      'isLocked': layer.isLocked,
      'isVisible': layer.isVisible,
      'opacity': layer.opacity,
    };

    if (layer is TemplateLayer) {
      base['backgroundAsset'] = layer.backgroundAsset;
      base['backgroundImagePath'] = layer.backgroundImagePath;
    } else if (layer is TextLayer) {
      base['blocks'] = layer.blocks.map((b) => b.toJson()).toList();
    } else if (layer is ImageLayer) {
      base['images'] = layer.images.map((i) => i.toJson()).toList();
    } else if (layer is DrawingLayer) {
      base['strokes'] = layer.strokes.map((s) => s.toJson()).toList();
    }

    return base;
  }

  static NoteLayer _layerFromJson(Map<String, dynamic> json) {
    final type = LayerType.values.firstWhere((e) => e.name == json['type']);
    final id = json['id'] as String;
    final isLocked = json['isLocked'] as bool;
    final isVisible = json['isVisible'] as bool;
    final opacity = json['opacity'] as double;

    switch (type) {
      case LayerType.template:
        return TemplateLayer(
          id: id,
          isLocked: isLocked,
          isVisible: isVisible,
          opacity: opacity,
          backgroundAsset: json['backgroundAsset'] as String?,
          backgroundImagePath: json['backgroundImagePath'] as String?,
        );
      case LayerType.text:
        return TextLayer(
          id: id,
          isLocked: isLocked,
          isVisible: isVisible,
          opacity: opacity,
          blocks: (json['blocks'] as List? ?? [])
              .map((b) => TextBlock.fromJson(b as Map<String, dynamic>))
              .toList(),
        );
      case LayerType.image:
        return ImageLayer(
          id: id,
          isLocked: isLocked,
          isVisible: isVisible,
          opacity: opacity,
          images: (json['images'] as List? ?? [])
              .map((i) => NoteImage.fromJson(i as Map<String, dynamic>))
              .toList(),
        );
      case LayerType.drawing:
        return DrawingLayer(
          id: id,
          isLocked: isLocked,
          isVisible: isVisible,
          opacity: opacity,
          strokes: (json['strokes'] as List? ?? [])
              .map((s) => DrawingStroke.fromJson(s as Map<String, dynamic>))
              .toList(),
        );
    }
  }
}

// --- Layers (Polymorphic) ---

abstract class NoteLayer {
  final String id;
  final LayerType type;
  final bool isLocked;
  final bool isVisible;
  final double opacity;

  NoteLayer({
    required this.id,
    required this.type,
    this.isLocked = false,
    this.isVisible = true,
    this.opacity = 1.0,
  });

  // Abstract CopyWith to force implementation
  NoteLayer copyWithBase({
    bool? isLocked,
    bool? isVisible,
    double? opacity,
  });
}

class TemplateLayer extends NoteLayer {
  final String? backgroundAsset;
  final String? backgroundImagePath;

  TemplateLayer({
    required super.id,
    super.isLocked = true, // Default locked
    super.isVisible = true,
    super.opacity = 1.0,
    this.backgroundAsset,
    this.backgroundImagePath,
  }) : super(type: LayerType.template);

  @override
  TemplateLayer copyWithBase(
      {bool? isLocked, bool? isVisible, double? opacity}) {
    return copyWith(isLocked: isLocked, isVisible: isVisible, opacity: opacity);
  }

  TemplateLayer copyWith({
    bool? isLocked,
    bool? isVisible,
    double? opacity,
    String? backgroundAsset,
    String? backgroundImagePath,
  }) {
    return TemplateLayer(
      id: id,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
      backgroundAsset: backgroundAsset ?? this.backgroundAsset,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
    );
  }
}

class TextLayer extends NoteLayer {
  final List<TextBlock> blocks;

  TextLayer({
    required super.id,
    super.isLocked = false,
    super.isVisible = true,
    super.opacity = 1.0,
    required this.blocks,
  }) : super(type: LayerType.text);

  @override
  TextLayer copyWithBase({bool? isLocked, bool? isVisible, double? opacity}) {
    return copyWith(isLocked: isLocked, isVisible: isVisible, opacity: opacity);
  }

  TextLayer copyWith({
    bool? isLocked,
    bool? isVisible,
    double? opacity,
    List<TextBlock>? blocks,
  }) {
    return TextLayer(
      id: id,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
      blocks: blocks ?? this.blocks,
    );
  }
}

class ImageLayer extends NoteLayer {
  final List<NoteImage> images;

  ImageLayer({
    required super.id,
    super.isLocked = false,
    super.isVisible = true,
    super.opacity = 1.0,
    required this.images,
  }) : super(type: LayerType.image);

  @override
  ImageLayer copyWithBase({bool? isLocked, bool? isVisible, double? opacity}) {
    return copyWith(isLocked: isLocked, isVisible: isVisible, opacity: opacity);
  }

  ImageLayer copyWith({
    bool? isLocked,
    bool? isVisible,
    double? opacity,
    List<NoteImage>? images,
  }) {
    return ImageLayer(
      id: id,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
      images: images ?? this.images,
    );
  }
}

class DrawingLayer extends NoteLayer {
  final List<DrawingStroke> strokes;

  DrawingLayer({
    required super.id,
    super.isLocked = false,
    super.isVisible = true,
    super.opacity = 1.0,
    required this.strokes,
  }) : super(type: LayerType.drawing);

  @override
  DrawingLayer copyWithBase(
      {bool? isLocked, bool? isVisible, double? opacity}) {
    return copyWith(isLocked: isLocked, isVisible: isVisible, opacity: opacity);
  }

  DrawingLayer copyWith({
    bool? isLocked,
    bool? isVisible,
    double? opacity,
    List<DrawingStroke>? strokes,
  }) {
    return DrawingLayer(
      id: id,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
      strokes: strokes ?? this.strokes,
    );
  }
}

// --- Content Items ---

class TextBlock {
  final String id;
  final String text;
  final double x;
  final double y;
  final double width;
  final double fontSize;
  // Add styling later

  TextBlock({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    this.width = 300,
    this.fontSize = 14,
  });

  TextBlock copyWith({
    String? text,
    double? x,
    double? y,
    double? width,
    double? fontSize,
  }) {
    return TextBlock(
      id: id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'x': x,
      'y': y,
      'width': width,
      'fontSize': fontSize,
    };
  }

  factory TextBlock.fromJson(Map<String, dynamic> json) {
    return TextBlock(
      id: json['id'] as String,
      text: json['text'] as String,
      x: json['x'] as double,
      y: json['y'] as double,
      width: json['width'] as double,
      fontSize: json['fontSize'] as double,
    );
  }
}

class NoteImage {
  final String id;
  final String path;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;

  NoteImage({
    required this.id,
    required this.path,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
    };
  }

  factory NoteImage.fromJson(Map<String, dynamic> json) {
    return NoteImage(
      id: json['id'] as String,
      path: json['path'] as String,
      x: json['x'] as double,
      y: json['y'] as double,
      width: json['width'] as double,
      height: json['height'] as double,
      rotation: json['rotation'] as double,
    );
  }
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
    };
  }

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    return DrawingStroke(
      points: (json['points'] as List)
          .map((p) =>
              Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble()))
          .toList(),
      color: Color(json['color'] as int),
      strokeWidth: json['strokeWidth'] as double,
    );
  }
}

// --- Document Metadata for Home Screen ---

class DocumentMetadata {
  final String id;
  final String title;
  final DateTime lastModified;

  DocumentMetadata({
    required this.id,
    required this.title,
    required this.lastModified,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    return DocumentMetadata(
      id: json['id'] as String,
      title: json['title'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }
}

class AIChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  AIChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    return AIChatMessage(
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
