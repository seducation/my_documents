import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../models/file_system_item.dart';
import 'package:flutter/foundation.dart';

class FileService {
  /// Get the app's documents directory
  static Future<String> getDocumentsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final docsPath = '${directory.path}/my_documents';

    // Create directory if it doesn't exist
    final docsDir = Directory(docsPath);
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }

    return docsPath;
  }

  /// Save a document to local storage
  static Future<void> saveDocument(NoteDocument doc) async {
    try {
      final docsPath = await getDocumentsDirectory();
      final file = File('$docsPath/${doc.id}.json');

      final jsonString = jsonEncode(doc.toJson());
      await file.writeAsString(jsonString);

      // Also update file system index
      await _updateFileSystemIndex(FileSystemItem(
        id: doc.id,
        name: doc.title,
        type: FileSystemItemType.document,
        parentId: doc.parentId,
        lastModified: doc.updatedAt,
        createdAt: doc.createdAt,
      ));
    } catch (e) {
      debugPrint('Error saving document: $e');
      rethrow;
    }
  }

  /// Load a document by ID
  static Future<NoteDocument?> loadDocument(String id) async {
    try {
      final docsPath = await getDocumentsDirectory();
      final file = File('$docsPath/$id.json');

      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      return NoteDocument.fromJson(json);
    } catch (e) {
      debugPrint('Error loading document: $e');
      return null;
    }
  }

  /// Get list of file system items (folders & documents) in a specific parent
  static Future<List<FileSystemItem>> listFileSystemItems(
      {String? parentId}) async {
    try {
      final docsPath = await getDocumentsDirectory();
      final indexFile = File('$docsPath/fs_index.json');

      if (!await indexFile.exists()) {
        return [];
      }

      final jsonString = await indexFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final allItems = jsonList
          .map((json) => FileSystemItem.fromJson(json as Map<String, dynamic>))
          .toList();

      // Filter by parentId
      return allItems.where((item) => item.parentId == parentId).toList();
    } catch (e) {
      debugPrint('Error listing file system items: $e');
      return [];
    }
  }

  /// Create a new folder
  static Future<FileSystemItem> createFolder(
      String name, String? parentId) async {
    try {
      final folder = FileSystemItem(
        id: const Uuid().v4(),
        name: name,
        type: FileSystemItemType.folder,
        parentId: parentId,
        lastModified: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _updateFileSystemIndex(folder);
      return folder;
    } catch (e) {
      debugPrint('Error creating folder: $e');
      rethrow;
    }
  }

  /// Move an item (document or folder) to a new parent
  static Future<void> moveItem(String itemId, String? newParentId) async {
    try {
      final docsPath = await getDocumentsDirectory();
      final indexFile = File('$docsPath/fs_index.json');

      if (!await indexFile.exists()) {
        return;
      }

      final jsonString = await indexFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final allItems = jsonList
          .map((json) => FileSystemItem.fromJson(json as Map<String, dynamic>))
          .toList();

      // Find and update the item
      final itemIndex = allItems.indexWhere((item) => item.id == itemId);
      if (itemIndex != -1) {
        allItems[itemIndex] = allItems[itemIndex].copyWith(
          parentId: newParentId,
          lastModified: DateTime.now(),
        );

        // If moving a document, also update the document JSON
        if (allItems[itemIndex].type == FileSystemItemType.document) {
          final doc = await loadDocument(itemId);
          if (doc != null) {
            await saveDocument(doc.copyWith(parentId: newParentId));
          }
        }
      }

      final newJsonString =
          jsonEncode(allItems.map((item) => item.toJson()).toList());
      await indexFile.writeAsString(newJsonString);
    } catch (e) {
      debugPrint('Error moving item: $e');
      rethrow;
    }
  }

  /// Delete a folder (with option to delete recursively)
  static Future<void> deleteFolder(String folderId,
      {bool recursive = false}) async {
    try {
      final docsPath = await getDocumentsDirectory();
      final indexFile = File('$docsPath/fs_index.json');

      if (!await indexFile.exists()) {
        return;
      }

      final jsonString = await indexFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);

      var allItems = jsonList
          .map((json) => FileSystemItem.fromJson(json as Map<String, dynamic>))
          .toList();

      // Check if folder has children
      final hasChildren = allItems.any((item) => item.parentId == folderId);

      if (hasChildren && !recursive) {
        throw Exception(
            'Folder is not empty. Use recursive delete or move contents first.');
      }

      if (recursive) {
        // Delete all children recursively
        final childrenToDelete =
            allItems.where((item) => item.parentId == folderId).toList();

        for (final child in childrenToDelete) {
          if (child.type == FileSystemItemType.folder) {
            await deleteFolder(child.id, recursive: true);
          } else {
            await deleteDocument(child.id);
          }
        }
      }

      // Remove folder from index
      await _removeFromFileSystemIndex(folderId);
    } catch (e) {
      debugPrint('Error deleting folder: $e');
      rethrow;
    }
  }

  /// Delete a document
  static Future<void> deleteDocument(String id) async {
    try {
      final docsPath = await getDocumentsDirectory();
      final file = File('$docsPath/$id.json');

      if (await file.exists()) {
        await file.delete();
      }

      // Remove from file system index
      await _removeFromFileSystemIndex(id);
    } catch (e) {
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }

  /// Rename an item
  static Future<void> renameItem(String itemId, String newName) async {
    try {
      final docsPath = await getDocumentsDirectory();
      final indexFile = File('$docsPath/fs_index.json');

      if (!await indexFile.exists()) {
        return;
      }

      final jsonString = await indexFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final allItems = jsonList
          .map((json) => FileSystemItem.fromJson(json as Map<String, dynamic>))
          .toList();

      final itemIndex = allItems.indexWhere((item) => item.id == itemId);
      if (itemIndex != -1) {
        allItems[itemIndex] = allItems[itemIndex].copyWith(
          name: newName,
          lastModified: DateTime.now(),
        );

        // If renaming a document, also update the document JSON
        if (allItems[itemIndex].type == FileSystemItemType.document) {
          final doc = await loadDocument(itemId);
          if (doc != null) {
            await saveDocument(doc.copyWith(title: newName));
          }
        }
      }

      final newJsonString =
          jsonEncode(allItems.map((item) => item.toJson()).toList());
      await indexFile.writeAsString(newJsonString);
    } catch (e) {
      debugPrint('Error renaming item: $e');
      rethrow;
    }
  }

  /// Update the file system index with an item
  static Future<void> _updateFileSystemIndex(FileSystemItem item) async {
    try {
      final docsPath = await getDocumentsDirectory();
      final indexFile = File('$docsPath/fs_index.json');

      List<FileSystemItem> allItems = [];

      if (await indexFile.exists()) {
        final jsonString = await indexFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        allItems = jsonList
            .map(
                (json) => FileSystemItem.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Update or add this item
      allItems.removeWhere((i) => i.id == item.id);
      allItems.add(item);

      // Sort: folders first, then by name
      allItems.sort((a, b) {
        if (a.type != b.type) {
          return a.type == FileSystemItemType.folder ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      // Save updated index
      final jsonString =
          jsonEncode(allItems.map((item) => item.toJson()).toList());
      await indexFile.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error updating file system index: $e');
    }
  }

  /// Remove item from file system index
  static Future<void> _removeFromFileSystemIndex(String id) async {
    try {
      final docsPath = await getDocumentsDirectory();
      final indexFile = File('$docsPath/fs_index.json');

      if (!await indexFile.exists()) {
        return;
      }

      final jsonString = await indexFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      List<FileSystemItem> allItems = jsonList
          .map((json) => FileSystemItem.fromJson(json as Map<String, dynamic>))
          .toList();

      allItems.removeWhere((item) => item.id == id);

      final newJsonString =
          jsonEncode(allItems.map((item) => item.toJson()).toList());
      await indexFile.writeAsString(newJsonString);
    } catch (e) {
      debugPrint('Error removing from file system index: $e');
    }
  }

  // LEGACY COMPATIBILITY: Keep old methods for backward compatibility
  @Deprecated('Use listFileSystemItems() instead')
  static Future<List<DocumentMetadata>> listDocuments() async {
    final items = await listFileSystemItems();
    return items
        .where((item) => item.type == FileSystemItemType.document)
        .map((item) => DocumentMetadata(
              id: item.id,
              title: item.name,
              lastModified: item.lastModified,
            ))
        .toList();
  }
}
