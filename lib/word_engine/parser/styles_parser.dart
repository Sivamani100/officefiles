import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import '../utils/xml_extensions.dart';

import '../model/style_model.dart';
import '../model/theme_model.dart';
import '../utils/color_resolver.dart';

class StylesParser {
  static const _highlightColorMap = <String, String>{
    'yellow': 'FFFF00',
    'green': '00FF00',
    'cyan': '00FFFF',
    'magenta': 'FF00FF',
    'blue': '0000FF',
    'red': 'FF0000',
    'darkBlue': '000080',
    'darkCyan': '008080',
    'darkGreen': '008000',
    'darkMagenta': '800080',
    'darkRed': '800000',
    'darkYellow': '808000',
    'darkGray': '808080',
    'lightGray': 'C0C0C0',
    'black': '000000',
  };

  static Map<String, StyleModel> parse(String xmlContent, {ThemeModel? theme}) {
    final document = XmlDocument.parse(xmlContent);
    final styles = <String, StyleModel>{};

    // Parse docDefaults if present
    final docDefaultsElem = document.findAllElementsNS('docDefaults').firstOrNull;
    if (docDefaultsElem != null) {
      final rPrDefault = docDefaultsElem.getElementNS('rPrDefault')?.getElementNS('rPr');
      final pPrDefault = docDefaultsElem.getElementNS('pPrDefault')?.getElementNS('pPr');
      final defaultRunProperties = _parseRunProperties(rPrDefault, theme);
      final defaultParagraphProperties = _parseParagraphProperties(pPrDefault, theme);

      styles['docdefaults'] = StyleModel(
        styleId: 'docDefaults',
        name: 'docDefaults',
        type: StyleType.paragraph,
        paragraphProperties: defaultParagraphProperties,
        runProperties: defaultRunProperties,
      );
    }

    for (final styleElement in document.findAllElementsNS('style')) {
      final styleId = styleElement.getAttributeNS('styleId');
      if (styleId == null) continue;
      final typeAttr = styleElement.getAttributeNS('type');
      final type = _parseStyleType(typeAttr);
      final name = styleElement.getElementNS('name')?.getAttributeNS('val');
      final basedOn = styleElement.getElementNS('basedOn')?.getAttributeNS('val');
      final linkedStyle = styleElement.getElementNS('link')?.getAttributeNS('val');

      final pPr = styleElement.getElementNS('pPr');
      final rPr = styleElement.getElementNS('rPr');
      final paragraphProperties = _parseParagraphProperties(pPr, theme);
      final runProperties = _parseRunProperties(rPr, theme);

      styles[styleId.toLowerCase()] = StyleModel(
        styleId: styleId,
        name: name,
        type: type,
        basedOn: basedOn,
        linkedStyle: linkedStyle,
        paragraphProperties: paragraphProperties,
        runProperties: runProperties,
      );
    }

    // Ensure styles['normal'] is populated. If not present by key, find the style named 'Normal' or marked default.
    if (!styles.containsKey('normal')) {
      StyleModel? defaultStyle;
      for (final style in styles.values) {
        if (style.type == StyleType.paragraph && 
            (style.name == 'Normal' || style.styleId.toLowerCase() == 'normal')) {
          defaultStyle = style;
          break;
        }
      }
      if (defaultStyle == null) {
        // Look for a style with styleId 'a'
        for (final style in styles.values) {
          if (style.type == StyleType.paragraph && style.styleId == 'a') {
            defaultStyle = style;
            break;
          }
        }
      }
      if (defaultStyle != null) {
        styles['normal'] = defaultStyle;
      }
    }

    return styles;
  }

  static StyleType _parseStyleType(String? value) {
    switch (value) {
      case 'character':
        return StyleType.character;
      case 'table':
        return StyleType.table;
      default:
        return StyleType.paragraph;
    }
  }

