import 'dart:ui';

class AppConstants {
  // A4 Dimensions in Logical Pixels (at 72 DPI for screen viewing base)
  static const double a4Width = 595.0;
  static const double a4Height = 842.0;

  // PDF DPI (Higher for print quality)
  static const double exportDpi = 96.0;

  // UI Layer Opacity
  static const double inactiveLayerOpacity = 0.3;

  // Colors
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color lockedOverlayColor = Color(0x1F000000);
}
