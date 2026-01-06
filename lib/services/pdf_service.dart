import 'package:flutter/foundation.dart';
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
      File pdfFile, String title,
      {String? parentId}) async {
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
      parentId: parentId,
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

      // Pre-load images for Image Layer
      final imageLayer =
          page.layers.firstWhere((l) => l is ImageLayer) as ImageLayer;
      final Map<String, pw.MemoryImage> imageMap = {};
      for (final img in imageLayer.images) {
        try {
          if (img.path.startsWith('http')) {
            // Downloading images for PDF export might be slow/complex,
            // but for MVP we assume local or previously cached.
          } else {
            final bytes = await File(img.path).readAsBytes();
            imageMap[img.id] = pw.MemoryImage(bytes);
          }
        } catch (e) {
          debugPrint('Error loading image for PDF export: $e');
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin:
              pw.EdgeInsets.zero, // CRITICAL: 1:1 alignment with UI coordinates
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // 1. Background
                if (bgImage != null)
                  pw.Positioned.fill(
                      child: pw.Image(bgImage, fit: pw.BoxFit.fill)),

                // 2. Images Layer
                ...imageLayer.images
                    .where((i) => imageMap.containsKey(i.id))
                    .map((img) {
                  return pw.Positioned(
                    left: img.x,
                    top: img.y,
                    child: pw.Container(
                      width: img.width,
                      height: img.height,
                      child: pw.Image(imageMap[img.id]!, fit: pw.BoxFit.cover),
                    ),
                  );
                }),

                // 3. Drawing Layer
                ...(page.layers.firstWhere((l) => l is DrawingLayer)
                        as DrawingLayer)
                    .strokes
                    .map((stroke) {
                  if (stroke.points.isEmpty) return pw.SizedBox();

                  final fColor = stroke.color;
                  final opacity = stroke.isHighlighter ? 0.3 : 1.0;
                  final pdfColor = PdfColor(
                    fColor.r,
                    fColor.g,
                    fColor.b,
                    opacity,
                  );

                  // Simple path drawing for strokes
                  return pw.Positioned.fill(
                    child: pw.CustomPaint(
                      painter: (PdfGraphics canvas, PdfPoint size) {
                        canvas
                          ..setColor(pdfColor)
                          ..setStrokeColor(pdfColor)
                          ..setLineWidth(stroke.strokeWidth)
                          ..setLineCap(PdfLineCap.round)
                          ..setLineJoin(PdfLineJoin.round);

                        if (stroke.points.length == 1) {
                          canvas
                            ..drawEllipse(
                                stroke.points[0].offset.dx,
                                PdfPageFormat.a4.height -
                                    stroke.points[0].offset.dy,
                                stroke.strokeWidth / 2,
                                stroke.strokeWidth / 2)
                            ..fillPath();
                          return;
                        }

                        // Move to first point
                        canvas.moveTo(
                          stroke.points[0].offset.dx,
                          PdfPageFormat.a4.height - stroke.points[0].offset.dy,
                        );

                        // Line to subsequent points
                        for (int i = 1; i < stroke.points.length; i++) {
                          final p = stroke.points[i].offset;
                          canvas.lineTo(
                            p.dx,
                            PdfPageFormat.a4.height - p.dy,
                          );
                        }

                        canvas.strokePath();
                      },
                    ),
                  );
                }),

                // 4. Text Layer
                ...(page.layers.firstWhere((l) => l is TextLayer) as TextLayer)
                    .blocks
                    .map((block) {
                  return pw.Positioned(
                    left: block.x,
                    top: block.y,
                    child: pw.Container(
                      width:
                          block.width, // CRITICAL: Prevent horizontal expansion
                      child: pw.Text(
                        block.text,
                        style: pw.TextStyle(
                          fontSize: block.fontSize,
                          lineSpacing: 1.2, // Match UI height 1.2
                        ),
                      ),
                    ),
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