  static Map<String, dynamic> _parseParagraphProperties(XmlElement? pPr, ThemeModel? theme) {
    final result = <String, dynamic>{};
    if (pPr == null) return result;

    // Alignment
    final alignment = pPr.getElementNS('jc')?.getAttributeNS('val');
    if (alignment != null) result['alignment'] = alignment;

    // Spacing
    final spacing = pPr.getElementNS('spacing');
    if (spacing != null) {
      final beforeVal = spacing.getAttributeNS('before');
      if (beforeVal != null) {
        result['spacingBefore'] = int.tryParse(beforeVal);
      }
      final afterVal = spacing.getAttributeNS('after');
      if (afterVal != null) {
        result['spacingAfter'] = int.tryParse(afterVal);
      }
      final lineVal = spacing.getAttributeNS('line');
      if (lineVal != null) {
        result['line'] = int.tryParse(lineVal);
      }
      final lineRule = spacing.getAttributeNS('lineRule');
      if (lineRule != null) {
        result['lineRule'] = lineRule;
      }
    }

    // Indentation (including hanging)
    final ind = pPr.getElementNS('ind');
    if (ind != null) {
      final leftVal = ind.getAttributeNS('left');
      if (leftVal != null) {
        result['indentLeft'] = int.tryParse(leftVal);
      }
      final rightVal = ind.getAttributeNS('right');
      if (rightVal != null) {
        result['indentRight'] = int.tryParse(rightVal);
      }
      final firstLineVal = ind.getAttributeNS('firstLine');
      if (firstLineVal != null) {
        result['indentFirstLine'] = int.tryParse(firstLineVal);
      }
      final hangingVal = ind.getAttributeNS('hanging');
      if (hangingVal != null) {
        result['indentHanging'] = int.tryParse(hangingVal);
      }
    }

    // Keep with next
    if (pPr.getElementNS('keepNext') != null) result['keepNext'] = true;

    // Keep lines together
    if (pPr.getElementNS('keepLines') != null) result['keepLines'] = true;

    // Page break before
    if (pPr.getElementNS('pageBreakBefore') != null) result['pageBreakBefore'] = true;

    // Outline level
    final outlineLvl = pPr.getElementNS('outlineLvl')?.getAttributeNS('val');
    if (outlineLvl != null) {
      result['outlineLevel'] = int.tryParse(outlineLvl);
    }

    // Contextual spacing
    if (pPr.getElementNS('contextualSpacing') != null) result['contextualSpacing'] = true;

    // Bidi
    final bidiElem = pPr.getElementNS('bidi');
    if (bidiElem != null) {
      final bidiVal = bidiElem.getAttributeNS('val');
      result['bidi'] = (bidiVal == null || (bidiVal != '0' && bidiVal != 'false'));
    }

    // Paragraph shading
    final shd = pPr.getElementNS('shd');
    if (shd != null) {
      final fill = shd.getAttributeNS('fill');
      final themeColor = shd.getAttributeNS('themeColor');
      final themeTint = shd.getAttributeNS('themeTint');
      final themeShade = shd.getAttributeNS('themeShade');
      if ((fill != null && fill.toLowerCase() != 'auto') || themeColor != null) {
        double? tint;
        if (themeTint != null) {
          final val = int.tryParse(themeTint, radix: 16);
          if (val != null) tint = val / 255.0;
        }
        double? shade;
        if (themeShade != null) {
          final val = int.tryParse(themeShade, radix: 16);
          if (val != null) shade = val / 255.0;
        }
        result['shading'] = ColorResolver.resolve(
          hexValue: fill,
          themeColor: themeColor,
          tint: tint,
          shade: shade,
          theme: theme,
        );
      }
    }

    // Numbering (numPr)
    final numPr = pPr.getElementNS('numPr');
    if (numPr != null) {
      final numId = numPr.getElementNS('numId')?.getAttributeNS('val');
      final ilvlVal = numPr.getElementNS('ilvl')?.getAttributeNS('val');
      final ilvl = ilvlVal != null ? int.tryParse(ilvlVal) ?? 0 : 0;
      if (numId != null) {
        result['numbering'] = {'numId': numId, 'ilvl': ilvl};
      }
    }

    return result;
  }

