import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../models/note_model.dart';

class PageLayoutEngine {
  /// Defines the writable area of the page (A4 - margins)
  static const double pageMargin = 40.0;
  static const double contentWidth = AppConstants.a4Width - (pageMargin * 2);
  static const double contentHeight = AppConstants.a4Height - (pageMargin * 2);

  /// Checks if a text block overflows the current page
  static bool checkOverflow(TextBlock block) {
    // Basic height calculation (Approximate for MVP, better with TextPainter)
    // 1.2 is line height multiplier
    final textPainter = TextPainter(
      text: TextSpan(
        text: block.text,
        style: TextStyle(fontSize: block.fontSize),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: block.width);

    final blockHeight = textPainter.height;

    // Check if bottom of block exceeds page writable area
    return (block.y + blockHeight) > contentHeight;
  }

  /// Splits a text block into two parts:
  /// Part 1: Fits on current page
  /// Part 2: Remainder (for next page)
  static Map<String, TextBlock> splitBlock(TextBlock block) {
    // 1. Calculate space remaining
    final double spaceRemaining = contentHeight - block.y;

    if (spaceRemaining <= 0) {
      // Entire block moves
      return {
        'moved': block.copyWith(y: pageMargin), // Reset Y for new page
      };
    }

    final text = block.text;
    final style = TextStyle(fontSize: block.fontSize);

    // 2. Binary search for split index
    int low = 0;
    int high = text.length;
    int splitIndex = 0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    while (low <= high) {
      int mid = (low + high) ~/ 2;

      textPainter.text = TextSpan(text: text.substring(0, mid), style: style);
      textPainter.layout(maxWidth: block.width);

      if (textPainter.height <= spaceRemaining) {
        splitIndex = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // 3. Backtrack to nearest whitespace to avoid cutting words
    if (splitIndex < text.length) {
      int lastSpace = text.lastIndexOf(' ', splitIndex);
      if (lastSpace != -1) {
        splitIndex = lastSpace +
            1; // Keep space on previous line or move it? +1 to start next word
      }
    }

    // 4. Create blocks
    final remainText = text.substring(0, splitIndex);
    final moveText = text.substring(splitIndex);

    return {
      'remain': block.copyWith(text: remainText),
      'moved': TextBlock(
        id: const Uuid().v4(),
        text: moveText,
        x: block.x,
        y: pageMargin,
        width: block.width,
        fontSize: block.fontSize,
      ),
    };
  }
}
