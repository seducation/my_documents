import 'dart:io';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:uuid/uuid.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/note_model.dart';
import 'file_service.dart';

class PdfService {
  /// Converts a PDF file into a NoteDocument where each page of the PDF
  /// becomes a background template for a NotePage.
  static Future<NoteDocument> convertPdfToNoteDocument(
      File pdfFile, String title) async {
    final document = await pdfx.PdfDocument.openFile(pdfFile.path);
    final List<NotePage> pages = [];

    final appDocDir = await FileService.getDocumentsDirectory();
    final pdfAssetsDir = Directory('$appDocDir/pdf_assets');
    if (!await pdfAssetsDir.exists()) {
      await pdfAssetsDir.create(recursive: true);
    }

    final docId = const Uuid().v4();

    for (int i = 0; i < document.pagesCount; i++) {
      final page = await document.getPage(i + 1);
      final pageImage = await page.render(
        width: page.width * 2, // Scale up for better quality
        height: page.height * 2,
        format: pdfx.PdfPageImageFormat.png,
      );

      if (pageImage != null) {
        final imageName = '${docId}_page_$i.png';
        final imageFile = File('${pdfAssetsDir.path}/$imageName');
        await imageFile.writeAsBytes(pageImage.bytes);

        final notePage = NotePage(
          id: const Uuid().v4(),
          pageIndex: i,
          layers: [
            TemplateLayer(
              id: const Uuid().v4(),
              isLocked: true,
              backgroundImagePath: imageFile.path,
            ),
            TextLayer(id: const Uuid().v4(), blocks: []),
            ImageLayer(id: const Uuid().v4(), images: []),
            DrawingLayer(id: const Uuid().v4(), strokes: []),
          ],
        );
        pages.add(notePage);
      }
      await page.close();
    }
    await document.close();

    return NoteDocument(
      id: docId,
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      pages: pages.isEmpty ? [NotePage.create(0)] : pages,
      chatHistory: [],
    );
  }

  /// Exports a NoteDocument to a PDF file and shares/prints it.
  static Future<void> exportDocument(NoteDocument doc) async {
    final pdf = pw.Document();

    for (final page in doc.pages) {
      // Find background image if it exists in TemplateLayer
      final templateLayer =
          page.layers.firstWhere((l) => l is TemplateLayer) as TemplateLayer;
      pw.MemoryImage? bgImage;
      if (templateLayer.backgroundImagePath != null) {
        final bytes =
            await File(templateLayer.backgroundImagePath!).readAsBytes();
        bgImage = pw.MemoryImage(bytes);
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                if (bgImage != null)
                  pw.Positioned.fill(
                      child: pw.Image(bgImage, fit: pw.BoxFit.fill)),
                // Render text snippets
                ...(page.layers[1] as TextLayer).blocks.map((block) {
                  return pw.Positioned(
                    left: block.x,
                    top: block.y,
                    child: pw.Text(block.text,
                        style: pw.TextStyle(fontSize: block.fontSize)),
                  );
                })
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${doc.title}.pdf',
    );
  }
}
