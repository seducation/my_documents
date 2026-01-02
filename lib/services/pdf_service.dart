import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/note_model.dart';

class PdfService {
  /// Export the given document to a PDF file & share/print it
  static Future<void> exportDocument(NoteDocument doc) async {
    final pdf = pw.Document();

    for (final page in doc.pages) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // 1. Template Layer
                _buildTemplateLayer(page.layers[0] as TemplateLayer),

                // 2. Text Layer
                _buildTextLayer(page.layers[1] as TextLayer),

                // 3. Image Layer (Skipped for MVP)

                // 4. Drawing Layer
                _buildDrawingLayer(page.layers[3] as DrawingLayer),
              ],
            );
          },
        ),
      );
    }

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: '${doc.title}.pdf');
  }

  static pw.Widget _buildTemplateLayer(TemplateLayer layer) {
    // Return Grid or Blank
    // Simple grid implementation for PDF
    return pw.Container(
      color: PdfColors.white,
      // child: pw.GridView(...) // Grid drawing in PDF is expensive, skip for blank MVP
    );
  }

  static pw.Widget _buildTextLayer(TextLayer layer) {
    return pw.Stack(
      children: layer.blocks.map((block) {
        return pw.Positioned(
          left: block.x,
          top: block.y,
          child: pw.Container(
            width: block.width,
            child: pw.Text(
              block.text,
              style: pw.TextStyle(
                fontSize: block.fontSize,
                // font: pw.Font.courier(), // Default font
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildDrawingLayer(DrawingLayer layer) {
    return pw.Stack(
      children: layer.strokes.map((stroke) {
        // Convert Stroke to CustomPaint or SVG path
        // PDF package requires Shape/Path drawing
        return pw.CustomPaint(
          painter: (canvas, size) {
            if (stroke.points.isEmpty) return;

            final color = PdfColor.fromInt(stroke.color.toARGB32());

            canvas.setColor(color);
            canvas.setStrokeColor(color);
            canvas.setLineWidth(stroke.strokeWidth);

            canvas.moveTo(stroke.points.first.dx, stroke.points.first.dy);
            for (int i = 1; i < stroke.points.length; i++) {
              canvas.lineTo(stroke.points[i].dx, stroke.points[i].dy);
            }
            canvas.strokePath();
          },
        );
      }).toList(),
    );
  }
}