  static Map<String, dynamic> _parseRunProperties(XmlElement? rPr, ThemeModel? theme) {
    final result = <String, dynamic>{};
    if (rPr == null) return result;

    // Fonts
    final rFonts = rPr.getElementNS('rFonts');
    if (rFonts != null) {
      final ascii = rFonts.getAttributeNS('ascii');
      final hAnsi = rFonts.getAttributeNS('hAnsi');
      final cs = rFonts.getAttributeNS('cs');
      
      final asciiTheme = rFonts.getAttributeNS('asciiTheme');
      final hAnsiTheme = rFonts.getAttributeNS('hAnsiTheme');
      final cstheme = rFonts.getAttributeNS('cstheme');

      String? resolvedAscii = ascii;
      if (asciiTheme != null && theme != null) {
        resolvedAscii = theme.resolveThemeFont(asciiTheme) ?? ascii;
      }

      String? resolvedHAnsi = hAnsi;
      if (hAnsiTheme != null && theme != null) {
        resolvedHAnsi = theme.resolveThemeFont(hAnsiTheme) ?? hAnsi;
      }

      String? resolvedCS = cs;
      if (cstheme != null && theme != null) {
        resolvedCS = theme.resolveThemeFont(cstheme) ?? cs;
      }

      if (resolvedAscii != null) result['fontAscii'] = resolvedAscii;
      if (resolvedHAnsi != null) result['fontHAnsi'] = resolvedHAnsi;
      if (resolvedCS != null) result['fontCS'] = resolvedCS;
    }

    // Font size
    final sz = rPr.getElementNS('sz')?.getAttributeNS('val');
    if (sz != null) result['fontSize'] = int.tryParse(sz);

    // Bold (three-state)
    final bElem = rPr.getElementNS('b');
    if (bElem != null) {
      final bVal = bElem.getAttributeNS('val');
      result['bold'] = (bVal == null || (bVal != '0' && bVal != 'false'));
    }

    // Bold Complex Script
    final bCsElem = rPr.getElementNS('bCs');
    if (bCsElem != null) {
      final bCsVal = bCsElem.getAttributeNS('val');
      result['boldCs'] = (bCsVal == null || (bCsVal != '0' && bCsVal != 'false'));
    }

    // Italic (three-state)
    final iElem = rPr.getElementNS('i');
    if (iElem != null) {
      final iVal = iElem.getAttributeNS('val');
      result['italic'] = (iVal == null || (iVal != '0' && iVal != 'false'));
    }

    // Italic Complex Script
    final iCsElem = rPr.getElementNS('iCs');
    if (iCsElem != null) {
      final iCsVal = iCsElem.getAttributeNS('val');
      result['italicCs'] = (iCsVal == null || (iCsVal != '0' && iCsVal != 'false'));
    }

    // RTL run
    final rtlElem = rPr.getElementNS('rtl');
    if (rtlElem != null) {
      final rtlVal = rtlElem.getAttributeNS('val');
      result['rtl'] = (rtlVal == null || (rtlVal != '0' && rtlVal != 'false'));
    }

    // Underline
    final uElem = rPr.getElementNS('u');
    if (uElem != null) {
      result['underline'] = _parseUnderlineType(uElem.getAttributeNS('val') ?? 'single');
      final uColorVal = uElem.getAttributeNS('color');
      final uThemeColor = uElem.getAttributeNS('themeColor');
      final uThemeTint = uElem.getAttributeNS('themeTint');
      final uThemeShade = uElem.getAttributeNS('themeShade');
      if (uColorVal != null || uThemeColor != null) {
        double? tint;
        if (uThemeTint != null) {
          final val = int.tryParse(uThemeTint, radix: 16);
          if (val != null) tint = val / 255.0;
        }
        double? shade;
        if (uThemeShade != null) {
          final val = int.tryParse(uThemeShade, radix: 16);
          if (val != null) shade = val / 255.0;
        }
        result['underlineColor'] = ColorResolver.resolve(
          hexValue: uColorVal,
          themeColor: uThemeColor,
          tint: tint,
          shade: shade,
          theme: theme,
        );
      }
    }

    // Shadow
    final shadowElem = rPr.getElementNS('shadow');
    if (shadowElem != null) {
      final shVal = shadowElem.getAttributeNS('val');
      result['shadow'] = (shVal == null || (shVal != '0' && shVal != 'false'));
    }

    // Outline
    final outlineElem = rPr.getElementNS('outline');
    if (outlineElem != null) {
      final oVal = outlineElem.getAttributeNS('val');
      result['outline'] = (oVal == null || (oVal != '0' && oVal != 'false'));
    }

    // Strikethrough
    final strikeElem = rPr.getElementNS('strike');
    if (strikeElem != null) {
      final sVal = strikeElem.getAttributeNS('val');
      result['strike'] = (sVal == null || (sVal != '0' && sVal != 'false'));
    }

    // Double strikethrough
    final dstrikeElem = rPr.getElementNS('dstrike');
    if (dstrikeElem != null) {
      final dsVal = dstrikeElem.getAttributeNS('val');
      result['dstrike'] = (dsVal == null || (dsVal != '0' && dsVal != 'false'));
    }

    // Color
    final colorElem = rPr.getElementNS('color');
    if (colorElem != null) {
      final colorVal = colorElem.getAttributeNS('val');
      final themeColor = colorElem.getAttributeNS('themeColor');
      final themeTint = colorElem.getAttributeNS('themeTint');
      final themeShade = colorElem.getAttributeNS('themeShade');
      if (colorVal != null || themeColor != null) {
        double? tint;
        if (themeTint != null) {
          final val = int.tryParse(themeTint, radix: 16);
          if (val != null) tint = val / 255.0;
        }
        double? shade;
        if (themeShade != null) {
          final val = int.tryParse(themeShade, radix: 16);
          if (val != null) shade = val / 255.0;
        }
        result['color'] = ColorResolver.resolve(
          hexValue: colorVal,
          themeColor: themeColor,
          tint: tint,
          shade: shade,
          theme: theme,
          isAutoText: true,
        );
      }
    }

    // Highlight
    final highlightVal = rPr.getElementNS('highlight')?.getAttributeNS('val');
    if (highlightVal != null) {
      final hex = _highlightColorMap[highlightVal];
      if (hex != null) {
        result['highlight'] = ColorResolver.resolve(hexValue: hex, theme: theme);
      }
    }

    // Shading (background)
    final shd = rPr.getElementNS('shd');
    if (shd != null) {
      final fill = shd.getAttributeNS('fill');
      final themeColor = shd.getAttributeNS('themeColor');
      final themeTint = shd.getAttributeNS('themeTint');
      final themeShade = shd.getAttributeNS('themeShade');
      if ((fill != null && fill.toLowerCase() != 'auto') || themeColor != null) {
        double? tint;
        if (themeTint != null) {
          final val = int.tryParse(themeTint, radix: 16);
          if (val != null) tint = val / 255.0;
        }
        double? shade;
        if (themeShade != null) {
          final val = int.tryParse(themeShade, radix: 16);
          if (val != null) shade = val / 255.0;
        }
        result['background'] = ColorResolver.resolve(
          hexValue: fill,
          themeColor: themeColor,
          tint: tint,
          shade: shade,
          theme: theme,
        );
      }
    }

    // Vertical alignment
    final vertAlignVal = rPr.getElementNS('vertAlign')?.getAttributeNS('val');
    if (vertAlignVal != null) {
      switch (vertAlignVal) {
        case 'superscript':
          result['vertAlign'] = VerticalAlignment.superscript;
          break;
        case 'subscript':
          result['vertAlign'] = VerticalAlignment.subscript;
          break;
        default:
          result['vertAlign'] = VerticalAlignment.baseline;
      }
    }

    // Caps
    final capsElem = rPr.getElementNS('caps');
    if (capsElem != null) {
      final cVal = capsElem.getAttributeNS('val');
      result['caps'] = (cVal == null || (cVal != '0' && cVal != 'false'));
    }

    // Small caps
    final smallCapsElem = rPr.getElementNS('smallCaps');
    if (smallCapsElem != null) {
      final scVal = smallCapsElem.getAttributeNS('val');
      result['smallCaps'] = (scVal == null || (scVal != '0' && scVal != 'false'));
    }

    // Vanish
    final vanishElem = rPr.getElementNS('vanish');
    if (vanishElem != null) {
      final vVal = vanishElem.getAttributeNS('val');
      result['vanish'] = (vVal == null || (vVal != '0' && vVal != 'false'));
    }

    // Character spacing
    final spacingElem = rPr.getElementNS('spacing');
    if (spacingElem != null) {
      final spacingVal = spacingElem.getAttributeNS('val');
      if (spacingVal != null) {
        result['characterSpacing'] = int.tryParse(spacingVal);
      }
    }

    return result;
  }

  static UnderlineType? _parseUnderlineType(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'none':
        return UnderlineType.none;
      case 'double':
      case 'wavyDouble':
        return UnderlineType.double;
      case 'dotted':
      case 'dottedHeavy':
        return UnderlineType.dotted;
      case 'dashed':
      case 'dash':
      case 'dashHeavy':
      case 'dashLong':
      case 'dashLongHeavy':
      case 'dotDash':
      case 'dotDotDash':
        return UnderlineType.dashed;
      case 'wave':
      case 'wavyHeavy':
        return UnderlineType.wave;
      default:
        return UnderlineType.single;
    }
  }
}
