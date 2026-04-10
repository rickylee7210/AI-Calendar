import 'package:flutter/widgets.dart';

/// HyperOS Symbols icon font glyphs extracted from Figma design.
class AppIcons {
  AppIcons._();

  static const String _fontFamily = 'HyperOS Symbols';

  // From Figma: 󰀝 (NavBar settings icon)
  static const IconData settings = IconData(0xF001D, fontFamily: _fontFamily);

  // From Figma: 󰁿 (keyboard icon)
  static const IconData keyboard = IconData(0xF007F, fontFamily: _fontFamily);

  // From Figma: 󰂀 (mic/voice icon)
  static const IconData mic = IconData(0xF0080, fontFamily: _fontFamily);

  // From Figma: 󰁂 (calendar icon)
  static const IconData calendar = IconData(0xF0042, fontFamily: _fontFamily);

  // From Figma: 󰀊 (back arrow icon, used for back-to-today)
  static const IconData backToday = IconData(0xF000A, fontFamily: _fontFamily);
}
