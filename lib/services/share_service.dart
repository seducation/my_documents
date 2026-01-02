import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pdf_service.dart';
import 'file_service.dart';
import '../providers/editor_provider.dart';
import '../ui/editor/editor_screen.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  void init(BuildContext context) {
    // For sharing images coming from outside the app while the app is in the memory
    ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> value) {
      if (context.mounted) {
        _handleSharedFiles(context, value);
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (context.mounted) {
        _handleSharedFiles(context, value);
      }
    });
  }

  void _handleSharedFiles(
      BuildContext context, List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    // We only support one PDF at a time for automatic import
    final SharedMediaFile? pdfFile = files.cast<SharedMediaFile?>().firstWhere(
          (file) => file?.path.toLowerCase().endsWith('.pdf') ?? false,
          orElse: () => files.first,
        );

    if (pdfFile != null && pdfFile.path.toLowerCase().endsWith('.pdf')) {
      final file = File(pdfFile.path);
      final fileName = pdfFile.path.split('/').last;

      try {
        final newDoc =
            await PdfService.convertPdfToNoteDocument(file, fileName);
        await FileService.saveDocument(newDoc);

        if (!context.mounted) return;

        final editorProvider = context.read<EditorProvider>();
        editorProvider.setActiveDocument(newDoc);

        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditorScreen()),
        );
      } catch (e) {
        debugPrint("Error handling shared PDF: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error importing shared PDF: $e')),
          );
        }
      }
    }
  }
}
