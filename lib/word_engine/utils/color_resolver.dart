import 'dart:ui';

import '../model/theme_model.dart';

class ColorResolver {
  static Color resolve({
    String? hexValue,
    String? themeColor,
    double? tint,
    double? shade,
    required ThemeModel? theme,
    bool isAutoText = false,
  }) {
    final base = _resolveBaseColor(hexValue: hexValue, themeColor: themeColor, theme: theme, isAutoText: isAutoText);
    if (tint != null) {
      return _applyTint(base, tint);
    }
    if (shade != null) {
      return _applyShade(base, shade);
    }
    return base;
  }

  static Color _resolveBaseColor({
    String? hexValue,
    String? themeColor,
    required ThemeModel? theme,
    bool isAutoText = false,
  }) {
    if (hexValue != null && hexValue.toLowerCase() == 'auto') {
      return isAutoText ? const Color(0xFF000000) : const Color(0x00000000);
    }
    if (hexValue != null) {
      final normalized = hexValue.padLeft(6, '0');
      final argb = int.parse('FF$normalized', radix: 16);
      return Color(argb);
    }
    if (themeColor != null && theme != null) {
      final argb = theme.colors[themeColor];
      if (argb != null) return Color(argb);
    }
    return isAutoText ? const Color(0xFF000000) : const Color(0x00000000);
  }

  static Color _applyTint(Color base, double tint) {
    final clampFactor = tint.clamp(0.0, 1.0);
    return Color.fromARGB(
      (base.a * 255.0).round().clamp(0, 255),
      _blendChannel((base.r * 255.0).round(), 255, clampFactor),
      _blendChannel((base.g * 255.0).round(), 255, clampFactor),
      _blendChannel((base.b * 255.0).round(), 255, clampFactor),
    );
  }

  static Color _applyShade(Color base, double shade) {
    final clampFactor = shade.clamp(0.0, 1.0);
    return Color.fromARGB(
      (base.a * 255.0).round().clamp(0, 255),
      ((base.r * 255.0) * clampFactor).round().clamp(0, 255),
      ((base.g * 255.0) * clampFactor).round().clamp(0, 255),
      ((base.b * 255.0) * clampFactor).round().clamp(0, 255),
    );
  }

  static int _blendChannel(int value, int target, double factor) {
    return (value + (target - value) * factor).round().clamp(0, 255);
  }

  /// Maps Word named highlight colors (e.g. "yellow", "darkBlue") to Color values.
  static Color? resolveHighlightName(String? name) {
    if (name == null || name.isEmpty) return null;
    return _highlightColors[name.toLowerCase()];
  }

  static const Map<String, Color> _highlightColors = {
    'yellow': Color(0xFFFFFF00),
    'green': Color(0xFF00FF00),
    'cyan': Color(0xFF00FFFF),
    'magenta': Color(0xFFFF00FF),
    'blue': Color(0xFF0000FF),
    'red': Color(0xFFFF0000),
    'darkblue': Color(0xFF000080),
    'darkcyan': Color(0xFF008080),
    'darkgreen': Color(0xFF008000),
    'darkmagenta': Color(0xFF800080),
    'darkred': Color(0xFF800000),
    'darkyellow': Color(0xFF808000),
    'darkgray': Color(0xFF808080),
    'lightgray': Color(0xFFC0C0C0),
    'black': Color(0xFF000000),
    'white': Color(0xFFFFFFFF),
  };
}
