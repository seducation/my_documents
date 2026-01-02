import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../models/note_model.dart';

class PageLayoutEngine {
  /// Defines the writable area of the page (A4 - margins)
  static const double pageMargin = 60.0;
  static const double contentWidth = AppConstants.a4Width - (pageMargin * 2);
  static const double contentHeight = AppConstants.a4Height - (pageMargin * 2);
  static const double pageBottomLimit = AppConstants.a4Height - pageMargin;

  /// Checks if a text block overflows the current page
  static bool checkOverflow(TextBlock block) {
    // Basic height calculation (Approximate for MVP, better with TextPainter)
    // 1.2 is line height multiplier
    final textPainter = TextPainter(
      text: TextSpan(
        text: block.text,
        style: TextStyle(
          fontSize: block.fontSize,
          fontFamily: 'Inter',
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    // Subtract a small buffer (4px) to ensure wrapping matches UI
    textPainter.layout(maxWidth: block.width - 4.0);
    final blockHeight = textPainter.height;

    // Check if bottom of block exceeds page writable area
    return (block.y + blockHeight) > pageBottomLimit;
  }

  /// Splits a text block into two parts:
  /// Part 1: Fits on current page
  /// Part 2: Remainder (for next page)
  static Map<String, TextBlock> splitBlock(TextBlock block) {
    // 1. Calculate space remaining based on absolute coordinates
    final double spaceRemaining = pageBottomLimit - block.y;

    if (spaceRemaining <= 0) {
      // Entire block moves
      return {
        'remain': block.copyWith(text: ""),
        'moved': block.copyWith(y: pageMargin), // Reset Y for new page
      };
    }

    final text = block.text;
    final style = TextStyle(
      fontSize: block.fontSize,
      fontFamily: 'Inter',
      height: 1.2,
    );

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
      textPainter.layout(maxWidth: block.width - 4.0);

      if (textPainter.height <= spaceRemaining) {
        splitIndex = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // 3. Backtrack to nearest whitespace to avoid cutting words
    if (splitIndex < text.length && splitIndex > 0) {
      final lastSpace =
          text.substring(0, splitIndex).lastIndexOf(RegExp(r'\s'));
      if (lastSpace != -1) {
        splitIndex = lastSpace + 1;
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
