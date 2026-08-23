import 'package:xml/xml.dart';
import '../utils/xml_extensions.dart';

import '../model/theme_model.dart';

class ThemeParser {
  static ThemeModel parse(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final colors = <String, int>{};

    final themeElements = document.findAllElementsNS('srgbClr');
    for (final element in themeElements) {
      final parent = element.parentElement;
      final name = parent?.name.local;
      final value = element.getAttribute('val');
      if (name != null && value != null) {
        colors[name] = _parseHexColor(value);
      }
    }

    // Parse color scheme by child names (dk1, lt1, accent1, etc.)
    final colorMap = <String, int>{};
    for (final scheme in document.findAllElementsNS('clrScheme')) {
      for (final child in scheme.children.whereType<XmlElement>()) {
        final name = child.name.local; // dk1, lt1, accent1, etc.
        final srgb = child.getElementNS('srgbClr');
        if (srgb != null) {
          final val = srgb.getAttribute('val');
          if (val != null) {
            colorMap[name] = _parseHexColor(val);
          }
        } else {
          final sys = child.getElementNS('sysClr');
          if (sys != null) {
            final val = sys.getAttribute('lastClr') ?? sys.getAttribute('val');
            if (val != null) {
              colorMap[name] = _parseHexColor(val);
            }
          }
        }
      }
    }

    // Parse major and minor fonts from fontScheme
    String? majorFont;
    String? minorFont;
    final fontScheme = document.findAllElementsNS('fontScheme').firstOrNull;
    if (fontScheme != null) {
      final majorFontElem = fontScheme.getElementNS('majorFont');
      majorFont = majorFontElem?.getElementNS('latin')?.getAttribute('typeface');

      final minorFontElem = fontScheme.getElementNS('minorFont');
      minorFont = minorFontElem?.getElementNS('latin')?.getAttribute('typeface');
    }

    return ThemeModel(
      colors: {...colors, ...colorMap},
      majorFont: majorFont,
      minorFont: minorFont,
    );
  }

  static int _parseHexColor(String hex) {
    final normalized = hex.padLeft(6, '0');
    return int.parse('FF$normalized', radix: 16);
  }
}
